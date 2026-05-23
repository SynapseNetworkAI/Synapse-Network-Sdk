#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
OUTPUT_DIR="${SYNAPSE_PROD_PUBLISHED_WORK_DIR:-$ROOT_DIR/output/prod-published-sdk}"
WORK_DIR="$OUTPUT_DIR/work"
LOG_DIR="$OUTPUT_DIR/logs"
ROWS_FILE="$OUTPUT_DIR/results.ndjson"
REPORT_FILE="$OUTPUT_DIR/report.json"
RUN_ID="${E2E_RUN_ID:-prod-published-$(date -u +%Y%m%dT%H%M%SZ)}"

PYTHON_PACKAGE="synapse-network-ai-sdk"
PYTHON_VERSION="1.0.0"
TYPESCRIPT_PACKAGE="@synapse-network-ai/sdk"
TYPESCRIPT_VERSION="1.0.0"
GO_MODULE="github.com/SynapseNetworkAI/Synapse-Network-Sdk/go"
GO_VERSION="v1.0.0"
DOTNET_PACKAGE="SynapseNetwork.Sdk"
DOTNET_VERSION="1.0.0"
JAVA_GROUP="ai.synapse-network"
JAVA_ARTIFACT="synapse-network-sdk"
JAVA_VERSION="1.0.0"

export SYNAPSE_ENV="${SYNAPSE_ENV:-prod}"
export SYNAPSE_GATEWAY_URL="${SYNAPSE_GATEWAY_URL:-https://api.synapse-network.ai}"
export SYNAPSE_PROD_FREE_SERVICE_ID="${SYNAPSE_PROD_FREE_SERVICE_ID:-svc_oss_security_healthcheck}"
export E2E_RUN_ID="$RUN_ID"
export NPM_CONFIG_REGISTRY="${NPM_CONFIG_REGISTRY:-https://registry.npmjs.org}"

if [[ "${SYNAPSE_ENV}" != "prod" ]]; then
  echo "[prod-published] SYNAPSE_ENV must be prod for this production smoke" >&2
  exit 2
fi
if [[ "${SYNAPSE_GATEWAY_URL}" != "https://api.synapse-network.ai" ]]; then
  echo "[prod-published] SYNAPSE_GATEWAY_URL must be https://api.synapse-network.ai" >&2
  exit 2
fi
if [[ -z "${SYNAPSE_PROD_TEST_OWNER_PRIVATE_KEY:-}" ]]; then
  echo "[prod-published] SYNAPSE_PROD_TEST_OWNER_PRIVATE_KEY is required" >&2
  echo "[prod-published] run: bash examples/prod-published/scripts/setup-prod-test-wallet.sh && source ~/.zshrc" >&2
  exit 2
fi

umask 077
mkdir -p "$WORK_DIR" "$LOG_DIR"
: > "$ROWS_FILE"

sanitize_file() {
  local file="$1"
  if [[ -n "${SYNAPSE_PROD_TEST_OWNER_PRIVATE_KEY:-}" ]]; then
    perl -0pi -e 's/\Q$ENV{SYNAPSE_PROD_TEST_OWNER_PRIVATE_KEY}\E/[REDACTED_PRIVATE_KEY]/g' "$file" 2>/dev/null || true
  fi
  if [[ -n "${SYNAPSE_AGENT_KEY:-}" ]]; then
    perl -0pi -e 's/\Q$ENV{SYNAPSE_AGENT_KEY}\E/[REDACTED_AGENT_KEY]/g' "$file" 2>/dev/null || true
  fi
  perl -0pi -e 's/agt_[A-Za-z0-9._-]+/agt_[REDACTED]/g; s/eyJ[A-Za-z0-9._-]+/[REDACTED_JWT]/g' "$file" 2>/dev/null || true
}

append_json_row() {
  ROW_JSON="$1" python3 - "$ROWS_FILE" <<'PY'
import json
import os
import sys

target = sys.argv[1]
row = json.loads(os.environ["ROW_JSON"])
with open(target, "a", encoding="utf-8") as handle:
    handle.write(json.dumps(row, separators=(",", ":")) + "\n")
PY
}

append_failure() {
  local language="$1"
  local package="$2"
  local version="$3"
  local status="$4"
  local error_code="$5"
  local message="$6"
  ROW_LANGUAGE="$language" ROW_PACKAGE="$package" ROW_VERSION="$version" ROW_STATUS="$status" \
    ROW_ERROR_CODE="$error_code" ROW_MESSAGE="$message" python3 - "$ROWS_FILE" <<'PY'
import json
import os
import sys

row = {
    "language": os.environ["ROW_LANGUAGE"],
    "package": os.environ["ROW_PACKAGE"],
    "version": os.environ["ROW_VERSION"],
    "status": os.environ["ROW_STATUS"],
    "errorCode": os.environ["ROW_ERROR_CODE"],
    "message": os.environ["ROW_MESSAGE"][:4000],
}
with open(sys.argv[1], "a", encoding="utf-8") as handle:
    handle.write(json.dumps(row, separators=(",", ":")) + "\n")
PY
}

finish_report() {
  python3 - "$ROWS_FILE" "$REPORT_FILE" <<'PY'
import json
import os
import sys
from datetime import datetime, timezone

rows_path, report_path = sys.argv[1:3]
rows = []
if os.path.exists(rows_path):
    with open(rows_path, encoding="utf-8") as handle:
        rows = [json.loads(line) for line in handle if line.strip()]

report = {
    "generatedAt": datetime.now(timezone.utc).isoformat(),
    "runId": os.environ.get("E2E_RUN_ID"),
    "gatewayUrl": os.environ.get("SYNAPSE_GATEWAY_URL"),
    "servicePreference": os.environ.get("SYNAPSE_PROD_FREE_SERVICE_ID"),
    "results": rows,
}
with open(report_path, "w", encoding="utf-8") as handle:
    json.dump(report, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
  sanitize_file "$REPORT_FILE"
}
trap finish_report EXIT

require_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[prod-published] missing required tool: $1" >&2
    exit 2
  }
}

