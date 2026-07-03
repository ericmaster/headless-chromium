# Headless Chromium

A self-hosted, always-on Chromium instance in Docker that is **shared between human operators and AI agents**.

- **Agents** drive it headlessly over the Chrome DevTools Protocol (CDP) on `127.0.0.1:9222` using Playwright, Puppeteer, or any CDP client.
- **Humans** watch or take over the *same* live session through a KasmVNC web UI in the browser.

Because it's one long-lived browser, logged-in sessions (Google, etc.) persist across automation runs, and a human can jump in to solve a captcha, complete an OAuth flow, or debug what an agent is doing — on the exact same tabs.

## Why

Automating logged-in web apps usually means either re-authenticating on every run or copying cookies around. This tool keeps a single authenticated browser alive so agents can attach on demand, while a human retains visual access and manual control when a flow needs a real person. It also backs a NotebookLM auth keepalive that re-extracts Google cookies over CDP.

## Stack

| Component | Detail |
|-----------|--------|
| Browser   | [`lscr.io/linuxserver/chromium`](https://docs.linuxserver.io/images/docker-chromium/) (KasmVNC) |
| CDP bridge | `alpine/socat` (see [AGENTS.md](AGENTS.md) for why a bridge is needed) |
| Web UI    | `https://127.0.0.1:3011` (HTTPS, self-signed) |
| CDP endpoint | `http://127.0.0.1:9222` |

## Quick start

```bash
# 1. Set the KasmVNC web password (never commit this)
echo "CHROMIUM_PASSWORD=<your-password>" > .env

# 2. Launch
docker compose up -d
```

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

This browser is shared. **Always open your own tab (`context.newPage()`) and close only what you opened** — never grab `pages()[0]`, which belongs to the human (or the keepalive) and hijacks their session.

## Security

- **The CDP port (`9222`) has NO authentication** — anyone who reaches it gets full control of a browser holding live logins. Keep it **loopback-only**; never tunnel, proxy, or publish it.
- The KasmVNC web UI (`3011`) is loopback-bound and reached externally only through a Cloudflare Tunnel + Access.
- Secrets live in `.env` (gitignored). Nothing sensitive is committed.

## More

See **[AGENTS.md](AGENTS.md)** for the full working context: network/CDP bridging internals, credentials handling, the security trust boundary, and connection details. The `skills/local-browser/` skill teaches agents how to use this instance.
