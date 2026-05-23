#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

username="${MAVEN_CENTRAL_USERNAME:-}"
password="${MAVEN_CENTRAL_PASSWORD:-}"

if [[ -z "${username}" || -z "${password}" ]]; then
  if [[ "${MAVEN_TOKEN:-}" == *:* ]]; then
    username="${MAVEN_TOKEN%%:*}"
    password="${MAVEN_TOKEN#*:}"
  fi
fi

if [[ -z "${username}" || -z "${password}" || "${username}" == "${password}" ]]; then
  echo "Maven Central publish requires MAVEN_TOKEN=username:password or MAVEN_CENTRAL_USERNAME/MAVEN_CENTRAL_PASSWORD." >&2
  exit 2
fi

settings_file="$(mktemp)"
cleanup() {
  rm -f "${settings_file}"
}
trap cleanup EXIT

python3 - "${settings_file}" <<'PY'
import os
import sys
import xml.sax.saxutils as xml

settings_path = sys.argv[1]
username = os.environ.get("MAVEN_CENTRAL_USERNAME") or os.environ.get("MAVEN_TOKEN", "").split(":", 1)[0]
password = os.environ.get("MAVEN_CENTRAL_PASSWORD") or os.environ.get("MAVEN_TOKEN", "").split(":", 1)[1]
payload = f"""<settings>
  <servers>
    <server>
      <id>central</id>
      <username>{xml.escape(username)}</username>
      <password>{xml.escape(password)}</password>
    </server>
  </servers>
</settings>
"""
with open(settings_path, "w", encoding="utf-8") as handle:
    handle.write(payload)
PY

chmod 600 "${settings_file}"

exec mvn -s "${settings_file}" -B -f "${ROOT_DIR}/java/pom.xml" -Dcentral.publish=true deploy