ensure_dotnet() {
  if command -v dotnet >/dev/null 2>&1; then
    return
  fi
  local dotnet_dir="$OUTPUT_DIR/dotnet-sdk"
  mkdir -p "$dotnet_dir"
  if [[ ! -x "$dotnet_dir/dotnet" ]]; then
    echo "[prod-published] installing .NET SDK 8.0 into $dotnet_dir"
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$dotnet_dir/dotnet-install.sh"
    bash "$dotnet_dir/dotnet-install.sh" --channel 8.0 --install-dir "$dotnet_dir" --no-path
  fi
  export DOTNET_ROOT="$dotnet_dir"
  export PATH="$DOTNET_ROOT:$PATH"
}

run_step() {
  local language="$1"
  local package="$2"
  local version="$3"
  local command="$4"
  local log_file="$LOG_DIR/$language.log"
  echo "[prod-published] running $language published package smoke"
  if bash -lc "$command" >"$log_file" 2>&1; then
    sanitize_file "$log_file"
    local json_line
    json_line="$(python3 - "$log_file" <<'PY'
import json
import sys

last = ""
with open(sys.argv[1], encoding="utf-8") as handle:
    for line in handle:
        text = line.strip()
        if not text.startswith("{"):
            continue
        try:
            payload = json.loads(text)
        except json.JSONDecodeError:
            continue
        if payload.get("language") and payload.get("status"):
            last = json.dumps(payload, separators=(",", ":"))
print(last)
PY
)"
    if [[ -z "$json_line" ]]; then
      append_failure "$language" "$package" "$version" "FAILED" "NO_RESULT_JSON" "runner did not emit a result row; see $log_file"
      echo "[prod-published] $language failed: no result row"
      return 1
    fi
    append_json_row "$json_line"
    echo "[prod-published] $language ok"
    return 0
  fi
  sanitize_file "$log_file"
  local message
  message="$(tail -n 80 "$log_file" | tr '\n' ' ')"
  append_failure "$language" "$package" "$version" "FAILED" "COMMAND_FAILED" "$message"
  echo "[prod-published] $language failed; see $log_file"
  return 1
}

write_python_example() {
  local dir="$WORK_DIR/python"
  mkdir -p "$dir"
  cat > "$dir/prod_free_invoke.py" <<'PY'
from __future__ import annotations

import json
import os
import time
from decimal import Decimal

from synapse_client import SynapseAuth, SynapseClient


LANGUAGE = "python"
PACKAGE = "synapse-network-ai-sdk"
VERSION = "1.0.0"


def env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"{name} is required")
    return value


def decimal_zero(value: object) -> bool:
    try:
        return Decimal(str(value).strip() or "0") == Decimal("0")
    except Exception:
        return False


def service_id(service: object) -> str:
    return str(getattr(service, "service_id", "") or getattr(service, "id", "") or "")


def pricing_amount(service: object) -> str:
    pricing = getattr(service, "pricing", None)
    return str(getattr(pricing, "amount", "") or "")


def price_model(service: object) -> str:
    pricing = getattr(service, "pricing", None)
    return str(getattr(service, "price_model", "") or getattr(pricing, "price_model", "") or "")


def is_free_fixed_api(service: object) -> bool:
    return (
        bool(service_id(service))
        and str(getattr(service, "service_kind", "")).lower() == "api"
        and price_model(service).lower() == "fixed"
        and decimal_zero(pricing_amount(service))
    )


def cleanup_published_credentials(auth: SynapseAuth) -> None:
    for credential in auth.list_credentials():
        name = str(getattr(credential, "name", "") or "")
        credential_id = str(getattr(credential, "id", "") or getattr(credential, "credential_id", "") or "")
        if name.startswith("prod-published") and credential_id:
            auth.delete_credential(credential_id)


def select_free_service(client: SynapseClient) -> tuple[str, str]:
    preferred = os.environ.get("SYNAPSE_PROD_FREE_SERVICE_ID", "svc_oss_security_healthcheck")
    for service in client.search(preferred, limit=10):
        if service_id(service) == preferred and is_free_fixed_api(service):
            return service_id(service), pricing_amount(service)
    if preferred != "svc_oss_security_healthcheck":
        for service in client.search("svc_oss_security_healthcheck", limit=10):
            if service_id(service) == "svc_oss_security_healthcheck" and is_free_fixed_api(service):
                return service_id(service), pricing_amount(service)
    for service in client.search("free", limit=25):
        if is_free_fixed_api(service):
            return service_id(service), pricing_amount(service)
    for service in client.discover(limit=25):
        if is_free_fixed_api(service):
            return service_id(service), pricing_amount(service)
    raise RuntimeError("no free fixed-price API service found")


def payload_for_service(service: str) -> dict:
    if service == "svc_oss_security_healthcheck":
        return {"repoUrl": "https://github.com/SynapseNetworkAI/Synapse-Network-Sdk"}
    if service == "svc_web3_sentiment_index":
        return {"target": "Ethereum"}
    if service == "svc_protocol_fundamental_brief":
        return {"protocol": "ethereum"}
    return {"message": "hello from published Python SDK", "metadata": {"runId": os.environ.get("E2E_RUN_ID")}}


def await_receipt(client: SynapseClient, invocation_id: str):
    if not invocation_id:
        raise RuntimeError("invoke returned empty invocation_id")
    deadline = time.time() + int(os.environ.get("SYNAPSE_E2E_RECEIPT_TIMEOUT_S", "60"))
    while True:
        receipt = client.get_invocation(invocation_id)
        if receipt.invocation_id and receipt.invocation_id != invocation_id:
            raise RuntimeError(f"receipt invocation mismatch: {receipt.invocation_id}")
        if str(receipt.status).upper() in {"SUCCEEDED", "SETTLED"}:
            return receipt
        if time.time() > deadline:
            raise RuntimeError(f"receipt {invocation_id} did not settle; last status={receipt.status}")
        time.sleep(2)


