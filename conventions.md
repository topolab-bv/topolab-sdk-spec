# Topolab SDK Conventions

The canonical surface every SDK implements idiomatically. The machine-readable
form is [`conventions.yaml`](conventions.yaml); each SDK lints against it.

## Construction

API key from an explicit argument or the `TOPOLAB_API_KEY` environment variable.
Auth is the `X-API-Key` header; the key is a signed JWT, so treat it as an opaque
string and never parse or trim it. `Authorization: Bearer <key>` is accepted as a
fallback on the same routes. **Data routes require an organization-scoped key** —
an organization admin creates one in the portal.

### Environments

The SDKs ship pointing at **production** (`https://api.topolab.nl`). Select
staging with the `environment` option (`"production"` | `"staging"`); an explicit
`base_url` overrides it (self-hosting / tests). Resolution precedence,
most-specific first:

1. `base_url` argument
2. `environment` argument
3. `TOPOLAB_BASE_URL` env var
4. `TOPOLAB_ENV` env var (`production` | `staging`)
5. production default

| Environment | Base URL |
|---|---|
| `production` (default) | `https://api.topolab.nl` |
| `staging` | `https://api-staging.topolab.nl` |

```python
Client(api_key="…", environment="staging")          # Python
```
```ts
new Client({ apiKey: "…", environment: "staging" })  // TypeScript
```
```r
tl_client(api_key = "…", environment = "staging")    # R
```
```go
topolab.New(topolab.WithAPIKey("…"), topolab.WithEnvironment("staging")) // Go
```

## Methods

| Op | Python (sync; async mirrors with `await`) | TypeScript | R | Go |
|---|---|---|---|---|
| client | `Client(api_key=)` / `AsyncClient(api_key=)` | `new Client({apiKey})` | `tl_client(api_key=)` | `topolab.New(WithAPIKey(…))` |
| handle | `tl.dataset("slug")` | `tl.dataset("slug")` | `tl_dataset(tl, "slug")` | `tl.Dataset("slug")` |
| catalog | `tl.datasets.list(...)` | `tl.datasets.list({...})` | `tl_datasets(tl, ...)` | `tl.Datasets.List(ctx, …)` |
| metadata | `ds.metadata()` | `ds.metadata()` | `tl_metadata(ds)` | `ds.Metadata(ctx, locale)` |
| sample | `ds.sample(format=)` | `ds.sample({format})` | `tl_sample(ds, format=)` | `ds.Sample(ctx, format)` |
| bulk geojson | `ds.to_geojson()` | `ds.toGeoJSON()` | `tl_geojson(ds)` | `ds.ToGeoJSON(ctx)` |
| download | `ds.download(path, format=)` | `download(ds, path, {format})` (`@topolab/sdk/node`) | `tl_download(ds, path, format=)` | `ds.Download(ctx, path, format)` |
| geo convert | `ds.to_geodataframe()` (`[geo]`) | — (returns typed GeoJSON) | `as_sf(ds)` | — (returns typed GeoJSON) |
| spatial | `ds.items(bbox=, limit=, **filters)` | `ds.items({bbox,limit,...})` | `tl_items(ds, bbox=, ...)` | `ds.Items(ctx, &ItemsOptions{…})` |
| paginate | `ds.iter_items(page_size=, total_limit=)` | `ds.iterItems({...})` | `tl_items_all(ds, ...)` | `ds.IterItems(ctx, …)` / `ds.ItemsAll(ctx, …)` |
| **owned** | `tl.datasets.owned(limit=, offset=)` | `tl.datasets.owned({limit,offset})` | `tl_datasets_owned(tl, ...)` | `tl.Datasets.Owned(ctx, …)` |
| **owned (all)** | `tl.datasets.iter_owned()` | `tl.datasets.iterOwned()` | `tl_datasets_owned_all(tl)` | `tl.Datasets.IterOwned(ctx, …)` |
| **archives** | `ds.archives()` | `ds.archives()` | `tl_archives(ds)` | `ds.Archives(ctx)` |
| **archive** | `ds.archive(path, month=, format=)` | `downloadArchive(ds, path, {month,format})` | `tl_archive(ds, path, month=, format=)` | `ds.Archive(ctx, path, month, format)` |
| **coordinates** | `ds.coordinates(limit=, offset=)` | `ds.coordinates({limit,offset})` | `tl_coordinates(ds, ...)` | `ds.Coordinates(ctx, …)` |
| **sql** | `tl.sql(query, max_rows=)` | `tl.sql(query, {maxRows})` | `tl_sql(tl, query, max_rows=)` | `tl.SQL(ctx, query, …)` |

