---
title: Use React DOM Resource Hints
impact: HIGH
impactDescription: starts loading critical resources earlier in the request lifecycle
tags: rendering, preload, preconnect, prefetch, resource-hints, react-19
---

## Use React DOM Resource Hints

React 19's `react-dom` exposes APIs that emit resource hints into the document head from anywhere in your component tree. The browser starts DNS resolution, TCP/TLS handshake, or resource fetch in parallel with the rest of your render.

| API | Use case |
|-----|----------|
| `prefetchDNS(href)` | Resolve DNS for a domain you might connect to later |
| `preconnect(href)` | Establish DNS + TCP + TLS to a server you'll fetch from immediately |
| `preload(href, options)` | Fetch a resource (stylesheet, font, script, image) you'll use soon |
| `preloadModule(href)` | Fetch an ES module you'll use soon |
| `preinit(href, options)` | Fetch **and evaluate** a stylesheet or script |
| `preinitModule(href)` | Fetch **and evaluate** an ES module |

These calls are idempotent — calling them multiple times during a render is safe; React dedupes them.

**Example — preconnect to API and analytics domains as the app boots:**

```tsx
import { preconnect, prefetchDNS } from 'react-dom'

export function App() {
  preconnect('https://api.example.com')          // we'll fetch from here right away
  prefetchDNS('https://analytics.example.com')   // we'll fetch from here later

  return <Routes />
}
```

**Example — preload a critical font:**

```tsx
import { preload } from 'react-dom'

export function App() {
  preload('/fonts/inter.woff2', {
    as: 'font',
    type: 'font/woff2',
    crossOrigin: 'anonymous',
  })

  return <Layout>...</Layout>
}
```

**Example — preload a lazy route's module on hover:**

```tsx
import { preloadModule } from 'react-dom'

function NavLink({ to, chunkHref }: { to: string; chunkHref: string }) {
  return (
    <a
      href={to}
      onMouseEnter={() => preloadModule(chunkHref, { as: 'script' })}
      onFocus={() => preloadModule(chunkHref, { as: 'script' })}
    >
      Go
    </a>
  )
}
```

For dynamic `import()` preloading without specifying a chunk URL, see [Preload Based on User Intent](../bundle/preload.md).

Reference: [React DOM Resource Preloading APIs](https://react.dev/reference/react-dom#resource-preloading-apis)
