---
name: react-perf
description: Curated React 19 performance rules for client-side SPAs (Vite + TanStack Query stack). Use when writing, reviewing, or refactoring React components, hooks, data fetching, or bundle configuration. Covers waterfalls, bundle size, re-renders, rendering work, and modern React 19 APIs (useTransition, useDeferredValue, useSuspenseQuery, resource hints, useEffectEvent). Does NOT cover Next.js/RSC/SSR patterns.
license: MIT
user-invocable: true
metadata:
  version: "2.0.0"
  type: reference
  status: stable
  stack: React 19, Vite, TanStack Query, TypeScript
  scope: SPA / CSR only
---

# React Performance (SPA / Vite / TanStack Query)

40 React 19 performance rules for single-page applications. Each rule states the symptom, an Incorrect → Correct contrast, and when not to apply. Optimized for AI agents to follow when writing or refactoring React code.

## Scope

**Applies to:** React 19 + Vite + TanStack Query (or SWR) on the client.

**Does NOT apply to:** Next.js App Router, React Server Components, server actions, SSR/SSG hydration patterns. Server-side rules are intentionally out of scope; Next.js-specific bundler APIs (`next/dynamic`, `next/script`, `next.config.optimizePackageImports`) are replaced by Vite + `React.lazy` idioms throughout.

## When to use

Reference these rules when:
- Writing new React components or hooks
- Implementing client-side data fetching
- Reviewing PRs for performance regressions
- Refactoring effects, state, or memoization
- Optimizing bundle size or chunk strategy

Skip this skill for:
- Next.js / RSC / SSR work — rules don't apply, use Next.js docs
- Composition / API design — use `react-composition` instead
- Initial component implementation when the perf risk is unknown — write it simple first, profile second

## How to Navigate

Rules live under `rules/<section>/<rule>.md`. Each section has a priority:

| Priority | Section | Folder |
|---|---|---|
| CRITICAL | Eliminating Waterfalls | `rules/async/` |
| CRITICAL | Bundle Size Optimization | `rules/bundle/` |
| MEDIUM-HIGH | Browser Runtime I/O | `rules/runtime-io/` |
| MEDIUM | Preventing Re-renders | `rules/prevent-rerender/` |
| MEDIUM | Render-Output Optimizations | `rules/render-output/` |
| LOW-MEDIUM | JS Micro-Optimizations | `rules/js-micro/` |
| LOW | Advanced Patterns | `rules/advanced/` |

Each rule file has frontmatter (`title`, `impact`, `tags`), a brief rationale, and contrasting **Incorrect / Correct** code examples in TypeScript.

## Quick Index

### 1. Eliminating Waterfalls (`async/`)
- `cheap-condition-before-await` — gate awaits behind cheap sync checks
- `defer-await` — move await into branch that uses the value
- `parallel-promises` — Promise.all (and allSettled) for independent ops
- `suspense-boundaries` — stream content with Suspense + useSuspenseQuery

### 2. Bundle Size (`bundle/`)
- `analyzable-paths` — keep imports statically analyzable
- `barrel-imports` — Vite optimizeDeps or direct imports for icon/UI libs
- `conditional-load` — load feature modules only when activated
- `defer-third-party` — defer analytics/widgets until after first paint
- `dynamic-imports` — React.lazy + Suspense for heavy components
- `preload` — modulepreload + router prefetch on hover/focus

### 3. Browser Runtime I/O (`runtime-io/`)
- `query-library-dedup` — use TanStack Query / SWR for automatic dedup
- `event-listeners` — share one global listener across subscribers
- `passive-event-listeners` — passive: true for scroll/touch
- `localstorage-schema` — version your localStorage shape

### 4. Preventing Re-renders (`prevent-rerender/`)
- `defer-reads` — subscribe to slices used in render, not slices only read in callbacks
- `narrow-effect-deps` — prefer primitive values in effect/memo dependency arrays
- `derived-state` — subscribe to derived booleans, not raw values that change often
- `derived-state-no-effect` — derive during render, not via `useEffect` + `setState`
- `functional-setstate` — `setX(prev => ...)` keeps callbacks stable and avoids stale closures
- `lazy-state-init` — pass a function to `useState` for expensive initial values
- `memo-component` — extract expensive subtrees into `memo()` to enable early-return
- `memo-with-default-value` — hoist non-primitive default props to a module-level constant
- `move-effect-to-event` — put interaction logic in event handlers, not effects
- `no-inline-components` — never define components inside components (causes remount)
- `split-combined-hooks` — split hooks that bundle independent state
- `transitions` — `startTransition` for non-urgent updates
- `use-deferred-value` — defer expensive renders to keep typed input responsive
- `use-ref-transient-values` — refs for high-frequency values that shouldn't trigger renders

### 5. Render-Output Optimizations (`render-output/`)
- `conditional-render` — ternary over `&&` for non-boolean checks (correctness)
- `content-visibility` — content-visibility: auto for long off-screen lists
- `resource-hints` — React 19 `preload`/`preconnect`/`preinit` DOM hooks
- `usetransition-loading` — prefer useTransition over isLoading flags

### 6. JS Micro-Optimizations (`js-micro/`)
- `flatmap-filter` — `flatMap` replaces `.map().filter(Boolean)` in one pass
- `hoist-regexp` — move RegExp creation outside loops / hot paths
- `index-maps` — build a `Map` for O(1) lookups instead of repeated `.find()`
- `min-max-loop` — single loop beats sort-then-pick for min/max
- `set-map-lookups` — `Set`/`Map` for O(1) membership; avoid `.includes()` in loops
- `tosorted-immutable` — `toSorted()` returns a new array (safe with immutable state)

### 7. Advanced Patterns (`advanced/`)
- `effect-event-deps` — keep useEffectEvent results out of deps
- `init-once` — initialize app singletons exactly once

