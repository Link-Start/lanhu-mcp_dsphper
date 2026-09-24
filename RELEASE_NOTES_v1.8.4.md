# v1.8.4 - Restore fast requirement analysis and reliable browser installation

This patch restores the fast requirement-document behavior users had before v1.8.x and fixes Playwright browser installation through domestic mirrors.

## Requirement document timeout fix

The requirement tools had several latent costs that were not covered by the release tests. `text_only` still scanned every DOM style and captured a full-page PNG, every page waited for `networkidle` plus a fixed two-second delay, the sitemap was requested twice in one analysis call, and a cache hit still contacted Lanhu before returning. Relative `DATA_DIR` values also followed the MCP client's working directory, which could make an existing cache appear missing.

v1.8.4 changes that behavior:

- `text_only` extracts text and annotations without scanning design styles or taking screenshots.
- Replacing only `lanhu_mcp_server.py` no longer crashes when `lanhu_design` is absent; requirement tools continue to work while advanced design tools report that the full package is required.
- Axure rendering waits for bounded DOM/page readiness instead of `networkidle` and the fixed delay.
- One fetched sitemap is reused for download and analysis.
- A matching versioned cache can return without any Lanhu request.
- Relative `DATA_DIR` values resolve against the `.env` directory, or the source directory when no `.env` exists.
- Cache metadata now stores the page list so later versioned calls can be fully offline.

Existing caches without the stored page list perform one normal request to upgrade their metadata. Later calls use the offline fast path.

## Playwright browser installation fix

Playwright 1.58+ moved Chromium to Chrome for Testing URLs while the installer configured only the legacy Playwright mirror root. The installers now configure both npmmirror roots, retain the legacy layout fallback, and finally fall back to the official Playwright CDN. User-provided mirror overrides remain authoritative.

## Validation

A live three-page Lanhu Axure document was measured through the same requirement path:

| Path | Result |
|---|---:|
| v1.8.3 full cold render | 10.118 s |
| v1.8.4 text-only cold render | 2.428 s |
| v1.8.4 full cold render | 2.565 s |
| v1.8.4 MCP text-only cold call | 5.329 s |
| v1.8.4 MCP text-only warm call | 0.135 s |
| v1.8.4 MCP full warm call | 0.136 s |

The full MCP response still contained three PNG images and extracted text. Captures measured 1920×1080, 1920×1256, and 1920×1080, confirming full-page capture.

Regression tests verify that exact-version caches make no network request, analysis does not request the sitemap twice, and text-only mode does not request screenshots or design styles. Package, source installer, browser launch, and MCP stdio checks remain part of release validation.

No real account Cookie is included in the repository, tests, CI configuration, or release artifacts.
