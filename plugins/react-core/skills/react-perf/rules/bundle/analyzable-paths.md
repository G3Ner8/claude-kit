---
title: Keep Imports Statically Analyzable
impact: HIGH
impactDescription: lets the bundler tree-shake correctly — dynamic property accesses and string-built paths defeat it, often shipping 10-100x more code than needed
tags: bundle, imports, tree-shaking, vite, rollup
---

## Keep Imports Statically Analyzable

Bundlers (Vite/Rollup/esbuild/webpack) tree-shake by reading import statements at build time. If the bundler can't statically determine which symbols you use, it has to include the entire module to be safe — including dependencies-of-dependencies you never touch.

The two patterns that defeat static analysis:

1. **String-built specifiers**: `import(\`./icons/${iconName}\`)` — the bundler must include every file under `./icons/`.
2. **Dynamic property access on a namespace import**: `Icons[iconName]` after `import * as Icons from '...'` — the bundler includes all of `Icons`.

The fix in both cases: switch to named imports for the actual symbols you reference.

**Incorrect — namespace import + dynamic property access:**

```ts
import * as Icons from 'lucide-react';

function IconCell({ name }: { name: keyof typeof Icons }) {
  const Icon = Icons[name];           // bundler can't tell which Icons.X is used
  return <Icon />;
}
```

The bundle ships **all** of `lucide-react` — usually 1000+ icons — because the bundler can't prove which subset is reachable.

**Correct — named imports for the symbols actually used:**

```tsx
import { ChevronDown, Search, X } from 'lucide-react';

const ICONS = { 'chevron-down': ChevronDown, search: Search, x: X } as const;
type IconName = keyof typeof ICONS;

function IconCell({ name }: { name: IconName }) {
  const Icon = ICONS[name];           // ICONS is local — the bundler sees the 3 named imports
  return <Icon />;
}
```

The bundler tree-shakes `lucide-react` down to the three icons that appear in named-import positions.

## Patterns to watch

| Pattern | Tree-shakeable? | Fix |
|---|---|---|
| `import { foo } from 'lib'` | ✅ yes | — |
| `import * as Lib from 'lib'; Lib.foo()` | ⚠ usually yes (modern Rollup) | switch to named import for clarity |
| `import * as Lib from 'lib'; Lib[name]()` | ❌ no | named imports + local lookup |
| `await import(\`./modules/${name}\`)` | ❌ no | enumerate the modules, or use a `Record<string, () => Promise>` |
| `require(variable)` (CJS) | ❌ no | switch to ESM static imports |

## When NOT to apply

- **The set of symbols really is dynamic** — e.g. you load locale files based on user setting. Use an explicit map: `const LOCALES = { en: () => import('./en.json'), th: () => import('./th.json') } as const;`. Each `import()` is statically analyzable on its own.
- **The library doesn't ship ES modules** — pre-built CommonJS libraries can't be tree-shaken at all, regardless of how you import. Either accept the cost or find an ESM alternative.

## Verify

Run a bundle analyzer (`vite-bundle-visualizer`, `rollup-plugin-visualizer`) on a production build. If a module is included that you didn't intentionally use, suspect a non-analyzable import.

## Related

- [`barrel-imports`](./barrel-imports.md) — barrel `index.ts` files that re-export 100 things can defeat tree-shaking even when imports look analyzable.
- [`dynamic-imports`](./dynamic-imports.md) — when you genuinely need code-splitting, use `React.lazy` + static `import()` calls.
