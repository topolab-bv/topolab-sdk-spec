#!/usr/bin/env bash
# Refresh openapi.live.json from a running engine, for diffing against the
# curated openapi.json in this repo.
#
# Usage: ENGINE_URL=https://api-staging.topolab.nl ./scripts/sync-spec.sh
set -euo pipefail

ENGINE_URL="${ENGINE_URL:-http://localhost:1337}"
DOCS_URL="${ENGINE_URL}/v1/api-docs-json"

echo "Pulling OpenAPI from ${DOCS_URL} ..."
status=$(curl -sS -o openapi.live.json -w '%{http_code}' "${DOCS_URL}" || echo "000")

if [ "$status" != "200" ]; then
  rm -f openapi.live.json
  echo "ERROR: ${DOCS_URL} returned HTTP ${status}." >&2
  case "$status" in
    404)
      echo "The OpenAPI document is only mounted when ENABLE_API_DOCS=true on the" >&2
      echo "target service (and, in production, behind API_DOCS_TOKEN). It is off" >&2
      echo "on staging today, so this check cannot run until that is enabled." >&2
      ;;
    401|403)
      echo "The docs endpoint is mounted but gated. Supply credentials via" >&2
      echo "API_DOCS_TOKEN (HTTP Basic) to fetch it." >&2
      ;;
    000)
      echo "Could not reach ${ENGINE_URL} at all." >&2
      ;;
  esac
  exit 1
fi

echo "Wrote openapi.live.json. Review and diff against openapi.json before committing."
