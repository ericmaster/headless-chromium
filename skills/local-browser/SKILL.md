---
name: local-browser
description: Use or connect to the running Headless Chromium browser instance via CDP/Playwright/Puppeteer for testing, browser automation, or web scraping.
---

# local-browser

Use this skill when you need to perform browser automation, end-to-end testing, visual verification, or web scraping using the shared local Headless Chromium browser instance.

## Connection Details
The browser runs as a shared persistent container service with:
* **Chrome DevTools Protocol (CDP) Endpoint**: `http://127.0.0.1:9222`
* **Visual VNC Web Interface (KasmVNC, HTTPS only)**: `https://chromium.nimblersoft.com` (Internal fallback: `https://127.0.0.1:3011` — self-signed cert)
  * **Username**: `eric`
  * **Password**: read it from `~/.headless-chromium-webpass.txt` (not stored in this repo)

## ⚠️ This browser is SHARED — etiquette
A human and other agents/automated jobs use this same browser. Automation must never disturb tabs it does not own:
* **Always open your own tab** with `context.newPage()` / `browser.newPage()`. **Never** operate on `contexts()[0].pages()[0]` — that is someone else's live tab, and `page.goto()` on it hijacks their session.
* **Close only the page(s) you created**, then disconnect.
* Over a `connectOverCDP` connection, `browser.close()` only clears *your* contexts and disconnects; the remote Chrome and the human's tabs keep running. It is safe — closing the human's tabs is not.
* The CDP port (9222) is **unauthenticated** and holds live Google/Meta/WhatsApp logins — it is loopback-only by design; never tunnel or proxy it.

## Step-by-Step Connection Instructions

### 1. Ensure the Browser is Running
Before connecting, verify the docker containers are active. If not, start them:
```bash
cd /home/ericmaster/tools/headless-chromium
./start.sh
```

### 2. Connect via Playwright (Node.js / TypeScript)
Use `connectOverCDP` to attach, and operate on **your own** page:
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
  await browser.close();                  // over CDP this disconnects; shared Chrome stays up
}
```

### 3. Connect via Playwright (Python)
```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp("http://127.0.0.1:9222")
    context = browser.contexts[0]          # shared default context
    page = context.new_page()              # YOUR OWN tab — never reuse pages[0]
    try:
        page.goto("https://example.com")
        print(page.title())
    finally:
        page.close()                       # close only the tab you opened
        browser.close()                    # disconnects; shared Chrome stays up
```

### 4. Connect via Puppeteer (Node.js)
```javascript
const puppeteer = require('puppeteer-core');

(async () => {
  // Fetch the ws endpoint dynamically from /json/version (webSocketDebuggerUrl).
  const { webSocketDebuggerUrl } = await fetch('http://127.0.0.1:9222/json/version').then(r => r.json());
  const browser = await puppeteer.connect({ browserWSEndpoint: webSocketDebuggerUrl });

  const page = await browser.newPage();    // YOUR OWN tab
  try {
    await page.goto('https://example.com');
    console.log(await page.title());
  } finally {
    await page.close();
    await browser.disconnect();            // never browser.close() a shared instance
  }
})();
```
