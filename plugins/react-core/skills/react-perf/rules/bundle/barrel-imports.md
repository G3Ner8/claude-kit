---
title: Avoid Deep Barrel Files
impact: HIGH
impactDescription: barrels re-export everything, which can defeat tree-shaking when downstream imports go through them — often doubles or triples bundle size for icon/UI libraries
tags: bundle, imports, barrel, tree-shaking, vite
---

## Avoid Deep Barrel Files

A barrel is an `index.ts` that re-exports many symbols from sibling files:

```ts
// components/index.ts
export * from './Button';
export * from './Input';
export * from './Card';
// ... 60 more
```

When a consumer writes `import { Button } from './components'`, the bundler walks every re-export to confirm the symbol exists. In theory, modern bundlers tree-shake unused re-exports. In practice, **side effects** (a single `console.log` or `Date.now()` at module level, or a polyfill import in a transitive dep) can mark the whole barrel as "has side effects," forcing the entire chain into the bundle.

The result: importing one `<Button>` from a UI library can pull in 200+ unused components.

The fix is one of:

1. **Direct imports** from the file that defines the symbol: `import { Button } from './components/Button'`.
2. **Vite `optimizeDeps.include`** to pre-bundle and tree-shake the barrel at dev-startup.
3. **Tell the bundler the package is side-effect-free** via `package.json`: `"sideEffects": false`.

**Incorrect — barrel import of a heavy library:**

```ts
import { ChevronDown } from 'lucide-react';
```

`lucide-react`'s root `index.js` re-exports 1500+ icons. If the bundler can't prove the rest are unused (which happens with some build configs), all 1500 ship.

**Correct (option 1) — direct subpath import:**

```ts
import ChevronDown from 'lucide-react/dist/esm/icons/chevron-down';
```

The bundler reads exactly one file. No barrel walk.

**Correct (option 2) — keep the barrel import, fix the build:**

```ts
// vite.config.ts
export default defineConfig({
  optimizeDeps: {
    include: ['lucide-react'],   // dev: pre-bundle so HMR doesn't re-walk barrels
  },
});
```

Plus check that the dependency has `"sideEffects": false` in its `package.json`. Most modern UI libraries do; older ones don't.

## Your own barrels

If you ship your own components via a barrel, mark the file:

```ts
// components/index.ts
/* eslint-disable */
export * from './Button';
export * from './Input';
// ...
```

And in your project's `package.json`:

```json
{
  "sideEffects": false
}
```

This signals the bundler that nothing in your package has side effects at module load. Tree-shaking can prune unused re-exports.

If you have files with intentional side effects (CSS imports, global polyfills), list them as exceptions:

```json
{
  "sideEffects": ["**/*.css", "./src/polyfills.ts"]
}
```

## When NOT to apply

- **Tiny libraries** — `@radix-ui/react-slot` exports 2 things; the barrel cost is negligible. Don't refactor barrels that ship < 5 KB.
- **Internal modules** — within your own app, barrels are convenient for organizing imports. Tree-shaking *across your own modules* tends to be reliable in modern bundlers. The pain hits third-party libraries.

## Verify

Bundle analyzer is the source of truth. If `lucide-react` shows up at 200 KB instead of 5 KB, you have a barrel problem.

## Related

- [`analyzable-paths`](./analyzable-paths.md) — even without barrels, dynamic property access on a namespace import defeats tree-shaking.
- [`dynamic-imports`](./dynamic-imports.md) — for components used in only one route, lazy-load instead of importing at all.
