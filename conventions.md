# Topolab SDK Conventions

The canonical surface every SDK implements idiomatically. The machine-readable
form is [`conventions.yaml`](conventions.yaml); each SDK lints against it.

## Construction

API key from an explicit argument or the `TOPOLAB_API_KEY` environment variable.
`base_url` defaults to `https://api.topolab.nl` (override for staging via arg or
`TOPOLAB_BASE_URL`). Auth is the `X-API-Key` header (`tlb_{env}_...`). **Data
routes require an organization-scoped key.**

## Methods

| Op | Python (sync; async mirrors with `await`) | TypeScript | R |
|---|---|---|---|
| client | `Client(api_key=)` / `AsyncClient(api_key=)` | `new Client({apiKey})` | `tl_client(api_key=)` |
| handle | `tl.dataset("slug")` | `tl.dataset("slug")` | `tl_dataset(tl, "slug")` |
| catalog | `tl.datasets.list(...)` | `tl.datasets.list({...})` | `tl_datasets(tl, ...)` |
| metadata | `ds.metadata()` | `ds.metadata()` | `tl_metadata(ds)` |
| sample | `ds.sample(format=)` | `ds.sample({format})` | `tl_sample(ds, format=)` |
| bulk geojson | `ds.to_geojson()` | `ds.toGeoJSON()` | `tl_geojson(ds)` |
| download | `ds.download(path, format=)` | `download(ds, path, {format})` (`@topolab/sdk/node`) | `tl_download(ds, path, format=)` |
| geo convert | `ds.to_geodataframe()` (`[geo]`) | — (returns typed GeoJSON) | `as_sf(ds)` |
| spatial | `ds.items(bbox=, limit=, **filters)` | `ds.items({bbox,limit,...})` | `tl_items(ds, bbox=, ...)` |
| paginate | `ds.iter_items(page_size=, total_limit=)` | `ds.iterItems({...})` | `tl_items_all(ds, ...)` |

Formats — **sample:** `csv, json, geojson, kml`. **bulk:** `csv, json, geojson, kml, shp`.
Spatial params: `bbox` `[minLon,minLat,maxLon,maxLat]` (sent as a comma string on
the wire), `limit` (1–1000, default 100), `offset`, filters `category`/`city`/`country`.

## Slug → OGC collection resolution

OGC collections are keyed by `dataset-{UUID}`, not the slug. On a handle's first
`items()`/`iter_items()` call the SDK fetches metadata once to read the dataset
`id`, builds `dataset-{id}`, and caches it for the session.

## Errors

| Trigger | Error | Notes |
|---|---|---|
| 401 | `AuthenticationError` | missing/invalid/revoked key |
| 403 + addon body | `AddonRequiredError` | message names the addon (`API_ACCESS`/`GIS_ACCESS`) |
| 403 (access) on data route | `AccessDeniedError` | unknown **or** unauthorized slug |
| 402 | `InsufficientCreditsError` | body `{required, available}` |
| 404 (metadata route) | `NotFoundError` | unknown slug on `GET /v1/dataset/:table` |
| 400 (non-org key on OGC) | `ConfigurationError` | key not organization-scoped |
| 429 | `RateLimitError` | carries `retry_after` (body, later header); auto-retried |
| other 4xx | `ValidationError` | bad params |
| 5xx | `ServerError` | retried |
| network | `ConnectionError` | transport failure |
