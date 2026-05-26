---
title: React 19 Resource Hints — `preload` / `preconnect` / `preinit`
impact: MEDIUM
impactDescription: tells the browser to warm connections and fetch critical resources in parallel with parse — saves 100-500 ms on hero images, fonts, and API endpoints
tags: render-output, resource-hints, react19, preload, preconnect
---

## React 19 Resource Hints — `preload` / `preconnect` / `preinit`

React 19 ships first-class DOM-hook helpers for resource hints. Call them from components (or from a root layout); React injects the appropriate `<link>` tag into the document head, deduped across the tree.

Three hooks, three jobs:

| Hook | Equivalent `<link>` | Use for |
|---|---|---|
| `preconnect(url)` | `<link rel="preconnect" href={url}>` | Origins you'll fetch from soon (API host, image CDN). |
| `preload(url, opts)` | `<link rel="preload" href={url} as={opts.as}>` | Specific files you know will be needed in the next few hundred ms (fonts, hero image, route chunk). |
| `preinit(url, opts)` | `<link rel="modulepreload"\|"preload">` + executes | Scripts and stylesheets that should download AND execute eagerly. |

Together they shave the connection handshake + the round-trip from the critical path.

**Incorrect — browser waits to discover what it needs as it parses:**

```tsx
function HeroSection() {
  return (
    <section>
      <img src="https://cdn.example.com/hero.jpg" />     {/* CDN connection cold */}
      <Greeting fontFamily="Inter" />                    {/* font discovered late */}
    </section>
  );
}
```

The browser only learns about `cdn.example.com` and the Inter font when it parses these elements. The TCP/TLS handshake to the CDN delays the image; the font triggers a Flash of Invisible Text.

**Correct — hints in the layout above:**

```tsx
import { preconnect, preload, preinit } from 'react-dom';

function RootLayout({ children }: { children: ReactNode }) {
  // Warm the CDN connection ASAP — handshake happens in parallel with HTML parse.
  preconnect('https://cdn.example.com', { crossOrigin: 'anonymous' });

  // Preload the hero image with high priority.
  preload('https://cdn.example.com/hero.jpg', { as: 'image' });

  // Preload + execute the font CSS.
  preinit('https://fonts.example.com/inter.css', { as: 'style' });

  return <div>{children}</div>;
}
```

By the time the parser hits `<img src="…/hero.jpg">`, the connection is warm and the file is in the browser's preload cache. The render is instant.

## When to call

- **`preconnect`** — as early as possible, ideally in the topmost layout. Cheap; safe to over-call.
- **`preload`** — when you're confident the resource will be used within ~1 second. Don't preload speculatively.
- **`preinit`** — for above-the-fold CSS and critical scripts. Same caveat as preload: only when you're sure.

## When NOT to apply

- **Resources you're not sure you'll need** — preload + unused = wasted bandwidth, lower priority for the things you *do* need. The lighthouse audit "preload key requests" specifically flags this.
- **More than ~6 preloads on a page** — browsers cap parallel high-priority fetches. Over-preloading causes contention with other resources.
- **Same-origin resources** — `preconnect` is a no-op for your own origin (the connection is already open). `preload` may still help for above-the-fold resources.

## Verify

Network tab → check the "Initiator" column. Preloaded resources show "preload" or the call site. Check the "Priority" column — preloaded resources should be "High."

## Related

- [`bundle/preload`](../bundle/preload.md) — preload as a way to warm lazy chunks the user is likely to need.
- [`bundle/defer-third-party`](../bundle/defer-third-party.md) — for scripts you can defer; use `preconnect` to warm their hosts.