def main() -> None:
    private_key = env("SYNAPSE_PROD_TEST_OWNER_PRIVATE_KEY")
    gateway_url = env("SYNAPSE_GATEWAY_URL")
    auth = SynapseAuth.from_private_key(private_key, gateway_url=gateway_url)
    cleanup_published_credentials(auth)
    issued = auth.issue_credential(
        name=f"prod-published-{LANGUAGE}-{os.environ.get('E2E_RUN_ID', int(time.time()))}",
        max_calls=5,
        rpm=10,
        expires_in_sec=3600,
    )
    if not issued.token:
        raise RuntimeError("issue_credential did not return a token")

    client = SynapseClient(api_key=issued.token, gateway_url=gateway_url)
    service, cost = select_free_service(client)
    if not decimal_zero(cost):
        raise RuntimeError(f"selected service is not free: {service} cost={cost}")
    result = client.invoke(
        service_id=service,
        payload=payload_for_service(service),
        cost_usdc=cost,
        idempotency_key=f"{os.environ.get('E2E_RUN_ID')}-{LANGUAGE}-fixed",
    )
    receipt = await_receipt(client, result.invocation_id)
    charged = str(receipt.charged_usdc if receipt.charged_usdc is not None else result.charged_usdc)
    if not decimal_zero(charged):
        raise RuntimeError(f"expected zero charge, got {charged}")
    print(json.dumps({
        "language": LANGUAGE,
        "package": PACKAGE,
        "version": VERSION,
        "status": "PASSED",
        "serviceId": service,
        "invocationId": result.invocation_id,
        "receiptStatus": receipt.status,
        "chargedUsdc": charged,
    }, separators=(",", ":")))


if __name__ == "__main__":
    main()
PY
}

write_typescript_example() {
  local dir="$WORK_DIR/typescript"
  mkdir -p "$dir"
  cat > "$dir/prod-free-invoke.mjs" <<'JS'
import { Wallet } from "ethers";
import { SynapseAuth, SynapseClient } from "@synapse-network-ai/sdk";

const LANGUAGE = "typescript";
const PACKAGE = "@synapse-network-ai/sdk";
const VERSION = "1.0.0";

function env(name) {
  const value = (process.env[name] ?? "").trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function decimalZero(value) {
  const text = String(value ?? "").trim();
  if (!text) return false;
  return Number(text) === 0;
}

function serviceId(service) {
  return service.serviceId ?? service.service_id ?? service.id ?? "";
}

function pricingAmount(service) {
  const pricing = service.pricing;
  if (typeof pricing === "string") return pricing;
  return pricing && typeof pricing === "object" ? String(pricing.amount ?? "") : "";
}

function priceModel(service) {
  const pricing = service.pricing;
  return String(service.priceModel ?? service.price_model ?? pricing?.priceModel ?? "");
}

function isFreeFixedApi(service) {
  return Boolean(serviceId(service))
    && String(service.serviceKind ?? service.service_kind ?? "").toLowerCase() === "api"
    && priceModel(service).toLowerCase() === "fixed"
    && decimalZero(pricingAmount(service));
}

async function cleanupPublishedCredentials(auth) {
  for (const credential of await auth.listCredentials()) {
    const name = String(credential.name ?? "");
    const credentialId = String(credential.id ?? credential.credential_id ?? "");
    if (name.startsWith("prod-published") && credentialId) {
      await auth.deleteCredential(credentialId);
    }
  }
}

async function selectFreeService(client) {
  const preferred = process.env.SYNAPSE_PROD_FREE_SERVICE_ID || "svc_oss_security_healthcheck";
  for (const service of await client.search(preferred, { limit: 10 })) {
    if (serviceId(service) === preferred && isFreeFixedApi(service)) {
      return { serviceId: serviceId(service), costUsdc: pricingAmount(service) };
    }
  }
  if (preferred !== "svc_oss_security_healthcheck") {
    for (const service of await client.search("svc_oss_security_healthcheck", { limit: 10 })) {
      if (serviceId(service) === "svc_oss_security_healthcheck" && isFreeFixedApi(service)) {
        return { serviceId: serviceId(service), costUsdc: pricingAmount(service) };
      }
    }
  }
  for (const service of await client.search("free", { limit: 25 })) {
    if (isFreeFixedApi(service)) return { serviceId: serviceId(service), costUsdc: pricingAmount(service) };
  }
  for (const service of await client.discover({ limit: 25 })) {
    if (isFreeFixedApi(service)) return { serviceId: serviceId(service), costUsdc: pricingAmount(service) };
  }
  throw new Error("no free fixed-price API service found");
}

function payloadForService(serviceId) {
  if (serviceId === "svc_oss_security_healthcheck") {
    return { repoUrl: "https://github.com/SynapseNetworkAI/Synapse-Network-Sdk" };
  }
  if (serviceId === "svc_web3_sentiment_index") return { target: "Ethereum" };
  if (serviceId === "svc_protocol_fundamental_brief") return { protocol: "ethereum" };
  return { message: "hello from published TypeScript SDK", metadata: { runId: process.env.E2E_RUN_ID } };
}

async function awaitReceipt(client, invocationId) {
  if (!invocationId) throw new Error("invoke returned empty invocationId");
  const deadline = Date.now() + Number(process.env.SYNAPSE_E2E_RECEIPT_TIMEOUT_S ?? "60") * 1000;
  while (true) {
    const receipt = await client.getInvocation(invocationId);
    if (receipt.invocationId && receipt.invocationId !== invocationId) {
      throw new Error(`receipt invocation mismatch: ${receipt.invocationId}`);
    }
    if (["SUCCEEDED", "SETTLED"].includes(String(receipt.status).toUpperCase())) return receipt;
    if (Date.now() > deadline) throw new Error(`receipt ${invocationId} did not settle; last status=${receipt.status}`);
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }
}

const gatewayUrl = env("SYNAPSE_GATEWAY_URL");
const wallet = new Wallet(env("SYNAPSE_PROD_TEST_OWNER_PRIVATE_KEY"));
const auth = SynapseAuth.fromWallet(wallet, { gatewayUrl });
await cleanupPublishedCredentials(auth);
const issued = await auth.issueCredential({
  name: `prod-published-${LANGUAGE}-${process.env.E2E_RUN_ID ?? Date.now()}`,
  maxCalls: 5,
  rpm: 10,
  expiresInSec: 3600,
});
if (!issued.token) throw new Error("issueCredential did not return a token");

const client = new SynapseClient({ credential: issued.token, gatewayUrl });
const target = await selectFreeService(client);
if (!decimalZero(target.costUsdc)) throw new Error(`selected service is not free: ${target.serviceId}`);
const result = await client.invoke(
  target.serviceId,
  payloadForService(target.serviceId),
  { costUsdc: target.costUsdc, idempotencyKey: `${process.env.E2E_RUN_ID}-${LANGUAGE}-fixed` }
);
const receipt = await awaitReceipt(client, result.invocationId);
const charged = String(receipt.chargedUsdc ?? result.chargedUsdc ?? "0");
if (!decimalZero(charged)) throw new Error(`expected zero charge, got ${charged}`);
console.log(JSON.stringify({
  language: LANGUAGE,
  package: PACKAGE,
  version: VERSION,
  status: "PASSED",
  serviceId: target.serviceId,
  invocationId: result.invocationId,
  receiptStatus: receipt.status,
  chargedUsdc: charged,
}));
JS
}

write_go_example() {
  local dir="$WORK_DIR/go"
  mkdir -p "$dir"
  cat > "$dir/main.go" <<'GO'
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"os"
	"strings"
	"time"

	synapse "github.com/SynapseNetworkAI/Synapse-Network-Sdk/go/synapse"
)

const language = "go"

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	auth, err := synapse.NewAuthFromPrivateKey(requireEnv("SYNAPSE_PROD_TEST_OWNER_PRIVATE_KEY"), synapse.AuthOptions{
		GatewayURL: requireEnv("SYNAPSE_GATEWAY_URL"),
	})
	must(err)
	issued, err := auth.IssueCredential(ctx, synapse.CredentialOptions{
		Name:         fmt.Sprintf("prod-published-%s-%s", language, envDefault("E2E_RUN_ID", fmt.Sprint(time.Now().Unix()))),
		MaxCalls:     5,
		RPM:          10,
		ExpiresInSec: 3600,
	})
	must(err)
	if strings.TrimSpace(issued.Token) == "" {
		fail("IssueCredential did not return a token")
	}

	client, err := synapse.NewClient(synapse.Options{Credential: issued.Token, GatewayURL: requireEnv("SYNAPSE_GATEWAY_URL")})
	must(err)
	serviceID, cost := selectFreeService(ctx, client)
	if !decimalZero(cost) {
		fail("selected service is not free: %s cost=%s", serviceID, cost)
	}
	result, err := client.Invoke(
		ctx,
		serviceID,
		payloadForService(serviceID),
		synapse.InvokeOptions{CostUSDC: cost, IdempotencyKey: fmt.Sprintf("%s-%s-fixed", os.Getenv("E2E_RUN_ID"), language)},
	)
	must(err)
	receipt := awaitReceipt(ctx, client, result.InvocationID)
	charged := firstNonEmpty(receipt.ChargedUSDC, result.ChargedUSDC, "0")
	if !decimalZero(charged) {
		fail("expected zero charge, got %s", charged)
	}
	emit(map[string]any{
		"language":      language,
		"package":       "github.com/SynapseNetworkAI/Synapse-Network-Sdk/go",
		"version":       "v1.0.0",
		"status":        "PASSED",
		"serviceId":     serviceID,
		"invocationId":  result.InvocationID,
		"receiptStatus": receipt.Status,
		"chargedUsdc":   charged,
	})
}

