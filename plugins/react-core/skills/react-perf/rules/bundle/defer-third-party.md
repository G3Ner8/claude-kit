---
title: Defer Non-Critical Third-Party Libraries
impact: MEDIUM
impactDescription: loads non-essential third-party code after first paint
tags: bundle, third-party, analytics, defer
---

## Defer Non-Critical Third-Party Libraries

Analytics, error tracking, session replay, A/B testing, chat widgets — none of these block the user from completing their primary task. They should not be in the initial bundle, and they should not delay first paint.

**Incorrect (third-party library evaluates as part of initial bundle):**

```tsx
import { Analytics } from '@vendor/analytics'

export function App() {
  return (
    <>
      <MainApp />
      <Analytics />
    </>
  )
}
```

**Correct option A — React.lazy with idle mount:**

```tsx
import { lazy, Suspense, useEffect, useState } from 'react'

const Analytics = lazy(() =>
  import('@vendor/analytics').then(m => ({ default: m.Analytics }))
)

export function App() {
  const [mountAnalytics, setMountAnalytics] = useState(false)

  useEffect(() => {
    // Wait until the browser is idle (or fall back to a timeout)
    if ('requestIdleCallback' in window) {
      const handle = window.requestIdleCallback(() => setMountAnalytics(true))
      return () => window.cancelIdleCallback(handle)
    }
    const handle = window.setTimeout(() => setMountAnalytics(true), 1500)
    return () => window.clearTimeout(handle)
  }, [])

  return (
    <>
      <MainApp />
      {mountAnalytics && (
        <Suspense fallback={null}>
          <Analytics />
        </Suspense>
      )}
    </>
  )
}
```

**Correct option B — vanilla `<script async>` for vendor snippets:**

For vendor scripts that ship as a `<script>` tag (most analytics/widget vendors), inject them with `async` or `defer` so they don't block parse:

```html
<!-- index.html -->
<script async src="https://cdn.vendor.com/analytics.js"></script>
```

Or inject at runtime after first paint:

```ts
useEffect(() => {
  const s = document.createElement('script')
  s.src = 'https://cdn.vendor.com/analytics.js'
  s.async = true
  document.head.appendChild(s)
  return () => { s.remove() }
}, [])
```

The goal is the same in both options: third-party code must not be on the critical path. Measure with Lighthouse Total Blocking Time — third-party scripts are usually the largest contributor.
