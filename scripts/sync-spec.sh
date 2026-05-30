#!/usr/bin/env bash
# Refresh openapi.json from a running engine.
# Usage: ENGINE_URL=https://api-staging.topolab.nl ./scripts/sync-spec.sh
set -euo pipefail
ENGINE_URL="${ENGINE_URL:-http://localhost:1337}"
echo "Pulling OpenAPI from ${ENGINE_URL}/v1/api-docs-json ..."
curl -fsS "${ENGINE_URL}/v1/api-docs-json" -o openapi.live.json
echo "Wrote openapi.live.json. Review and diff against openapi.json before committing."