Formats — **sample:** `csv, json, geojson, kml`. **bulk / archive:** `csv, json, geojson, kml, shp`.
Spatial params: `bbox` `[minLon,minLat,maxLon,maxLat]` (sent as a comma string on
the wire), `limit` (1–1000, default 100), `offset`, filters `category`/`city`/`country`.

## Slug → OGC collection resolution

**The OGC `collectionId` is the dataset slug.** `GET /v1/ogc/collections` emits
slugs, so a handle addresses its collection directly and no metadata round-trip
is needed. The legacy `dataset-{UUID}` form still resolves server-side for old
clients, but SDKs must not construct it.

## Errors

Every error shares one envelope, produced by the engine's global exception filter:

```json
{ "code": 403, "message": "This endpoint requires the api-access add-on",
  "path": "/v1/dataset/{table}/files/geojson", "method": "GET",
  "time": "2026-09-08T23:42:15.819Z", "requestId": "25c2a6a1…" }
```

```json
{ "code": "SPENDING_LIMIT_EXCEEDED",
  "message": "Organization monthly spending limit exceeded",
  "details": { "limit": 5000, "consumed": 4995, "remaining": 5,
               "periodEnd": "2026-11-30T23:59:59.999Z" },
  "path": "/v1/dataset/{table}/files/geojson", "method": "GET",
  "time": "2026-11-07T11:52:28.000Z", "requestId": "8f0c41d2…" }
```

- **There is no `statusCode` field.**
- **`code` is a string or a number.** When the engine throws a named code it is
  that string, always upper-snake (`^[A-Z][A-Z0-9_]{0,63}$`), such as
  `SPENDING_LIMIT_EXCEEDED`. Otherwise it is the numeric HTTP status. `code`
  therefore no longer always equals the HTTP status, and SDKs type it as
  string-or-number.
- **`details`** is present only for the codes and statuses listed below, and
  carries only allow-listed, typed keys. Anything else the server knows stays
  server-side.
- `requestId` is also returned as the `X-Request-Id` header.

SDKs choose the error class from the **HTTP status**, never from a body field, so
the classes below are unchanged. `code` refines the meaning inside a class: a 403
with `SPENDING_LIMIT_EXCEEDED` is still an `AccessDeniedError`.

### Fields on every SDK error

| Field | Python | TypeScript | R | Go |
|---|---|---|---|---|
| HTTP status (always a number) | `.status` (`.status_code` kept) | `.status` (`.statusCode` kept) | `$status` | `.StatusCode` |
| Envelope `code` | `.code`: `str \| int \| None` | `.code`: `string \| number \| undefined` | `$code`: character or integer | `.Code`: `topolab.Code` |
| `details` | `.details`: `dict \| None` | `.details`: `Record<string, unknown> \| undefined` | `$details`: list or `NULL` | `.Details`: `map[string]any` (nil when absent) |
| Request id | `.request_id` | `.requestId` | `$request_id` | `.RequestID` |

- `status` comes from the HTTP response. Callers that relied on `code` being the
  status must read `status` instead.
