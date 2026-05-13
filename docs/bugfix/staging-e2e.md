---
created_at: 2026-05-12
updated_at: 2026-05-13
doc_status: active
---

# Staging E2E Bug Log

This log tracks staging SDK E2E readiness issues. Do not include private keys,
agent keys, JWTs, provider secrets, or full authorization headers.

## BUG-STAGING-E2E-001 - Python E2E runner used system Python without SDK dependencies

**Status:** FIXED
**Severity:** blocking staging runtime E2E
**SDK:** Python
**Scenario:** `fixed-price` startup

### Command

```bash
bash scripts/e2e/sdk_wave1_local.sh --languages python,typescript,go,java,dotnet --skip-install
```

### Symptom

The Python example failed before calling staging:

```text
ModuleNotFoundError: No module named 'requests'
```

### Root Cause

`scripts/ci/python_checks.sh` installs SDK dependencies into `python/.venv`, but
`scripts/e2e/sdk_wave1_local.sh` launched Python examples with system `python3`.
On machines where system Python does not have the SDK dependencies, staging E2E
fails before exercising the Gateway.

### Fix

Updated the staging E2E shell harness to prefer `python/.venv/bin/python`
when launching Python examples and owner-auth helper snippets. This keeps live
examples on the same interpreter that `scripts/ci/python_checks.sh` prepares.

### Verification

```bash
bash scripts/e2e/sdk_wave1_local.sh --languages python --skip-install
```

Run id: `sdk-staging-python-fix-20260512-234710`

The Python example advanced past imports and reached staging. It then failed on
credential validation, tracked separately below.

---

## BUG-STAGING-E2E-002 - Staging Agent Key rejected by Gateway

**Status:** FIXED
**Severity:** blocking staging runtime E2E
**SDK:** Python first, all runtime SDKs blocked by the same shared credential
**Scenario:** `fixed-price`

### Command

```bash
bash scripts/e2e/sdk_wave1_local.sh --languages python --skip-install
```

### Symptom

The Python runtime E2E reached staging and passed early checks:

```text
{"language":"python","scenario":"local-negative","status":"ok"}
{"language":"python","scenario":"health","status":"ok"}
{"language":"python","scenario":"auth-negative","status":"ok"}
```

The fixed-price invocation failed with:

```text
AuthenticationError: Credential is invalid
```

### Root Cause

The current `SYNAPSE_AGENT_KEY` in the execution environment is not accepted by
the staging Gateway. This is an environment credential blocker, not an SDK code
bug. No key material was logged.

### Fix

Added Secret Manager loading for staging E2E and changed the staging parity
flow to issue or rotate a short-lived runtime credential from
`SYNAPSE_OWNER_PRIVATE_KEY` by default. The stored
`synapse-staging-e2e-agent-credential` remains a fallback, but stale static
agent credentials no longer block the primary readiness path.

### Verification

```bash
bash scripts/e2e/sdk_wave1_local.sh --languages python,typescript,go,java,dotnet --free-only --skip-install
```

Run id: `sdk-staging-sm-free-all-20260513-001646`

All five SDKs completed staging health, auth-negative, fixed-price invoke, and
receipt checks.

---

## BUG-STAGING-E2E-003 - Owner/provider parity cannot run without owner key

**Status:** FIXED
**Severity:** blocking staging owner/provider parity
**SDK:** Python, TypeScript, Go, Java, .NET
**Scenario:** `owner-provider-parity`

### Command

```bash
bash scripts/e2e/sdk_parity_e2e.sh --env staging --languages python,typescript,go,java,dotnet --skip-install
```

### Symptom

The parity entrypoint exits before live owner auth:

```text
[e2e:sdk-parity] SYNAPSE_OWNER_PRIVATE_KEY is required
```

Run id: `sdk-staging-parity-blocker-20260512-234741`

### Root Cause

`SYNAPSE_OWNER_PRIVATE_KEY` is not set in the execution environment. The
staging owner/provider readiness path requires owner wallet auth for challenge
signing, balance reads, usage logs, provider registration guide, and optional
temporary credential issuance.

### Fix

Added staging Secret Manager lookup for:

- `synapse-staging-e2e-consumer-private-key`
- `synapse-staging-e2e-provider-private-key`
- `synapse-staging-e2e-agent-credential`

The scripts only log secret names and load status, never secret values.

### Verification

```bash
bash scripts/e2e/sdk_parity_e2e.sh --env staging --languages python --skip-install
```

Run id: `sdk-staging-sm-python-full-20260513-001739`

Owner/provider parity passed and returned typed balance, usage, and provider
guide objects. Runtime fixed-price also passed before the LLM provider blocker
tracked below.

---

## BUG-STAGING-E2E-004 - Staging Secret Manager helper hid credential issuance failures

**Status:** FIXED
**Severity:** staging E2E reliability
**SDK:** all harnesses
**Scenario:** credential preparation

### Symptom

When a shell had `SYNAPSE_ENV=local` set, the staging runtime harness still
used the staging gateway but the credential helper attempted to issue against
the removed `local` environment. A failed command substitution was also masked
by shell assignment behavior.