func selectFreeService(ctx context.Context, client *synapse.Client) (string, string) {
	preferred := envDefault("SYNAPSE_PROD_FREE_SERVICE_ID", "svc_oss_security_healthcheck")
	services, err := client.Search(ctx, preferred, synapse.SearchOptions{Limit: 10})
	must(err)
	for _, service := range services {
		amount := moneyString(service.Pricing["amount"])
		if service.ServiceID == preferred && isFreeFixedAPI(service, amount) {
			return service.ServiceID, amount
		}
	}
	if preferred != "svc_oss_security_healthcheck" {
		services, err = client.Search(ctx, "svc_oss_security_healthcheck", synapse.SearchOptions{Limit: 10})
		must(err)
		for _, service := range services {
			amount := moneyString(service.Pricing["amount"])
			if service.ServiceID == "svc_oss_security_healthcheck" && isFreeFixedAPI(service, amount) {
				return service.ServiceID, amount
			}
		}
	}
	services, err = client.Search(ctx, "free", synapse.SearchOptions{Limit: 25})
	must(err)
	for _, service := range services {
		amount := moneyString(service.Pricing["amount"])
		if isFreeFixedAPI(service, amount) {
			return service.ServiceID, amount
		}
	}
	services, err = client.Discover(ctx, synapse.SearchOptions{Limit: 25})
	must(err)
	for _, service := range services {
		amount := moneyString(service.Pricing["amount"])
		if isFreeFixedAPI(service, amount) {
			return service.ServiceID, amount
		}
	}
	fail("no free fixed-price API service found")
	return "", ""
}

func payloadForService(serviceID string) map[string]any {
	switch serviceID {
	case "svc_oss_security_healthcheck":
		return map[string]any{"repoUrl": "https://github.com/SynapseNetworkAI/Synapse-Network-Sdk"}
	case "svc_web3_sentiment_index":
		return map[string]any{"target": "Ethereum"}
	case "svc_protocol_fundamental_brief":
		return map[string]any{"protocol": "ethereum"}
	default:
		return map[string]any{"message": "hello from published Go SDK", "metadata": map[string]any{"runId": os.Getenv("E2E_RUN_ID")}}
	}
}

func isFreeFixedAPI(service synapse.ServiceRecord, amount string) bool {
	return strings.TrimSpace(service.ServiceID) != "" &&
		strings.EqualFold(service.ServiceKind, "api") &&
		strings.EqualFold(firstNonEmpty(service.PriceModel, moneyString(service.Pricing["priceModel"])), "fixed") &&
		decimalZero(amount)
}

func awaitReceipt(ctx context.Context, client *synapse.Client, invocationID string) *synapse.InvocationResult {
	if strings.TrimSpace(invocationID) == "" {
		fail("invoke returned empty invocationId")
	}
	deadline := time.Now().Add(time.Duration(envInt("SYNAPSE_E2E_RECEIPT_TIMEOUT_S", 60)) * time.Second)
	for {
		receipt, err := client.GetInvocation(ctx, invocationID)
		must(err)
		if receipt.InvocationID != "" && receipt.InvocationID != invocationID {
			fail("receipt invocation mismatch: %s", receipt.InvocationID)
		}
		if terminal(receipt.Status) {
			return receipt
		}
		if time.Now().After(deadline) {
			fail("receipt %s did not settle; last status=%s", invocationID, receipt.Status)
		}
		time.Sleep(2 * time.Second)
	}
}

