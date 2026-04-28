#!/usr/bin/env bash
# neutral-release-callback.sh — POST a worker callback to Convex.
#
# The workflow invokes this after Copybara/build/publish (success path)
# or in the `if: failure()` step (failure path).
#
# Required env vars (set by the workflow):
#   MIRROR_RUN_ID, CALLBACK_URL, CALLBACK_SECRET, CALLBACK_STATUS
#   On success: EXTERNAL_HEAD, NPM_TARBALL, NPM_INTEGRITY, WORKER_LOG_URL, INTERNAL_SHA
#   On failure: ERROR_MESSAGE, WORKER_LOG_URL

set -euo pipefail

if [[ "${CALLBACK_STATUS}" == "succeeded" ]]; then
  BODY=$(jq -nc \
    --arg id "$MIRROR_RUN_ID" \
    --arg jobId "$GITHUB_RUN_ID" \
    --arg log "$WORKER_LOG_URL" \
    --arg internalSha "$INTERNAL_SHA" \
    --arg externalSha "$EXTERNAL_HEAD" \
    --arg tarball "$NPM_TARBALL" \
    --arg integrity "$NPM_INTEGRITY" \
    '{
      mirrorRunId: $id,
      status: "succeeded",
      workerJobId: $jobId,
      workerLogUrl: $log,
      externalShas: [{ internalSha: $internalSha, externalSha: $externalSha }],
      npmTarball: $tarball,
      npmIntegrity: $integrity
    }')
else
  BODY=$(jq -nc \
    --arg id "$MIRROR_RUN_ID" \
    --arg jobId "$GITHUB_RUN_ID" \
    --arg log "$WORKER_LOG_URL" \
    --arg msg "$ERROR_MESSAGE" \
    '{
      mirrorRunId: $id,
      status: "failed",
      workerJobId: $jobId,
      workerLogUrl: $log,
      errorMessage: $msg
    }')
fi

# HMAC-SHA256 the body with the shared callback secret.
SIG=$(printf '%s' "$BODY" \
  | openssl dgst -sha256 -hmac "$CALLBACK_SECRET" \
  | awk '{print $2}')

curl --fail-with-body --show-error -sS \
  -X POST "$CALLBACK_URL" \
  -H "Content-Type: application/json" \
  -H "X-Neutral-Signature: sha256=$SIG" \
  --data "$BODY"
