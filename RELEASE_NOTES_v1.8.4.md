# v1.8.4 - Reliable Playwright browser fallback

This patch fixes requirement-document screenshots failing after dependency installation because Playwright 1.58+ moved Chromium to Chrome for Testing URLs while the installer still configured only the legacy Playwright mirror root.

## What failed

The package intentionally allows supported Playwright updates with `playwright>=1.48.0`. Each Playwright release requires a matching Chromium revision. On September 24, 2026, Playwright 1.58.0 required Chromium revision 1208 (Chrome 145.0.7632.6). With only `PLAYWRIGHT_DOWNLOAD_HOST` configured, Playwright generated a `binaries/playwright/...` Chrome for Testing URL that returned HTTP 404. The same Chrome and headless-shell archives were available under npmmirror's dedicated `binaries/chrome-for-testing/...` path. The Python dependencies and text APIs still worked, but full visual PRD analysis failed when Chromium launched.

## Fixed

- Source installers set both npmmirror roots: the Playwright mirror for FFmpeg and legacy artifacts, plus the Chrome for Testing mirror for Chromium and its headless shell.
- Installers try the modern dual-mirror configuration first, the legacy npmmirror layout second, and the official Playwright CDN last.
- User-provided `PLAYWRIGHT_DOWNLOAD_HOST` or `PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST` values remain authoritative and are not silently bypassed.
- Linux/macOS and Windows launch scripts use the same fallback policy.
- Windows CI now runs the browser installation inside `easy-install.bat`, then launches Chromium and completes an MCP stdio handshake.
- README troubleshooting includes commands that clear a stale mirror override and install the browser matching the current Playwright package.

## Validation

The incorrect legacy-only URL was reproduced as HTTP 404. Direct range requests to the corrected npmmirror URLs for Chromium revision 1208, its matching headless shell, and FFmpeg 1011 all returned HTTP 206. Playwright's own `--dry-run` output confirmed that the dual environment variables resolve every artifact to those available domestic paths. An official-CDN installation was also completed as the final fallback validation.

A live Lanhu Axure document with three pages was then analyzed in `full` mode. The MCP stdio response contained:

- three `image/png` contents,
- the header and extracted page text contents,
- screenshots measuring 1920×1080, 1920×1256, and 1920×1080.

The 1256-pixel page confirms that capture still uses the full document height rather than clipping to the 1080-pixel viewport. No real account Cookie is included in the repository, tests, CI configuration, or release artifacts.
