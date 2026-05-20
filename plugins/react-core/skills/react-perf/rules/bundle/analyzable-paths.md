---
title: Prefer Statically Analyzable Paths
impact: HIGH
impactDescription: keeps the bundler's view of reachable modules narrow and predictable
tags: bundle, vite, rollup, esbuild, path, dynamic-import
---

## Prefer Statically Analyzable Paths

Bundlers (Vite, Rollup, esbuild, Webpack) work best when import paths are obvious at build time. If you hide the real path inside a variable or compose it dynamically, the tool either has to include a broad set of possible files, warn that it cannot analyze the import, or skip optimization entirely.

Prefer explicit maps or literal paths so the set of reachable modules stays narrow and predictable.

When analysis becomes too broad, the cost is real:

- Larger production bundles (unused modules included)
- Slower builds (more files to process)
- Worse cache reuse (broader dependency graph)
- More memory use during build

### Import Paths

**Incorrect (the bundler cannot tell what may be imported):**

```ts
const PAGE_MODULES = {
  home: './pages/home',
  settings: './pages/settings',
} as const

const Page = await import(PAGE_MODULES[pageName])
```

**Correct (use an explicit map of allowed modules):**

```ts
const PAGE_MODULES = {
  home: () => import('./pages/home'),
  settings: () => import('./pages/settings'),
} as const

const Page = await PAGE_MODULES[pageName]()
```

Each `() => import('./pages/home')` is a literal `import()` call — the bundler can statically see all reachable modules and code-split each into its own chunk.

### Glob Imports

If you really do need a runtime-chosen module, prefer Vite's `import.meta.glob()` over composing a string path. It gives the bundler an explicit set of files to consider:

```ts
const pages = import.meta.glob('./pages/*.tsx')
const loader = pages[`./pages/${pageName}.tsx`]
const Page = await loader()
```

Reference: [Vite features – Glob import](https://vite.dev/guide/features.html#glob-import), [Rollup dynamic import vars](https://www.npmjs.com/package/@rollup/plugin-dynamic-import-vars)
