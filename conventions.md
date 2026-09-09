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

**There is no `statusCode` field** — the numeric status is `code`, and it always
equals the HTTP status. SDKs must branch on the **HTTP status**, never on a body
field. `requestId` is also returned as the `X-Request-Id` header.

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
| 429 | `RateLimitError` | carries `retry_after` (body, later header); auto-retried |
| other 4xx | `ValidationError` | bad params |
| 5xx | `ServerError` | retried |
| network | `ConnectionError` | transport failure |

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
