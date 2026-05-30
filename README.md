# topolab-sdk-spec

Source of truth for the Topolab client SDKs (Python, TypeScript, R).

- `openapi.json` — committed snapshot of the public API (curated to the dataset + OGC surface the SDKs wrap).
- `conventions.yaml` — machine-readable canonical method/parameter/error surface every SDK must expose.
- `conventions.md` — human-readable mirror of the surface.
- `fixtures/` — golden HTTP responses shared by all SDK test suites.
- `examples/` — the advertised `example.{py,js,r}` snippets, run in CI against the fixtures.
- `scripts/sync-spec.sh` — refresh `openapi.json` from a running engine.

See [`conventions.md`](conventions.md) for the human-readable surface and
[`../docs/superpowers/specs/2026-05-30-client-sdks-design.md`](../docs/superpowers/specs/2026-05-30-client-sdks-design.md)
for the design.

## Repos that consume this

| Repo | Package |
|---|---|
| `topolab-python` | `topolab` (PyPI) |
| `topolab-js` | `@topolab/sdk` (npm) |
| `topolab-r` | `topolab` (CRAN) |

Each SDK's CI checks this repo out side-by-side so its tests can read `../topolab-sdk-spec/fixtures` and `../topolab-sdk-spec/conventions.yaml`.
