# Changelog

## [Unreleased]
- **The link route's documents.** `ExportLinkReady.documents` names signed
  links to the build's `columns.json` and each notice file
  (`{columns, notices: [{name, url}]}`). `download()` writes them beside the
  file as `<file>.columns.json` and `<file>.notices/<name>`, fetched without the
  API key; a document that cannot be fetched fails the call. `archive()` writes
  the zip only, which holds them. `conventions.md` ("Downloading files") and the
  `downloads.documents` block of `conventions.yaml` say so.
- `ExportBuildStatus.state` adds `superseded`: a change of the dataset's
  columns ended the build; ask the link route again.
- **The link route.** `openapi.json` adds `POST /v1/dataset/{table}/exports`
  (`ExportLinkRequest`: `format`, `month`, `bundle` `zip` or `file`; 200
  `ExportLinkReady` with a 10-minute signed `url`; 202 `ExportLinkPreparing`
  with `retryAfterSeconds`; 503 `FILE_BUILD_FAILED`) and
  `GET /v1/dataset/exports/{buildId}` (`ExportBuildStatus`).
- The current-month file route sends `Deprecation` (RFC 9745) and
  `Link: <…/exports>; rel="successor-version"` (RFC 8288), and answers 413
  `FILE_TOO_LARGE` over 500 MB and 503 `FILE_PREPARING` or `FILE_BUILD_FAILED`
  with `Retry-After`. The archive route answers a zip only (no gzip), named
  `<table>_<YYYY-MM>.<format>.zip`, and the same 503s.
- `ApiError.details` lists `retryAfter`/`linkRoute` for the two 503 codes and
  `linkRoute` for `FILE_TOO_LARGE`; `conventions.md` and `conventions.yaml`
  list the three codes.
- New section "Downloading files" in `conventions.md` and a `downloads` block in
  `conventions.yaml`: how `download()` and `archive()` use the link route, poll
  while a file is prepared, fetch the signed link without the API key, and fall
  back to the old routes on 404 or 405, decided on every call.
- `DatasetSummary` gains `columnsOnRequest` (`name`, `label.en`, `label.nl`):
  columns available on request, names only.
- Tier words: the `CoordinateRow.metadata` description and the
  `HIGH_VALUE_DATA_REQUIRED` row say "Advanced columns"; the code and the
  `high-value-data` add-on slug keep their names. No tier text names a plan:
  `ExportLinkReady.tier` reads `standard` (the dataset's Standard columns) or
  `advanced` (its Standard and Advanced columns).
- "Downloading files": the signed link's query never goes into a log line or an
  error (`signed_url_request.query_in_logs_or_errors: false`).
- The new paths are not live until the engine release that adds them; the
  weekly freshness check lists them as missing until then.
- The staging base URL is now `https://api.topolab.dev` (was
  `https://api-staging.topolab.nl`): `conventions.yaml` / `conventions.md`
  `environments.staging`, the `servers` entry and description in `openapi.json`,
  and the freshness and smoke workflows. Production is unchanged.

## [1.2.2]
- SQL proxy guard codes (engine database guards): `SQL_FUNCTION_NOT_ALLOWED` and
  `QUERY_TOO_EXPENSIVE` (400), `BUSY` (503, `details.retryAfter` and
  `Retry-After`). SDKs handle them through their status classes; no SDK release.
- `BUSY` carries a top-level `reason`: `ORGANIZATION_LIMIT`, `FLEET_LIMIT` or
  `SLOT_STORE_UNAVAILABLE`. `openapi.json`: `ApiError` has an optional `reason`.
- `openapi.json`: `/v1/sql/query` documents a 503 response. Version 1.2.2.
- A 408 on SQL now means the statement timeout or the run's overall time budget.

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
- **The chat API's stream error codes are upper-snake**, like the error
  envelope's. Every code was renamed, with no lower-case alias: `PROVIDER_DOWN`,
  `RATE_LIMITED`, `AUTH_REQUIRED`, `INTERNAL`, `NOT_ENTITLED`,
  `CREDITS_EXHAUSTED`, `DAILY_LIMIT_REACHED`, `BUDGET_EXHAUSTED`,
  `INVALID_REQUEST`, `AI_BUSY`, `AI_INTERRUPTED` and `AI_CANCELLED`.
  `conventions.md` lists them and notes that Data Studio's HTTP errors send the
  same five AI codes. The 1.2.0 entry below names the old lower-snake spellings.

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
