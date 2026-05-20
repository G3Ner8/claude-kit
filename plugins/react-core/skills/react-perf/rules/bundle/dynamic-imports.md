---
title: Dynamic Imports for Heavy Components
impact: CRITICAL
impactDescription: keeps heavy editors/charts/PDF readers out of the main chunk
tags: bundle, dynamic-import, code-splitting, react-lazy, suspense
---

## Dynamic Imports for Heavy Components

Use `React.lazy()` + `<Suspense>` to load large components on demand. Editors (Monaco, CodeMirror), chart libraries (Recharts, ApexCharts), PDF viewers, rich-text editors, image croppers, and date pickers can each be hundreds of KB — keeping them in the initial chunk delays Time to Interactive across every route, even ones that don't use them.

**Incorrect (heavy component bundles with main chunk):**

```tsx
import { MonacoEditor } from './monaco-editor'

function CodePanel({ code }: { code: string }) {
  return <MonacoEditor value={code} />
}
```

`monaco-editor` is ~300KB+ gzipped. Every user pays the parse and download cost on first load, even if they never open the editor.

**Correct (Monaco loads on demand):**

```tsx
import { lazy, Suspense } from 'react'

const MonacoEditor = lazy(() =>
  import('./monaco-editor').then(m => ({ default: m.MonacoEditor }))
)

function CodePanel({ code }: { code: string }) {
  return (
    <Suspense fallback={<EditorSkeleton />}>
      <MonacoEditor value={code} />
    </Suspense>
  )
}
```

> `React.lazy` requires the dynamically imported module to have a `default` export. If the heavy component is a named export, wrap with `.then(m => ({ default: m.NamedExport }))` as shown.

### Lazy route loading (most common application)

Always lazy-load routes — the bundler emits one chunk per route, and only the active route is fetched:

```tsx
import { lazy, Suspense } from 'react'
import { createBrowserRouter, RouterProvider } from 'react-router-dom'

const Dashboard = lazy(() => import('./routes/Dashboard'))
const Settings = lazy(() => import('./routes/Settings'))
const Reports = lazy(() => import('./routes/Reports'))

const router = createBrowserRouter([
  {
    path: '/',
    element: (
      <Suspense fallback={<PageSkeleton />}>
        <RootLayout />
      </Suspense>
    ),
    children: [
      { path: 'dashboard', element: <Dashboard /> },
      { path: 'settings', element: <Settings /> },
      { path: 'reports', element: <Reports /> },
    ],
  },
])

export function App() {
  return <RouterProvider router={router} />
}
```

### Naming chunks for easier debugging

Vite and Webpack accept a `webpackChunkName` magic comment that becomes the chunk filename, which makes bundle analysis (`vite build --sourcemap`, `rollup-plugin-visualizer`) much easier to read:

```ts
const MonacoEditor = lazy(() =>
  import(/* webpackChunkName: "monaco" */ './monaco-editor')
    .then(m => ({ default: m.MonacoEditor }))
)
```

### Pairing with intent-based preload

Lazy chunks don't load until React renders the component. To remove the loading flash, kick off the `import()` ahead of time on hover or focus — see [Preload Based on User Intent](./preload.md).

### When NOT to lazy-load

- The component is small (< 20KB gzipped). The chunk metadata + fetch round trip is more expensive than just shipping it.
- The component is rendered on every page load (e.g., the app shell). Lazy-loading it just delays first paint.
- The component is below-the-fold but always rendered. Use `content-visibility: auto` (see [Content Visibility](../rendering/content-visibility.md)) instead — it skips render work without breaking the bundle.

Reference: [React – lazy](https://react.dev/reference/react/lazy), [Vite – Code Splitting](https://vite.dev/guide/features.html#code-splitting)
