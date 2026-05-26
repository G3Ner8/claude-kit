---
title: Defer Third-Party Scripts Until After First Paint
impact: HIGH
impactDescription: analytics, chat widgets, A/B test libraries can each add 100-500 ms of blocking work — defer them and the user sees content sooner
tags: bundle, third-party, async, defer, lcp
---

## Defer Third-Party Scripts Until After First Paint

Analytics (GA, Mixpanel), chat widgets (Intercom, Drift), tag managers (GTM), session replay (FullStory, Hotjar), and A/B test SDKs all share a property: they don't affect what the user sees on first paint. Loading them eagerly delays Largest Contentful Paint (LCP) for nothing.

The fix is to defer their load until after the first paint, using either:

1. **`<script async>` or `<script defer>`** — the script downloads in parallel but executes after parse/paint.
2. **Manual injection from `requestIdleCallback` or post-mount** — full control over when the work happens.
3. **The browser's `idle-prerender` heuristics** — `<link rel="preconnect">` warms the connection without loading the script.

**Incorrect — synchronous script in `<head>`:**

```html
<head>
  <script src="https://cdn.intercom.io/widget.js"></script>
  <script src="https://www.googletagmanager.com/gtm.js?id=GTM-XXX"></script>
</head>
```

These two scripts can add 300-500 ms to LCP because the browser parses + executes them before continuing.

**Correct (option 1) — `async` / `defer`:**

```html
<head>
  <script src="https://cdn.intercom.io/widget.js" async></script>
  <script src="https://www.googletagmanager.com/gtm.js?id=GTM-XXX" defer></script>
</head>
```

`async` = "download in parallel, execute as soon as ready (may block parsing briefly)". Good for fire-and-forget like GTM.

`defer` = "download in parallel, execute *after* HTML parsing is done". Best when the script touches the DOM (it'll wait for the DOM to be ready).

**Correct (option 2) — explicit post-mount injection:**

```tsx
// In your root App component
useEffect(() => {
  const idleCallback = window.requestIdleCallback ?? window.setTimeout;
  const handle = idleCallback(() => {
    const script = document.createElement('script');
    script.src = 'https://cdn.intercom.io/widget.js';
    script.async = true;
    document.body.appendChild(script);
  }, { timeout: 2000 });

  return () => {
    if (typeof handle === 'number') clearTimeout(handle);
    else cancelIdleCallback(handle);
  };
}, []);
```

`requestIdleCallback` waits until the main thread is idle — meaning first paint and any input handling have already completed. The script then loads without competing with rendering work.

## Preconnecting in advance

If you'll definitely load the script (just not yet), warm the TCP/TLS handshake while the rest of the page parses:

```html
<head>
  <link rel="preconnect" href="https://cdn.intercom.io" crossorigin>
</head>
```

This costs ~0 bytes and saves the connection handshake (~100-300 ms) when the script finally loads.

## When NOT to apply

- **Scripts the first paint actually depends on** — fonts loaded via a JavaScript loader, a feature-flag SDK whose flags drive visible UI. These have to load eagerly (or you accept the LCP cost).
- **Critical security/anti-fraud scripts** — some fraud-detection vendors require their script to load before any form. Read their integration docs before deferring.
- **GA4 with `send_page_view: true`** — defers automatically. Don't add more deferral on top; you may miss page-view events.

## Verify

In Chrome DevTools → Performance → record a page load. Look for third-party scripts in the main thread timeline. They should appear *after* the LCP marker, not before.

## Related

- [`preload`](./preload.md) — for scripts you *do* need on the critical path, preload them so they're cached when the parser hits the `<script>` tag.
