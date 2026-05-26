---
title: Preload Likely-Next Chunks
impact: MEDIUM
impactDescription: shaves the chunk-fetch latency off navigations the user is about to make — typically saves 100-400 ms on click-through
tags: bundle, preload, prefetch, modulepreload, navigation
---

## Preload Likely-Next Chunks

If a lazy chunk will likely be needed soon (the user is hovering a link, focused a button, or just landed on a page where the next view is highly predictable), start the fetch *now* instead of waiting for the click.

The mechanism:

- **`<link rel="modulepreload">`** — hints the browser to fetch + parse a JS module file in the background, at high priority.
- **`<link rel="prefetch">`** — same idea but lower priority (fits in idle time). Better for "might use later" guesses.
- **Calling `import()` without awaiting** — manually triggers the chunk fetch from JS.

The user-perceived effect: when they click, the chunk is already cached. Render is instant.

**Incorrect — link click triggers a cold chunk fetch:**

```tsx
function Nav() {
  return (
    <Link to="/reports">Reports</Link>     // click -> 300 ms chunk fetch -> render
  );
}
```

The 300 ms feels like a stall.

**Correct (option 1) — prefetch on hover/focus:**

```tsx
import { lazy } from 'react';

const Reports = lazy(() => import('./pages/Reports'));

function NavLink({ to, children }: { to: string; children: ReactNode }) {
  const onPrefetch = () => {
    if (to === '/reports') void import('./pages/Reports');  // start fetch; ignore result
  };
  return (
    <Link to={to} onMouseEnter={onPrefetch} onFocus={onPrefetch}>
      {children}
    </Link>
  );
}
```

Hovering or tab-focusing the link starts the fetch. By the time the user actually clicks, the chunk is in the cache.

**Correct (option 2) — declarative preload tag:**

```tsx
import { preload } from 'react-dom';      // React 19 resource-hint helper

function ReportsRoutePreloader() {
  // Called eagerly when the parent layout mounts — typically a dashboard
  // where the next click is statistically a report.
  preload('/chunks/reports.js', { as: 'script' });
  return null;
}
```

React 19 ships a `preload` hook that injects a `<link rel="modulepreload">` tag at the document head. The browser handles the fetch with high priority.

## Router-level prefetch

If you use a router that ships its own prefetch primitive, use it:

- React Router 7: `<Link prefetch="intent">` (prefetches on hover/focus).
- TanStack Router: `<Link preload="intent">`.

These do exactly what option 1 does, declaratively. Prefer them over hand-rolling the hover handler.

## When NOT to apply

- **Low-bandwidth users** — aggressive prefetching wastes data on chunks the user never visits. The Save-Data header (`navigator.connection.saveData`) is the signal to back off.
- **Many candidate destinations** — if a page has 20 nav links, you can't prefetch all 20 on mount. Prefetch only the top 1-2 by traffic, or wait for hover.
- **Critical-path chunks** — these shouldn't be lazy in the first place. Don't preload to mask a lazy boundary that shouldn't exist.

## Verify

Network tab: after the prefetch trigger, the chunk request should appear with Initiator = "preload" or "link" and Priority = "Low" (prefetch) or "High" (modulepreload). On click, the chunk should come from `(disk cache)` or `(memory cache)`.

## Related

- [`dynamic-imports`](./dynamic-imports.md) — the chunks you preload are typically produced by `React.lazy`.
- [`render-output/resource-hints`](../render-output/resource-hints.md) — same concept for fonts, images, API endpoints (not just scripts).