func terminal(status string) bool {
	switch strings.ToUpper(strings.TrimSpace(status)) {
	case "SUCCEEDED", "SETTLED":
		return true
	default:
		return false
	}
}

func moneyString(value any) string {
	switch typed := value.(type) {
	case string:
		return typed
	case json.Number:
		return typed.String()
	case nil:
		return ""
	default:
		return fmt.Sprint(typed)
	}
}

func decimalZero(value string) bool {
	rat, ok := new(big.Rat).SetString(strings.TrimSpace(value))
	return ok && rat.Sign() == 0
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}

func envDefault(name, fallback string) string {
	value := strings.TrimSpace(os.Getenv(name))
	if value == "" {
		return fallback
	}
	return value
}

func envInt(name string, fallback int) int {
	var value int
	if _, err := fmt.Sscanf(os.Getenv(name), "%d", &value); err == nil && value > 0 {
		return value
	}
	return fallback
}

func requireEnv(name string) string {
	value := strings.TrimSpace(os.Getenv(name))
	if value == "" {
		fail("%s is required", name)
	}
	return value
}

func must(err error) {
	if err != nil {
		fail("%v", err)
	}
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}

func emit(value map[string]any) {
	raw, err := json.Marshal(value)
	must(err)
	fmt.Println(string(raw))
}
GO
}

write_dotnet_example() {
  local dir="$WORK_DIR/dotnet"
  mkdir -p "$dir"
  cat > "$dir/Program.cs" <<'CS'
using System.Globalization;
using System.Text.Json;
using SynapseNetwork.Sdk;

const string Language = "dotnet";

var cancellationToken = new CancellationTokenSource(TimeSpan.FromMinutes(2)).Token;
var gatewayUrl = RequireEnv("SYNAPSE_GATEWAY_URL");
var auth = SynapseAuth.FromPrivateKey(
    RequireEnv("SYNAPSE_PROD_TEST_OWNER_PRIVATE_KEY"),
    new SynapseAuthOptions { GatewayUrl = gatewayUrl });
await CleanupPublishedCredentials(auth, cancellationToken);
var issued = await auth.IssueCredentialAsync(new CredentialOptions
{
    Name = $"prod-published-{Language}-{EnvDefault("E2E_RUN_ID", DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString(CultureInfo.InvariantCulture))}",
    MaxCalls = 5,
    Rpm = 10,
    ExpiresInSec = 3600,
}, cancellationToken);
if (string.IsNullOrWhiteSpace(issued.Token))
{
    Fail("IssueCredentialAsync did not return a token");
}

var client = new SynapseClient(new SynapseClientOptions { Credential = issued.Token, GatewayUrl = gatewayUrl });
var target = await SelectFreeService(client, cancellationToken);
if (!DecimalZero(target.CostUsdc))
{
    Fail($"selected service is not free: {target.ServiceId} cost={target.CostUsdc}");
}
var result = await client.InvokeAsync(
    target.ServiceId,
    PayloadForService(target.ServiceId),
    new InvokeOptions { CostUsdc = target.CostUsdc, IdempotencyKey = $"{Environment.GetEnvironmentVariable("E2E_RUN_ID")}-{Language}-fixed" },
    cancellationToken);
var receipt = await AwaitReceipt(client, result.InvocationId, cancellationToken);
var charged = FirstNonBlank(receipt.ChargedUsdc, result.ChargedUsdc, "0");
if (!DecimalZero(charged))
{
    Fail($"expected zero charge, got {charged}");
}
Console.WriteLine(JsonSerializer.Serialize(new Dictionary<string, object?>
{
    ["language"] = Language,
    ["package"] = "SynapseNetwork.Sdk",
    ["version"] = "1.0.0",
    ["status"] = "PASSED",
    ["serviceId"] = target.ServiceId,
    ["invocationId"] = result.InvocationId,
    ["receiptStatus"] = receipt.Status,
    ["chargedUsdc"] = charged,
}, new JsonSerializerOptions(JsonSerializerDefaults.Web)));

static async Task<FixedTarget> SelectFreeService(SynapseClient client, CancellationToken cancellationToken)
{
    var preferred = EnvDefault("SYNAPSE_PROD_FREE_SERVICE_ID", "svc_oss_security_healthcheck");
    var services = await client.SearchAsync(preferred, new SearchOptions { Limit = 10 }, cancellationToken);
    foreach (var service in services)
    {
        var amount = PricingAmount(service);
        if (service.ServiceId == preferred && IsFreeFixedApi(service, amount))
        {
            return new FixedTarget(service.ServiceId, amount);
        }
    }
    if (!string.Equals(preferred, "svc_oss_security_healthcheck", StringComparison.Ordinal))
    {
        services = await client.SearchAsync("svc_oss_security_healthcheck", new SearchOptions { Limit = 10 }, cancellationToken);
        foreach (var service in services)
        {
            var amount = PricingAmount(service);
            if (string.Equals(service.ServiceId, "svc_oss_security_healthcheck", StringComparison.Ordinal)
                && IsFreeFixedApi(service, amount))
            {
                return new FixedTarget(service.ServiceId, amount);
            }
        }
    }
    services = await client.SearchAsync("free", new SearchOptions { Limit = 25 }, cancellationToken);
    foreach (var service in services)
    {
        var amount = PricingAmount(service);
        if (IsFreeFixedApi(service, amount))
        {
            return new FixedTarget(service.ServiceId, amount);
        }
    }
    services = await client.DiscoverAsync(new SearchOptions { Limit = 25 }, cancellationToken);
    foreach (var service in services)
    {
        var amount = PricingAmount(service);
        if (IsFreeFixedApi(service, amount))
        {
            return new FixedTarget(service.ServiceId, amount);
        }
    }
    Fail("no free fixed-price API service found");
    throw new InvalidOperationException("unreachable");
}

static Dictionary<string, object?> PayloadForService(string serviceId)
{
    return serviceId switch
    {
        "svc_oss_security_healthcheck" => new Dictionary<string, object?> { ["repoUrl"] = "https://github.com/SynapseNetworkAI/Synapse-Network-Sdk" },
        "svc_web3_sentiment_index" => new Dictionary<string, object?> { ["target"] = "Ethereum" },
        "svc_protocol_fundamental_brief" => new Dictionary<string, object?> { ["protocol"] = "ethereum" },
        _ => new Dictionary<string, object?> { ["message"] = "hello from published .NET SDK", ["metadata"] = new Dictionary<string, object?> { ["runId"] = Environment.GetEnvironmentVariable("E2E_RUN_ID") } },
    };
}

static bool IsFreeFixedApi(ServiceRecord service, string amount)
{
    return !string.IsNullOrWhiteSpace(service.ServiceId)
        && string.Equals(service.ServiceKind, "api", StringComparison.OrdinalIgnoreCase)
        && string.Equals(FirstNonBlank(service.PriceModel, PricingPriceModel(service)), "fixed", StringComparison.OrdinalIgnoreCase)
        && DecimalZero(amount);
}

static async Task CleanupPublishedCredentials(SynapseAuth auth, CancellationToken cancellationToken)
{
    foreach (var credential in await auth.ListCredentialsAsync(cancellationToken))
    {
        var credentialId = FirstNonBlank(credential.Id, credential.CredentialId);
        if (!string.IsNullOrWhiteSpace(credential.Name)
            && credential.Name.StartsWith("prod-published", StringComparison.Ordinal)
            && !string.IsNullOrWhiteSpace(credentialId))
        {
            await auth.DeleteCredentialAsync(credentialId, cancellationToken);
        }
    }
}

static async Task<InvocationResult> AwaitReceipt(SynapseClient client, string? invocationId, CancellationToken cancellationToken)
{
    if (string.IsNullOrWhiteSpace(invocationId))
    {
        Fail("invoke returned empty invocationId");
        throw new InvalidOperationException("unreachable");
    }
    var deadline = DateTimeOffset.UtcNow.AddSeconds(EnvInt("SYNAPSE_E2E_RECEIPT_TIMEOUT_S", 60));
    while (true)
    {
        var receipt = await client.GetInvocationAsync(invocationId, cancellationToken);
        if (!string.IsNullOrWhiteSpace(receipt.InvocationId) && receipt.InvocationId != invocationId)
        {
            Fail($"receipt invocation mismatch: {receipt.InvocationId}");
        }
        if (Terminal(receipt.Status))
        {
            return receipt;
        }
        if (DateTimeOffset.UtcNow > deadline)
        {
            Fail($"receipt {invocationId} did not settle; last status={receipt.Status}");
        }
        await Task.Delay(TimeSpan.FromSeconds(2), cancellationToken);
    }
}

static string PricingAmount(ServiceRecord service)
{
    return service.Pricing.HasValue && service.Pricing.Value.TryGetProperty("amount", out var amount)
        ? amount.GetString() ?? ""
        : "";
}

static string PricingPriceModel(ServiceRecord service)
{
    return service.Pricing.HasValue && service.Pricing.Value.TryGetProperty("priceModel", out var priceModel)
        ? priceModel.GetString() ?? ""
        : "";
}

static bool Terminal(string? status)
{
    return string.Equals(status, "SUCCEEDED", StringComparison.OrdinalIgnoreCase)
        || string.Equals(status, "SETTLED", StringComparison.OrdinalIgnoreCase);
}

static bool DecimalZero(string? value)
{
    return decimal.TryParse(value, NumberStyles.Number, CultureInfo.InvariantCulture, out var parsed) && parsed == 0m;
}

static string FirstNonBlank(params string?[] values)
{
    foreach (var value in values)
    {
        if (!string.IsNullOrWhiteSpace(value))
        {
            return value;
        }
    }
    return "";
}

static string EnvDefault(string name, string fallback)
{
    var value = Environment.GetEnvironmentVariable(name);
    return string.IsNullOrWhiteSpace(value) ? fallback : value.Trim();
}

static int EnvInt(string name, int fallback)
{
    return int.TryParse(Environment.GetEnvironmentVariable(name), out var value) && value > 0 ? value : fallback;
}

static string RequireEnv(string name)
{
    var value = Environment.GetEnvironmentVariable(name);
    if (string.IsNullOrWhiteSpace(value))
    {
        Fail($"{name} is required");
    }
    return value!.Trim();
}

static void Fail(string message)
{
    Console.Error.WriteLine(message);
    Environment.Exit(1);
}

sealed record FixedTarget(string ServiceId, string CostUsdc);
CS
}

