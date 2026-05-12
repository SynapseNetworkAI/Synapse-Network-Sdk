#!/usr/bin/env bash

load_staging_e2e_secrets() {
  if [[ "${SYNAPSE_E2E_LOAD_SECRET_MANAGER:-1}" == "0" ]]; then
    echo "[e2e:secrets] Secret Manager loading disabled"
    return 0
  fi

  if ! command -v gcloud >/dev/null 2>&1; then
    echo "[e2e:secrets] gcloud not found; using existing environment variables only"
    return 0
  fi

  load_secret_if_missing \
    "SYNAPSE_AGENT_KEY" \
    "${SYNAPSE_STAGING_E2E_AGENT_CREDENTIAL_SECRET:-synapse-staging-e2e-agent-credential}"
  load_secret_if_missing \
    "SYNAPSE_OWNER_PRIVATE_KEY" \
    "${SYNAPSE_STAGING_E2E_CONSUMER_PRIVATE_KEY_SECRET:-synapse-staging-e2e-consumer-private-key}"
  load_secret_if_missing \
    "SYNAPSE_PROVIDER_PRIVATE_KEY" \
    "${SYNAPSE_STAGING_E2E_PROVIDER_PRIVATE_KEY_SECRET:-synapse-staging-e2e-provider-private-key}"
}

load_secret_if_missing() {
  local env_name="$1"
  local secret_name="$2"
  local override="${SYNAPSE_E2E_SECRET_MANAGER_OVERRIDE:-1}"
  if [[ -n "${!env_name:-}" && "$override" != "1" ]]; then
    echo "[e2e:secrets] $env_name already set; keeping explicit environment value"
    return 0
  fi

  local command_args=(secrets versions access latest --secret="$secret_name")
  local project="${SYNAPSE_GCP_PROJECT:-${GOOGLE_CLOUD_PROJECT:-${GCLOUD_PROJECT:-}}}"
  if [[ -n "$project" ]]; then
    command_args+=(--project "$project")
  fi

  local value
  if ! value="$(gcloud "${command_args[@]}" 2>/dev/null)"; then
    echo "[e2e:secrets] unable to load $env_name from Secret Manager secret $secret_name" >&2
    return 1
  fi
  if [[ -z "$value" ]]; then
    echo "[e2e:secrets] Secret Manager secret $secret_name is empty" >&2
    return 1
  fi

  export "$env_name=$value"
  echo "[e2e:secrets] loaded $env_name from Secret Manager secret $secret_name"
}

issue_e2e_agent_key_from_owner() {
  local root_dir="$1"
  local python_bin="$2"
  if [[ -z "${SYNAPSE_OWNER_PRIVATE_KEY:-}" ]]; then
    echo "[e2e:secrets] SYNAPSE_OWNER_PRIVATE_KEY is required to issue a runtime credential" >&2
    return 1
  fi

  echo "[e2e:secrets] issuing a temporary runtime credential"
  local issued_agent_key
  if ! issued_agent_key="$(
    PYTHONPATH="$root_dir/python" "$python_bin" - <<'PY'
import os

from synapse_client import SynapseAuth
from synapse_client.exceptions import AuthenticationError

auth = SynapseAuth.from_private_key(
    os.environ["SYNAPSE_OWNER_PRIVATE_KEY"],
    environment=os.environ.get("SYNAPSE_ENV", "staging"),
    gateway_url=os.environ.get("SYNAPSE_GATEWAY_URL") or None,
)
try:
    result = auth.issue_credential(
        name=f"{os.environ.get('E2E_RUN_ID', 'sdk-e2e')}-agent",
        max_calls=100,
        rpm=60,
        expires_in_sec=3600,
    )
    print(result.token)
except AuthenticationError:
    credentials = auth.list_active_credentials()
    if not credentials:
        raise
    credential = credentials[0]
    auth.update_credential_quota(credential.credential_id, max_calls=100, rpm=60)
    print(auth._usable_token_for_credential(credential))
PY
  )"; then
    echo "[e2e:secrets] unable to issue or reuse a runtime credential" >&2
    return 1
  fi
  if [[ -z "$issued_agent_key" ]]; then
    echo "[e2e:secrets] issued runtime credential was empty" >&2
    return 1
  fi

  SYNAPSE_AGENT_KEY="$issued_agent_key"
  export SYNAPSE_AGENT_KEY
  export SYNAPSE_E2E_SECRET_MANAGER_OVERRIDE=0
}