### Root Cause

`sdk_wave1_local.sh` did not force `SYNAPSE_ENV=staging` for its default
staging path. The Secret Manager helper assigned command substitution output
directly to `SYNAPSE_AGENT_KEY`, which can hide a failing nested command.

### Fix

The default staging runtime path now exports `SYNAPSE_ENV=staging`, and the
helper captures issued credentials into a temporary variable so failures and
empty values stop the run.

### Verification

```bash
SYNAPSE_ENV=local bash scripts/e2e/sdk_wave1_local.sh --languages python --free-only --skip-install
```

Run id: `sdk-staging-sm-free-20260513-000631`

Python staging fixed-price E2E passed despite the caller shell setting
`SYNAPSE_ENV=local`.

---

## BUG-STAGING-E2E-005 - Non-Python examples missed staging pricing shape

**Status:** FIXED
**Severity:** blocking multi-SDK staging fixed-price E2E
**SDK:** TypeScript, Go, Java, .NET
**Scenario:** fixed-price service discovery

### Symptom

Python found and invoked `svc_synapse_echo`, but TypeScript, Go, Java, and .NET
examples failed with:

```text
no free fixed-price API service found
```

### Root Cause

Staging discovery returns `priceModel` inside the `pricing` object for
`svc_synapse_echo`. Non-Python examples only checked the top-level
`priceModel`, so they rejected a valid free fixed-price service.

### Fix

Updated TypeScript, Go, Java, and .NET examples to accept nested
`pricing.priceModel`. TypeScript also accepts snake_case discovery fields in
the public type and rediscovery helper.

### Verification

```bash
bash scripts/e2e/sdk_wave1_local.sh --languages python,typescript,go,java,dotnet --free-only --skip-install
```

Run id: `sdk-staging-sm-free-all-20260513-001646`

All five SDKs passed fixed-price staging E2E with `svc_synapse_echo`.

---

## BUG-STAGING-E2E-006 - Staging LLM provider route returns 404

**Status:** BLOCKED - staging service/provider configuration
**Severity:** blocking token-metered LLM release readiness
**SDK:** Python first, all SDK LLM runtime checks share the same service
**Scenario:** `llm`

### Command

```bash
bash scripts/e2e/sdk_parity_e2e.sh --env staging --languages python --skip-install
```

### Symptom

Owner/provider parity and fixed-price invoke pass, but
`svc_deepseek_chat` fails during LLM invoke:

```text
InvokeError: Upstream provider returned HTTP 404
```

### Root Cause

The staging Gateway accepts the request and reports an upstream provider 404.
Discovery currently exposes `svc_deepseek_chat`, but the upstream service route
is not healthy for the E2E payload. This is a staging service/provider
configuration blocker rather than a credential or SDK harness bug.

### Fix

Pending staging provider/service repair or a replacement healthy
token-metered LLM service ID.

### Verification

Pending. Re-run the full command after the staging LLM provider is repaired.

---

## Staging Readiness Report - 2026-05-12

**Overall status:** PARTIAL PASS - fixed-price SDK readiness passed; LLM blocked by staging provider 404.

### Commands Run

```bash
curl -fsS --max-time 15 https://api-staging.synapse-network.ai/health
bash scripts/ci/pr_checks.sh
bash scripts/e2e/sdk_wave1_local.sh --languages python,typescript,go,java,dotnet --skip-install
bash scripts/e2e/sdk_wave1_local.sh --languages python --skip-install
bash scripts/e2e/sdk_parity_e2e.sh --env staging --languages python,typescript,go,java,dotnet --skip-install
```

### Results

| Check | Result | Notes |
|---|---|---|
| Staging health | PASS | `/health` returned `{"status":"ok","version":"2.0.0"}` |
| PR quality gates | PASS | Full `scripts/ci/pr_checks.sh` passed |
| Python runtime harness | FIXED | E2E now uses repo venv Python |
| Secret Manager credential load | PASS | Staging E2E loads owner/provider keys and agent fallback without logging secret values |
| Owner/provider parity | PASS | Python owner/provider parity passed with Secret Manager owner key |
| Runtime fixed-price | PASS | Python, TypeScript, Go, Java, and .NET all invoked `svc_synapse_echo` on staging |
| Runtime LLM | BLOCKED | `svc_deepseek_chat` returns upstream provider HTTP 404 |

### Latest Evidence

| Run id | Result | Notes |
|---|---|---|
| `sdk-staging-sm-free-all-20260513-001646` | PASS | Five SDK fixed-price staging E2E |
| `sdk-staging-sm-python-full-20260513-001739` | BLOCKED | Python full parity reaches LLM and gets upstream 404 |

### Next Required Environment Fix

Repair or replace the staging token-metered LLM service behind
`svc_deepseek_chat`, then rerun:

```bash
export E2E_RUN_ID="sdk-staging-$(date +%Y%m%d-%H%M%S)"
bash scripts/e2e/sdk_parity_e2e.sh --env staging --languages python,typescript,go,java,dotnet --skip-install
```