- When the body carries no usable `code` (for example a proxy's HTML error page),
  `code` falls back to the HTTP status.
- Errors raised before a response exists (network failures, client-side
  validation) have no status, code or details.
- Compare string codes by equality (`err.code == "SPENDING_LIMIT_EXCEEDED"`). Never
  compare `code` with a number to learn the status.

### Known string codes

Codes the SDK surface (datasets, OGC, archives, coordinates, SQL) can return:

| Status | Code | Meaning | `details` |
|---|---|---|---|
| 403 | `SPENDING_LIMIT_EXCEEDED` | A metered call (download, SQL) would pass the organization's monthly spending limit. Surfaces as `AccessDeniedError`. | `limit`, `consumed`, `remaining` (numbers), `periodEnd` (ISO 8601 timestamp) |
| 400 | `SQL_DATA_ERROR` | The SQL query raised a data error while evaluating a value, such as a bad cast. The message names the SQLSTATE. | none |
| 400 | `MAX_NODES_EXCEEDED`, `MAX_DEPTH_EXCEEDED`, `MAX_ARRAY_LENGTH_EXCEEDED`, `MAX_KEYS_EXCEEDED` | A JSON request body is larger or deeper than the server accepts. | none |
| 400 | `PROTOTYPE_POLLUTION_KEY` | A JSON request body contains a forbidden key (`__proto__`, `constructor`, `prototype`). | none |
| 429 | `RATE_LIMIT_EXCEEDED` | The API key passed its per-minute rate limit (see [Rate limits](#rate-limits)). The response also carries `Retry-After`. Surfaces as `RateLimitError`. | `retryAfter` (seconds), `limit`, `remaining` (numbers), `resetAt` (ISO 8601 timestamp) |
| 429 | `USAGE_QUOTA_EXCEEDED` | The API key has used up its usage quota. Waiting does not help, so there is no `retryAfter` and no `Retry-After`. Surfaces as `RateLimitError`. | `quota`, `used` (numbers) |

Codes from other parts of the API, listed so a shared error handler recognises them:

| Status | Code | Meaning | `details` |
|---|---|---|---|
| 403 | `HIGH_VALUE_DATA_REQUIRED` | Data Studio: a pipeline or generated file needs High-Value Data the organization does not hold. | `columns`, `datasetIds` (lists of identifiers) |
| 410 | `REGENERATE_REQUIRED` | Data Studio: the file predates build tracking; run the pipeline again. | none |
| 400 | `METADATA_NOT_READABLE` | Data Studio: a pipeline cannot read the metadata column; select named columns. | none |
| 403 | `SSO_REQUIRED` | Sign-in: the organization enforces single sign-on, so no magic link is sent. | none |
| 503 | `SSO_CHECK_UNAVAILABLE` | Sign-in: the single sign-on lookup failed; try again. | none |
| 400 | `CONFIGURATION_VALIDATION_FAILED`, `UNSUPPORTED_ADDON_SUBTYPE`, `INVALID_TRIGGER_CODE`, `INVALID_DESTINATION_TARGET`, `DESTINATION_HAS_NO_SECRET` | Order add-on and delivery-destination configuration was rejected. | none |
| 404 | `ORG_DESTINATION_NOT_FOUND` | The delivery destination does not exist. | none |

Numeric codes that carry `details`:

| `code` | Meaning | `details` |
|---|---|---|
| `402` | Not enough credits for the call (`InsufficientCreditsError`). | `required`, `available` |
| `413` | A Data Studio upload exceeds the storage quota. | `quotaBytes`, `usageBytes`, `additionalBytes` |

The chat API streams answers as Server-Sent Events and reports a failed turn as an
`error` event, `{type: "error", code, message}`, not as an HTTP error envelope.
Its codes are lower-snake. The AI metering refusals are `ai_busy` (another AI
request for the organization is still running; try again shortly),
`ai_interrupted` (the answer was interrupted and not charged; ask again) and
`ai_cancelled` (the request was cancelled and not charged). The SDKs do not call
the chat API.

### Recognising an add-on requirement

Two message shapes carry an add-on requirement, and a 403 that matches neither is
an access denial:

| Message | Add-on |
|---|---|
| `This endpoint requires the api-access add-on` | `api-access` |
| `Archive access requires the Archived Data add-on. Please upgrade to access historical data.` | `archived-data` |

Add-on identifiers are **hyphenated slugs** (`api-access`, `gis-access`,
`archived-data`, `high-value-data`, `sql-access`). Match with
`requires the (.+?) add-?on` (case-insensitive) and normalise the capture by
lower-casing it and replacing spaces with hyphens, so both shapes yield the same
slug. A `\w+` capture does **not** work — it stops at the hyphen and matches
nothing.

| Trigger | Error | Notes |
|---|---|---|
| 401 | `AuthenticationError` | missing/invalid/revoked key |
| 403 + addon message | `AddonRequiredError` | `.addon` is the normalised slug (`api-access`, `archived-data`, …) |
| 403 (access) on data route | `AccessDeniedError` | unknown **or** unauthorized slug |
| 402 | `InsufficientCreditsError` | body `{required, available}` |
| 404 (metadata route) | `NotFoundError` | unknown slug on `GET /v1/dataset/:table` |
| 400 (non-org key on OGC) | `ConfigurationError` | key not organization-scoped |
| 408 | `QueryTimeoutError` | SQL exceeded the server statement timeout |
| 429 | `RateLimitError` | carries `retry_after`: the `Retry-After` header, else `details.retryAfter`, else a top-level `retryAfter` from older engines; auto-retried |
| other 4xx | `ValidationError` | bad params |
| 5xx | `ServerError` | retried |
| network | `ConnectionError` | transport failure |

## Rate limits

Each API key has its own per-minute request limit, set by the organization's
plan:

| Plan | Requests per minute, per key |
|---|---|
| Free | 60 |
| Team | 300 |
| Enterprise | 1,000 |

Every response to an API-key request reports the key's window in these headers:

| Header | Meaning |
|---|---|
| `X-RateLimit-Limit-ApiKey` | Requests allowed per minute for this key |
| `X-RateLimit-Remaining-ApiKey` | Requests left in the current window |
| `X-RateLimit-Reset-ApiKey` | Seconds until the window resets |

A key with a usage quota also gets `X-Quota-Limit`, `X-Quota-Used` and
`X-Quota-Remaining`. The unsuffixed `X-RateLimit-*` headers (and their
`-short`, `-medium` and `-long` variants) belong to the service-wide throttler,
not to the key.

Passing the key's limit answers **429** with the `RATE_LIMIT_EXCEEDED` code and a
`Retry-After` header (whole seconds, rounded up):

```json
{ "code": "RATE_LIMIT_EXCEEDED", "message": "Rate limit exceeded",
  "details": { "retryAfter": 42, "limit": 300, "remaining": 0,
               "resetAt": "2026-11-07T12:01:00.000Z" },
  "path": "/v1/dataset/{table}/files/geojson", "method": "GET",
  "time": "2026-11-07T12:00:18.000Z", "requestId": "4d6f8a0c…" }
```

Using up the key's usage quota answers **429** with `USAGE_QUOTA_EXCEEDED` and
`details: {quota, used}`, and no wait, because waiting does not help.

SDKs retry a 429 after the server's wait, read in this order:

1. the `Retry-After` header (delay-seconds, or an HTTP date per RFC 9110);
2. `details.retryAfter` (seconds);
3. a top-level `retryAfter` (engines older than the `RATE_LIMIT_EXCEEDED` code).

With none of these they fall back to exponential backoff. `RateLimitError`
exposes the same value as its retry-after field.

## Pulling data you own

The integration loop these SDKs are built for — discover what the organization
licences, then pull each dataset's newest snapshot — needs no hard-coded slugs:

```python
for ds in tl.datasets.iter_owned():
    tl.dataset(ds.table).archive(f"{ds.table}.zip", month="latest", format="geojson")
```

`owned()` is authoritative: it is filtered by the same licence check the download
routes enforce, so everything it returns is downloadable. Each entry also carries
absolute `links`, letting an integration follow URLs instead of building paths.

### Addressing an archive

`month` accepts three forms:

| Value | Meaning |
|---|---|
| `latest` | Newest archive inside your plan's retention window |
| `YYYY-MM` | That month |
| `YYYY-MM-DD` | The month containing that date |

A malformed or impossible month (`2026-13`, `2026-07-99`) is a **400**. A real
month with no archive available is a **404** — as are months outside your
retention window and months that have not started, which are deliberately
indistinguishable so the response never reveals an archive you cannot access.

### Retention

Team plans see a trailing 12 months of archives; Enterprise and full-history
add-ons see everything. `archives()` already reflects your window, so it never
lists a month that would 404.

## SQL access

`tl.sql(...)` requires the `sql-access` entitlement, which is part of the
Enterprise plan and is not sold separately. Queries run read-only against the
datasets you licence: a single `SELECT` (or `WITH`), no DDL/DML, no system
catalogues, and every relation the planner resolves must be a dataset your
organization holds an active licence for.