write_java_example() {
  local dir="$WORK_DIR/java"
  mkdir -p "$dir/src/main/java/ai/synapsenetwork/examples"
  cat > "$dir/pom.xml" <<XML
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>ai.synapsenetwork.examples</groupId>
  <artifactId>prod-published-smoke</artifactId>
  <version>1.0.0</version>
  <properties>
    <maven.compiler.release>17</maven.compiler.release>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
  </properties>
  <dependencies>
    <dependency>
      <groupId>$JAVA_GROUP</groupId>
      <artifactId>$JAVA_ARTIFACT</artifactId>
      <version>$JAVA_VERSION</version>
    </dependency>
    <dependency>
      <groupId>com.fasterxml.jackson.core</groupId>
      <artifactId>jackson-databind</artifactId>
      <version>2.17.2</version>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <groupId>org.codehaus.mojo</groupId>
        <artifactId>exec-maven-plugin</artifactId>
        <version>3.5.0</version>
      </plugin>
    </plugins>
  </build>
</project>
XML
  cat > "$dir/src/main/java/ai/synapsenetwork/examples/ProdFreeInvoke.java" <<'JAVA'
package ai.synapsenetwork.examples;

import ai.synapsenetwork.sdk.SynapseAuth;
import ai.synapsenetwork.sdk.SynapseClient;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.BigDecimal;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class ProdFreeInvoke {
  private static final String LANGUAGE = "java";
  private static final ObjectMapper MAPPER = new ObjectMapper();

  private ProdFreeInvoke() {}

  public static void main(String[] args) throws Exception {
    String gatewayUrl = requireEnv("SYNAPSE_GATEWAY_URL");
    SynapseAuth.Options authOptions = new SynapseAuth.Options();
    authOptions.gatewayUrl = gatewayUrl;
    SynapseAuth auth = SynapseAuth.fromPrivateKey(requireEnv("SYNAPSE_PROD_TEST_OWNER_PRIVATE_KEY"), authOptions);
    cleanupPublishedCredentials(auth);
    SynapseAuth.CredentialOptions credentialOptions = new SynapseAuth.CredentialOptions();
    credentialOptions.name = "prod-published-" + LANGUAGE + "-" + envDefault("E2E_RUN_ID", String.valueOf(System.currentTimeMillis()));
    credentialOptions.maxCalls = 5;
    credentialOptions.rpm = 10;
    credentialOptions.expiresInSec = 3600;
    SynapseAuth.IssueCredentialResult issued = auth.issueCredential(credentialOptions);
    if (issued.token() == null || issued.token().isBlank()) {
      fail("issueCredential did not return a token");
    }

    SynapseClient client = new SynapseClient(SynapseClient.options(issued.token()).gatewayUrl(gatewayUrl));
    FixedTarget target = selectFreeService(client);
    if (!decimalZero(target.costUsdc())) {
      fail("selected service is not free: " + target.serviceId() + " cost=" + target.costUsdc());
    }
    SynapseClient.InvokeOptions invokeOptions = new SynapseClient.InvokeOptions();
    invokeOptions.costUsdc = target.costUsdc();
    invokeOptions.idempotencyKey = System.getenv("E2E_RUN_ID") + "-" + LANGUAGE + "-fixed";
    SynapseClient.InvocationResult result =
        client.invoke(
            target.serviceId(),
            payloadForService(target.serviceId()),
            invokeOptions);
    SynapseClient.InvocationResult receipt = awaitReceipt(client, result.invocationId());
    String charged = firstNonBlank(receipt.chargedUsdc(), result.chargedUsdc(), "0");
    if (!decimalZero(charged)) {
      fail("expected zero charge, got " + charged);
    }
    Map<String, Object> row = new LinkedHashMap<>();
    row.put("language", LANGUAGE);
    row.put("package", "ai.synapse-network:synapse-network-sdk");
    row.put("version", "1.0.0");
    row.put("status", "PASSED");
    row.put("serviceId", target.serviceId());
    row.put("invocationId", result.invocationId());
    row.put("receiptStatus", receipt.status());
    row.put("chargedUsdc", charged);
    System.out.println(MAPPER.writeValueAsString(row));
  }

  private static FixedTarget selectFreeService(SynapseClient client) {
    String preferred = envDefault("SYNAPSE_PROD_FREE_SERVICE_ID", "svc_oss_security_healthcheck");
    SynapseClient.SearchOptions preferredOptions = new SynapseClient.SearchOptions();
    preferredOptions.limit = 10;
    for (SynapseClient.ServiceRecord service : client.search(preferred, preferredOptions)) {
      String amount = pricingAmount(service);
      if (preferred.equals(service.serviceId()) && isFreeFixedApi(service, amount)) {
        return new FixedTarget(service.serviceId(), amount);
      }
    }
    if (!"svc_oss_security_healthcheck".equals(preferred)) {
      for (SynapseClient.ServiceRecord service : client.search("svc_oss_security_healthcheck", preferredOptions)) {
        String amount = pricingAmount(service);
        if ("svc_oss_security_healthcheck".equals(service.serviceId()) && isFreeFixedApi(service, amount)) {
          return new FixedTarget(service.serviceId(), amount);
        }
      }
    }
    SynapseClient.SearchOptions options = new SynapseClient.SearchOptions();
    options.limit = 25;
    for (SynapseClient.ServiceRecord service : client.search("free", options)) {
      String amount = pricingAmount(service);
      if (isFreeFixedApi(service, amount)) {
        return new FixedTarget(service.serviceId(), amount);
      }
    }
    for (SynapseClient.ServiceRecord service : client.discover(options)) {
      String amount = pricingAmount(service);
      if (isFreeFixedApi(service, amount)) {
        return new FixedTarget(service.serviceId(), amount);
      }
    }
    fail("no free fixed-price API service found");
    throw new IllegalStateException("unreachable");
  }

  private static void cleanupPublishedCredentials(SynapseAuth auth) {
    for (SynapseAuth.AgentCredential credential : auth.listCredentials()) {
      String credentialId = firstNonBlank(credential.id(), credential.credentialId());
      if (credential.name() != null && credential.name().startsWith("prod-published") && !credentialId.isBlank()) {
        auth.deleteCredential(credentialId);
      }
    }
  }

  private static boolean isFreeFixedApi(SynapseClient.ServiceRecord service, String amount) {
    return service.serviceId() != null
        && "api".equalsIgnoreCase(service.serviceKind())
        && "fixed".equalsIgnoreCase(firstNonBlank(service.priceModel(), pricingPriceModel(service)))
        && decimalZero(amount);
  }

  private static Map<String, Object> payloadForService(String serviceId) {
    if ("svc_oss_security_healthcheck".equals(serviceId)) {
      return Map.of("repoUrl", "https://github.com/SynapseNetworkAI/Synapse-Network-Sdk");
    }
    if ("svc_web3_sentiment_index".equals(serviceId)) {
      return Map.of("target", "Ethereum");
    }
    if ("svc_protocol_fundamental_brief".equals(serviceId)) {
      return Map.of("protocol", "ethereum");
    }
    return Map.of("message", "hello from published Java SDK", "metadata", Map.of("runId", envDefault("E2E_RUN_ID", "")));
  }

  private static SynapseClient.InvocationResult awaitReceipt(SynapseClient client, String invocationId) throws InterruptedException {
    if (invocationId == null || invocationId.isBlank()) {
      fail("invoke returned empty invocationId");
    }
    long deadline = System.currentTimeMillis() + Duration.ofSeconds(envInt("SYNAPSE_E2E_RECEIPT_TIMEOUT_S", 60)).toMillis();
    while (true) {
      SynapseClient.InvocationResult receipt = client.getInvocation(invocationId);
      if (receipt.invocationId() != null && !receipt.invocationId().isBlank() && !receipt.invocationId().equals(invocationId)) {
        fail("receipt invocation mismatch: " + receipt.invocationId());
      }
      if (terminal(receipt.status())) {
        return receipt;
      }
      if (System.currentTimeMillis() > deadline) {
        fail("receipt " + invocationId + " did not settle; last status=" + receipt.status());
      }
      Thread.sleep(2000);
    }
  }

  private static String pricingAmount(SynapseClient.ServiceRecord service) {
    return service.pricing() != null && service.pricing().has("amount") ? service.pricing().get("amount").asText("") : "";
  }

  private static String pricingPriceModel(SynapseClient.ServiceRecord service) {
    return service.pricing() != null && service.pricing().has("priceModel") ? service.pricing().get("priceModel").asText("") : "";
  }

  private static boolean terminal(String status) {
    return "SUCCEEDED".equalsIgnoreCase(status) || "SETTLED".equalsIgnoreCase(status);
  }

  private static boolean decimalZero(String value) {
    try {
      return new BigDecimal(value == null || value.isBlank() ? "NaN" : value).compareTo(BigDecimal.ZERO) == 0;
    } catch (NumberFormatException ex) {
      return false;
    }
  }

  private static String firstNonBlank(String... values) {
    for (String value : values) {
      if (value != null && !value.isBlank()) {
        return value;
      }
    }
    return "";
  }

  private static int envInt(String name, int fallback) {
    try {
      int value = Integer.parseInt(envDefault(name, String.valueOf(fallback)));
      return value > 0 ? value : fallback;
    } catch (NumberFormatException ex) {
      return fallback;
    }
  }

  private static String envDefault(String name, String fallback) {
    String value = System.getenv(name);
    return value == null || value.isBlank() ? fallback : value.trim();
  }

  private static String requireEnv(String name) {
    String value = System.getenv(name);
    if (value == null || value.isBlank()) {
      fail(name + " is required");
    }
    return value.trim();
  }

  private static void fail(String message) {
    System.err.println(message);
    System.exit(1);
  }

  private record FixedTarget(String serviceId, String costUsdc) {}
}
JAVA
}

