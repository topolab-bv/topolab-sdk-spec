# Changelog

## [1.2.1]
- **429s carry a code, details and `Retry-After`** (engine #650).
  - `RATE_LIMIT_EXCEEDED` has `details.retryAfter` (seconds), `limit`,
    `remaining` and `resetAt`, plus a `Retry-After` header.
  - `USAGE_QUOTA_EXCEEDED` has `details.quota` and `used`, and no wait.
  - `fixtures/nl-domino-poi/error-429.json` now has the real envelope instead of
    the old `statusCode`/`retryAfter` shape. `error-429-quota.json` is new. Both
    are written to the filter's output shape, not captured live.
- SDKs read a 429's wait from the `Retry-After` header, then
  `details.retryAfter`, then the older top-level `retryAfter`
  (`retry_after_sources` in `conventions.yaml`).
- New "Rate limits" section in `conventions.md`:
  - the per-key limit by plan (60, 300 and 1,000 requests a minute for Free,
    Team and Enterprise);
  - the `X-RateLimit-Limit-ApiKey`, `X-RateLimit-Remaining-ApiKey` and
    `X-RateLimit-Reset-ApiKey` headers, with Reset in seconds;
  - the `X-Quota-*` headers.
- `openapi.json`: `ApiError.details` lists the 429 keys, and the owned-datasets
  429 documents `Retry-After`. Version 1.2.1.

## [1.2.0]
- **`code` in the error envelope is now a string or a number.** Since engine
  PR #641 the engine keeps a named code it throws (upper-snake, such as
  `SPENDING_LIMIT_EXCEEDED`) and otherwise sends the numeric HTTP status, so
  `code` no longer always equals the status. `ApiError.code` in `openapi.json` is
  `oneOf: [string, integer]`, and `conventions.md` lists the known string codes
  and what they mean, plus the lower-snake codes the chat API sends on its
  stream (`ai_busy`, `ai_interrupted`, `ai_cancelled`).
- **`details` is documented.** It carries allow-listed, typed fields: 402
  `required`/`available`, 413 `quotaBytes`/`usageBytes`/`additionalBytes`, 403
  `SPENDING_LIMIT_EXCEEDED` `limit`/`consumed`/`remaining`/`periodEnd` and 403
  `HIGH_VALUE_DATA_REQUIRED` `columns`/`datasetIds`. `ApiError` gains a
  `details` property.
- Every SDK error now exposes the HTTP status (`status`), the envelope `code`
  (string-or-number) and `details`, with the idiomatic spelling per language in
  `conventions.md` and `error_fields` in `conventions.yaml`. Error classes are
  still chosen from the HTTP status.
- Fixtures: `nl-domino-poi/error-403-spending-limit.json` (string code with
  details) and `owned/error-400-sql-data.json` (string code without details),
  both written to the shape the engine filter emits after #641. The 402 fixture
  now has the real envelope shape (`code: 402` with `details`) instead of the
  `statusCode`/`error` shape it was written in.

## [1.1.0]
- Spec grew from 5 paths to 17, covering the surface an organization needs to
  pull the data it owns into its own systems:
  - `GET /v1/dataset/owned` — paginated listing of licensed datasets, each with
    absolute links to its current file and archives.
  - `GET /v1/dataset/{table}/archives/list` — monthly archives, newest first,
    already filtered to the plan's retention window.
  - `GET /v1/dataset/{table}/archives/{month}/{format}` — archive download,
    addressable by `latest`, `YYYY-MM` or `YYYY-MM-DD`.
  - `GET /v1/dataset/{table}/coordinates` — paginated coordinates with
    `X-Total-Count` / `X-Returned-Count` / `X-Offset`.
  - `POST /v1/sql/query` — read-only SQL (Enterprise).
  - The OGC discovery trio (`/v1/ogc`, `/conformance`, `/api`), the collection
    routes, and single-feature access.
  - `GET /v1/dataset/{table}/files` — public asset/export metadata.
- Catalogue routes (`/v1/dataset/all`, `/{table}`, `/{table}/sample/{format}`,
  `/{table}/files`) are now marked as requiring no authentication, which is how
  they actually behave.
- `sample` no longer advertises `shp`; only the bulk and archive downloads
  offer it.
- Corrected `conventions.md`: the API key is a signed JWT (it did not match the
  `tlb_{env}_...` shape the doc claimed), and the OGC `collectionId` is the
  dataset slug — the documented `dataset-{UUID}` round-trip was never what the
  SDKs did, and the legacy form is server-side back-compat only.
- Added `QueryTimeoutError` (408) for SQL statement timeouts.
- **Corrected the error envelope.** The engine returns
  `{code, message, path, method, time, requestId}` — there is no `statusCode`
  field, which is what `ApiError` and the error fixtures claimed. SDKs branch on
  the HTTP status, so mapping was unaffected, but the documented shape was wrong.
- **Fixed add-on detection, which never worked.** Add-on identifiers are
  hyphenated slugs (`api-access`), but the documented capture was `(\w+)`, which
  stops at the hyphen and therefore matched nothing — so every add-on 403 was
  reported as a plain access denial in all four SDKs. The `error-403-addon`
  fixture had been written to match the regex (`API_ACCESS`) rather than the API.
  A second message shape ("Archive access requires the Archived Data add-on…")
  is now documented too.
- Fixed the nightly live-smoke job, which had failed every night since
  2026-07-26: it asserted on a dataset slug that does not exist. It now
  discovers a dataset from the key's own entitlements and exercises the
  discover-to-download loop.
- `scripts/sync-spec.sh` now explains why it failed instead of surfacing a bare
  curl error.

## [0.1.0]
- Initial spec snapshot, conventions, fixtures, and examples.
- Defines the read-only v1 surface shared by the Python, TypeScript, and R SDKs:
  client construction + options, `dataset()` / `datasets.list` / `metadata` /
  `sample` / `to_geojson` / `download` / `items` / `iter_items`, the error
  taxonomy, and `X-API-Key` auth on data routes.
- OGC `collectionId` is the dataset slug (`table`); all SDKs address
  `/v1/ogc/collections/{slug}/items` directly.
