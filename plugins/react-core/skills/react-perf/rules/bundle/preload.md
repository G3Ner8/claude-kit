---
title: Preload Based on User Intent
impact: MEDIUM
impactDescription: reduces perceived latency when the user lands on the lazy-loaded view
tags: bundle, preload, user-intent, hover, prefetch
---

## Preload Based on User Intent

When the user signals intent — hovering a link, focusing a button, opening a menu — there's a window of a few hundred milliseconds before they actually click. Use it to start fetching the next chunk so the navigation feels instant.

**Example — preload a heavy editor before the user clicks "Open":**

```tsx
function EditorButton({ onClick }: { onClick: () => void }) {
  const preload = () => {
    void import('./monaco-editor')
  }

  return (
    <button
      onMouseEnter={preload}
      onFocus={preload}
      onClick={onClick}
    >
      Open Editor
    </button>
  )
}
```

`onMouseEnter` covers pointer users; `onFocus` covers keyboard users. The `void` discards the promise so React doesn't complain about an unhandled return.

**Example — preload a route chunk on link hover:**

```tsx
const Dashboard = lazy(() => import('./routes/Dashboard'))

function NavLink() {
  const preload = () => {
    void import('./routes/Dashboard')
  }

  return (
    <a
      href="/dashboard"
      onMouseEnter={preload}
      onFocus={preload}
      onClick={(e) => {
        e.preventDefault()
        navigate('/dashboard')
      }}
    >
      Dashboard
    </a>
  )
}
```

Calling `import('./routes/Dashboard')` twice is safe — modern bundlers (Vite, Rollup, Webpack) dedupe the chunk request, so the second call resolves instantly.

**Example — preload when a feature flag enables:**

```tsx
function FlagsProvider({ children, flags }: Props) {
  useEffect(() => {
    if (flags.editorEnabled) {
      void import('./monaco-editor').then(mod => mod.init?.())
    }
  }, [flags.editorEnabled])

  return <FlagsContext.Provider value={flags}>{children}</FlagsContext.Provider>
}
```

**Pair with `<link rel="modulepreload">` for known critical chunks** — see [Use React DOM Resource Hints](../rendering/resource-hints.md) for `preloadModule()`.
