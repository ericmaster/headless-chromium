# Headless Chromium

A self-hosted, always-on Chromium instance in Docker that is **shared between human operators and AI agents**.

- **Agents** drive it headlessly over the Chrome DevTools Protocol (CDP) on `127.0.0.1:9222` using Playwright, Puppeteer, or any CDP client.
- **Humans** watch or take over the *same* live session through a KasmVNC web UI in the browser.

Because it's one long-lived browser, logged-in sessions (Google, etc.) persist across automation runs, and a human can jump in to solve a captcha, complete an OAuth flow, or debug what an agent is doing — on the exact same tabs.

## Why

Automating logged-in web apps usually means either re-authenticating on every run or copying cookies around. This tool keeps a single authenticated browser alive so agents can attach on demand, while a human retains visual access and manual control when a flow needs a real person.

## Stack

| Component | Detail |
|-----------|--------|
| Browser   | [`lscr.io/linuxserver/chromium`](https://docs.linuxserver.io/images/docker-chromium/) (KasmVNC) |
| CDP bridge | `alpine/socat` (see [AGENTS.md](AGENTS.md) for why a bridge is needed) |
| Web UI    | `https://127.0.0.1:3011` (HTTPS, self-signed) |
| CDP endpoint | `http://127.0.0.1:9222` |

## Quick start

The KasmVNC web password (`CHROMIUM_PASSWORD`) can come from either source, tried in that order:

1. **Infisical** — set `INFISICAL_PROJECT_ID=<uuid>` in `.env` (secret name `CHROMIUM_PASSWORD`). Auth credentials (`INFISICAL_CLIENT_ID`/`INFISICAL_CLIENT_SECRET`/`INFISICAL_API_URL`) come from the host's global profile, not this repo — see [AGENTS.md](AGENTS.md).
2. **Plain `.env`** — set `CHROMIUM_PASSWORD=<your-password>` directly in `.env` (gitignored). Used if Infisical isn't configured, or as a fallback if the fetch fails.

```bash
# Either populate .env as above, then:
./start.sh
```

`start.sh` resolves the password (Infisical or `.env`) and runs `docker compose up -d`. You can still run `docker compose up -d` directly if `CHROMIUM_PASSWORD` is already exported or set in `.env`.

Then open the web UI at `https://127.0.0.1:3011` (user `eric`), or connect an agent:

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

Stop with `docker compose down`. The Google login and other session state persist in the `/config` volume.

## Shared-browser etiquette

This browser is shared. **Always open your own tab (`context.newPage()`) and close only what you opened** — never grab `pages()[0]`, which belongs to the human or to another agent's in-flight session, and hijacking it steals that session.

## Security

- **The CDP port (`9222`) has NO authentication** — anyone who reaches it gets full control of a browser holding live logins. Keep it **loopback-only**; never tunnel, proxy, or publish it.
- The KasmVNC web UI (`3011`) is loopback-bound and reached externally only through a Cloudflare Tunnel + Access.
- The KasmVNC password comes from Infisical or `.env` (gitignored) — see Quick start. Nothing sensitive is committed.

## More

See **[AGENTS.md](AGENTS.md)** for the full working context: network/CDP bridging internals, credentials handling, the security trust boundary, and connection details. The `skills/local-browser/` skill teaches agents how to use this instance.
