# Changelog

## [0.1.0]
- Initial spec snapshot, conventions, fixtures, and examples.
- Defines the read-only v1 surface shared by the Python, TypeScript, and R SDKs:
  client construction + options, `dataset()` / `datasets.list` / `metadata` /
  `sample` / `to_geojson` / `download` / `items` / `iter_items`, the error
  taxonomy, and `X-API-Key` auth on data routes.
- OGC `collectionId` is the dataset slug (`table`); all SDKs address
  `/v1/ogc/collections/{slug}/items` directly.