check_java_published() {
  local metadata_url="https://repo1.maven.org/maven2/${JAVA_GROUP//.//}/${JAVA_ARTIFACT}/maven-metadata.xml"
  curl -fsS "$metadata_url" >/dev/null 2>&1
}

run_java_gate() {
  if ! check_java_published; then
    append_failure "java" "$JAVA_GROUP:$JAVA_ARTIFACT" "$JAVA_VERSION" "BLOCKED_UNPUBLISHED_JAVA" "MAVEN_ARTIFACT_MISSING" "Maven Central does not serve $JAVA_GROUP:$JAVA_ARTIFACT:$JAVA_VERSION; source fallback is intentionally disabled."
    echo "[prod-published] java blocked: Maven artifact is not public"
    return 20
  fi
  write_java_example
  if ! command -v mvn >/dev/null 2>&1; then
    append_failure "java" "$JAVA_GROUP:$JAVA_ARTIFACT" "$JAVA_VERSION" "FAILED" "TOOL_MISSING" "mvn is required"
    return 1
  fi
  local java_dir="$WORK_DIR/java"
  run_step "java" "$JAVA_GROUP:$JAVA_ARTIFACT" "$JAVA_VERSION" \
    "cd '$java_dir' && mvn -q -DskipTests compile exec:java -Dexec.mainClass=ai.synapsenetwork.examples.ProdFreeInvoke"
}

