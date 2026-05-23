#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/output/prod-published-sdk/wallet-setup"
ZSHRC="${SYNAPSE_ZSHRC_PATH:-$HOME/.zshrc}"
BEGIN_MARKER="# >>> synapse prod published SDK test wallet >>>"
END_MARKER="# <<< synapse prod published SDK test wallet <<<"
FORCE=false

usage() {
  cat <<'EOF'
Usage: bash examples/prod-published/scripts/setup-prod-test-wallet.sh [--force]

Creates a fresh local production smoke-test wallet and stores it only in a
controlled marker block in ~/.zshrc.

Options:
  --force   Replace an existing Synapse production smoke-test wallet block.
  -h        Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[prod-published:wallet] unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -f "$ZSHRC" ]] && grep -Fq "$BEGIN_MARKER" "$ZSHRC" && [[ "$FORCE" != "true" ]]; then
  existing_address="$(
    awk -F"'" '/SYNAPSE_PROD_TEST_OWNER_ADDRESS=/ {print $2; exit}' "$ZSHRC" 2>/dev/null || true
  )"
  echo "[prod-published:wallet] existing test wallet block found in $ZSHRC"
  if [[ -n "$existing_address" ]]; then
    echo "[prod-published:wallet] address: $existing_address"
  fi
  echo "[prod-published:wallet] use --force to replace it"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || {
  echo "[prod-published:wallet] python3 is required" >&2
  exit 2
}
command -v openssl >/dev/null 2>&1 || {
  echo "[prod-published:wallet] openssl is required" >&2
  exit 2
}

mkdir -p "$OUTPUT_DIR"
if [[ ! -x "$OUTPUT_DIR/.venv/bin/python" ]]; then
  python3 -m venv "$OUTPUT_DIR/.venv"
fi
"$OUTPUT_DIR/.venv/bin/python" -m pip install --quiet --upgrade pip eth-account

private_key="0x$(openssl rand -hex 32)"
address="$(
  "$OUTPUT_DIR/.venv/bin/python" - "$private_key" <<'PY'
import sys
from eth_account import Account

print(Account.from_key(sys.argv[1]).address)
PY
)"

mkdir -p "$(dirname "$ZSHRC")"
touch "$ZSHRC"
tmp_file="$(mktemp)"
awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
  $0 == begin {skip=1; next}
  $0 == end {skip=0; next}
  skip != 1 {print}
' "$ZSHRC" > "$tmp_file"
cat >> "$tmp_file" <<EOF

$BEGIN_MARKER
export SYNAPSE_PROD_TEST_OWNER_PRIVATE_KEY='$private_key'
export SYNAPSE_PROD_TEST_OWNER_ADDRESS='$address'
export SYNAPSE_ENV='prod'
export SYNAPSE_GATEWAY_URL='https://api.synapse-network.ai'
$END_MARKER
EOF
mv "$tmp_file" "$ZSHRC"
chmod 600 "$ZSHRC" 2>/dev/null || true

echo "[prod-published:wallet] wrote local test wallet block to $ZSHRC"
echo "[prod-published:wallet] address: $address"
echo "[prod-published:wallet] private key: [redacted]"
echo "[prod-published:wallet] next: source ~/.zshrc && bash examples/prod-published/scripts/run-all.sh"
