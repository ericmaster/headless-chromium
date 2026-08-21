# Headless Chromium - Agent Working Context

This tool manages a self-hosted Headless Chromium instance running in a Docker container with KasmVNC visual access and an exposed Chrome DevTools Protocol (CDP) port.

It is designed to serve as a **shared browser between human operators and AI agents**: agents connect headlessly via Playwright/Puppeteer/CDP on port `9222`, while humans visually monitor or take control of the same session on port `3011`. Any agent or automated job needing a real, logged-in browser (auth keepalives, scraping, UI verification, etc.) can attach here rather than standing up its own Chromium instance.

## Stack
- **Docker Image**: `lscr.io/linuxserver/chromium:latest`
- **CDP Bridge**: `alpine/socat`
- **Web UI (KasmVNC, HTTPS only)**: https://chromium.nimblersoft.com (Internal fallback: https://127.0.0.1:3011 — self-signed cert)
- **CDP Endpoint**: http://127.0.0.1:9222

## Credentials
- **Username**: `eric`
- **Password**: not stored here. Resolved by `scripts/resolve-password.sh` (sourced by `start.sh`) via `load-secrets`, using the project ID in `.infisical.env` and the `CHROMIUM_PASSWORD` secret. Auth comes from the host's global Infisical configuration — never put credentials in this repo.
- The resolved value is written to `~/.headless-chromium-webpass.txt` for the human to read, and exported for `docker compose`'s `${CHROMIUM_PASSWORD}` substitution. To rotate: update the Infisical secret, then `./start.sh` to recreate.
- Cloudflare Access (`eric@nimblersoft.com`) gates the public hostname; the KasmVNC basic-auth password above is a second factor and is independent of CF Access SSO.

## Security / trust boundary (read before exposing anything)
- **The CDP port (9222) has NO authentication.** Anyone who can reach `127.0.0.1:9222` on this host gets full control of this browser — which holds live Google / Meta Business / WhatsApp logins. Keep it **loopback-only**; never publish, tunnel, or proxy 9222 beyond `127.0.0.1`. `--remote-allow-origins=*` is acceptable *only* because the port is loopback-bound.
- KasmVNC (3011) is loopback-only on the host and reached externally solely through the Cloudflare Tunnel + Access app.

## Shared-browser etiquette (IMPORTANT)
This browser is shared between a human and multiple agents/automated jobs. Automation must never disturb tabs it does not own:
- **Always create your own page** (`context.newPage()` / `browser.newPage()`). **Never** grab `contexts()[0].pages()[0]` — that is the human's (or keepalive's) live tab, and navigating it hijacks their session.
- **Close only the page(s) you created**, then disconnect.
- Over a `connectOverCDP` connection, Playwright's `browser.close()` only clears *your* contexts and disconnects — the remote Chrome (and the human's tabs) keep running. Puppeteer's `browser.disconnect()` is the equivalent. Either is safe; closing the human's tabs is not.

## Network Architecture & CDP Port Bridging
Because Chromium's `--remote-debugging-port` binds to `127.0.0.1` inside the container network namespace, standard Docker port mappings cannot route host traffic directly to it. To resolve this:
1. `cdp-bridge` runs in the same network namespace as the `chromium` container (`network_mode: service:chromium`).
2. `cdp-bridge` runs `socat` to listen on port `9223` and forward to `127.0.0.1:9222`.
3. The host maps `127.0.0.1:9222` → the bridge's `9223`.

## Playwright / Puppeteer Connection Code
Connect to the running browser via the CDP endpoint, **on your own tab**:

```typescript
import { chromium } from 'playwright';

const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
const context = browser.contexts()[0];   // shared default context
const page = await context.newPage();     // YOUR OWN tab — never reuse pages()[0]
try {
  await page.goto('https://example.com');
  console.log(await page.title());
} finally {
  await page.close();                     // close only the tab you opened
  await browser.close();                  // over CDP: disconnects; shared Chrome keeps running
}
```

## Management
Start: `./start.sh` (resolves `CHROMIUM_PASSWORD` then `docker compose up -d`) · Stop: `docker compose down`
(Recreating the container closes current tabs, but the Google login persists in the `/config` volume at `~/.headless-chromium-config`.)