require_tool python3
require_tool curl

failures=0

write_python_example
if command -v python3 >/dev/null 2>&1; then
  python_dir="$WORK_DIR/python"
  if [[ ! -x "$python_dir/.venv/bin/python" ]]; then
    python3 -m venv "$python_dir/.venv"
  fi
  run_step "python" "$PYTHON_PACKAGE" "$PYTHON_VERSION" \
    "cd '$python_dir' && .venv/bin/python -m pip install --quiet --upgrade pip '$PYTHON_PACKAGE==$PYTHON_VERSION' eth-account && .venv/bin/python prod_free_invoke.py" || failures=$((failures + 1))
else
  append_failure "python" "$PYTHON_PACKAGE" "$PYTHON_VERSION" "FAILED" "TOOL_MISSING" "python3 is required"
  failures=$((failures + 1))
fi

write_typescript_example
if command -v npm >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
  ts_dir="$WORK_DIR/typescript"
  run_step "typescript" "$TYPESCRIPT_PACKAGE" "$TYPESCRIPT_VERSION" \
    "cd '$ts_dir' && npm init -y >/dev/null && npm install --silent '$TYPESCRIPT_PACKAGE@$TYPESCRIPT_VERSION' ethers@^6 && node prod-free-invoke.mjs" || failures=$((failures + 1))
else
  append_failure "typescript" "$TYPESCRIPT_PACKAGE" "$TYPESCRIPT_VERSION" "FAILED" "TOOL_MISSING" "node and npm are required"
  failures=$((failures + 1))
fi

write_go_example
if command -v go >/dev/null 2>&1; then
  go_dir="$WORK_DIR/go"
  run_step "go" "$GO_MODULE" "$GO_VERSION" \
    "cd '$go_dir' && go mod init synapse-prod-published-smoke >/dev/null 2>&1 || true; go get '$GO_MODULE/synapse@$GO_VERSION' >/dev/null; go run ." || failures=$((failures + 1))
else
  append_failure "go" "$GO_MODULE" "$GO_VERSION" "FAILED" "TOOL_MISSING" "go is required"
  failures=$((failures + 1))
fi

ensure_dotnet
if command -v dotnet >/dev/null 2>&1; then
  dotnet_dir="$WORK_DIR/dotnet"
  rm -rf "$dotnet_dir"
  mkdir -p "$dotnet_dir"
  (cd "$dotnet_dir" && dotnet new console --framework net8.0 >/dev/null)
  write_dotnet_example
  run_step "dotnet" "$DOTNET_PACKAGE" "$DOTNET_VERSION" \
    "cd '$dotnet_dir' && dotnet add package '$DOTNET_PACKAGE' --version '$DOTNET_VERSION' >/dev/null && dotnet run --no-restore" || failures=$((failures + 1))
else
  append_failure "dotnet" "$DOTNET_PACKAGE" "$DOTNET_VERSION" "FAILED" "TOOL_MISSING" "dotnet SDK is required"
  failures=$((failures + 1))
fi

if ! run_java_gate; then
  failures=$((failures + 1))
fi

finish_report
echo "[prod-published] report: $REPORT_FILE"

if [[ "$failures" -gt 0 ]]; then
  echo "[prod-published] completed with $failures failure/blocker row(s)" >&2
  exit 1
fi

echo "[prod-published] all published SDK production free-invoke checks passed"
