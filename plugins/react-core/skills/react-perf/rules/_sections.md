# Sections

This file defines the seven sections used by `react-perf`, their priority ordering, impact levels, and folder mapping.

---

## 1. Eliminating Waterfalls (`async/`)

**Impact:** CRITICAL
**Description:** Sequential awaits are the largest single source of perceived latency in client-side React apps. Each `await` adds full network or microtask round-trip. Restructuring to run independent work in parallel, deferring awaits, or streaming with Suspense yields the largest gains.

## 2. Bundle Size Optimization (`bundle/`)

**Impact:** CRITICAL
**Description:** Initial bundle size directly affects Time to Interactive and First Contentful Paint on slow networks and low-end devices. Avoid pulling in large UI libraries via barrel files, lazy-load heavy components, and defer non-critical third-party scripts.

## 3. Browser Runtime I/O (`runtime-io/`)

**Impact:** MEDIUM-HIGH
**Description:** Browser-side runtime concerns: client data fetching (TanStack Query / SWR for automatic dedup, cache, revalidation), shared event listeners, passive listeners on touch/scroll, versioned localStorage shapes.

## 4. Preventing Re-renders (`prevent-rerender/`)

**Impact:** MEDIUM
**Description:** Stop unnecessary renders from happening. Derive state during render (not in effects), prefer primitive deps, memoize selectively, split combined hooks, avoid inline component definitions.

## 5. Render-Output Optimizations (`render-output/`)

**Impact:** MEDIUM
**Description:** When a render does happen, reduce browser-side work. Use `content-visibility` for off-screen content, React 19 resource-hint hooks for early connection setup, and `useTransition` for non-urgent updates.

## 6. JS Micro-Optimizations (`js-micro/`)

**Impact:** LOW-MEDIUM
**Description:** Targeted micro-optimizations for hot paths. Index maps for O(1) lookups, hoist RegExp outside loops, prefer `flatMap` over chained `.map().filter()`, use `toSorted()` for immutability.

## 7. Advanced Patterns (`advanced/`)

**Impact:** LOW
**Description:** Edge-case patterns for specific React 19 APIs. Keep `useEffectEvent` results out of effect dependencies. Initialize app singletons exactly once across StrictMode double-invocation.
