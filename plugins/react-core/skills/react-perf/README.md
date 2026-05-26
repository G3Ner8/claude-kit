# react-perf — Maintenance & Provenance

A curated React 19 performance skill for SPA stacks (Vite + TanStack Query). Derived from [vercel-labs/agent-skills/skills/react-best-practices](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices).

## Why a curated fork

The upstream pack mixes Next.js / RSC / SSR rules with framework-agnostic React rules. For SPA projects:

- Server-side rules (RSC, `React.cache`, `after()`, hoisting static I/O) have no runtime to apply to
- Bundle and dynamic-import rules use `next/dynamic` and `next.config.optimizePackageImports` — these don't exist in Vite
- Data-fetching rules use SWR — adjacent libraries (TanStack Query) follow the same dedup model but with different APIs
- Several micro-optimizations are obsolete in modern JS engines

This skill keeps the **rules that actually pay off in a Vite/CSR app** and rewrites stack-specific examples.

## Stack assumptions

Rules assume your project uses:

- **React** ≥ 19.0 (rules reference `useEffectEvent`, `useDeferredValue`, `<Activity>`, resource-hint DOM hooks)
- **Vite** as the bundler/dev server (for bundle-* rules)
- **TanStack Query** ≥ 5 or **SWR** ≥ 2 for client data fetching
- **TypeScript** (examples are TS, but rules apply to JS too)

If your stack differs, individual rules may still apply — read the rationale.

## Rule inventory (40 rules)

| Section | Files | Status |
|---|---|---|
| `async/` | 4 | 2 light edit, 2 heavy rewrite |
| `bundle/` | 6 | 4 light edit, 2 heavy rewrite |
| `runtime-io/` | 4 | 3 verbatim, 1 heavy rewrite |
| `prevent-rerender/` | 14 | 14 verbatim |
| `render-output/` | 4 | 1 verbatim, 2 light edit, 1 heavy rewrite |
| `js-micro/` | 6 | 6 verbatim |
| `advanced/` | 2 | 2 verbatim |

## Upstream → this skill mapping

### Dropped (29 rules — not applicable or noise)

| Upstream | Reason dropped |
|---|---|
| `server-after-nonblocking` | RSC / server runtime only |
| `server-auth-actions` | Server actions (Next.js) |
| `server-cache-lru` | Server runtime only |
| `server-cache-react` | RSC `React.cache()` only |
| `server-dedup-props` | RSC prop serialization |
| `server-hoist-static-io` | Server module evaluation |
| `server-no-shared-module-state` | RSC / SSR concern |
| `server-parallel-fetching` | RSC patterns |
| `server-parallel-nested-fetching` | RSC patterns |
| `server-serialization` | RSC client/server boundary |
| `async-api-routes` | Next.js API routes |
| `rendering-hydration-no-flicker` | SSR hydration only |
| `rendering-hydration-suppress-warning` | SSR hydration only |
| `async-dependencies` | Requires niche `better-all` lib; refactor instead |
| `rerender-simple-expression-in-memo` | Obsolete with React Compiler |
| `rendering-animate-svg-wrapper` | Niche (SVG animation only) |
| `rendering-svg-precision` | Niche (SVG-heavy apps only) |
| `rendering-hoist-jsx` | Micro-gain, Compiler handles |
| `rendering-script-defer-async` | Vite handles `<script>` injection |
| `rendering-activity` | React 19 experimental, narrow use |
| `advanced-event-handler-refs` | Niche advanced pattern |
| `advanced-use-latest` | Duplicates event-handler-refs |
| `js-batch-dom-css` | Rare in React/Tailwind code |
| `js-cache-property-access` | JS engines already optimize |
| `js-cache-function-results` | Premature; use library cache |
| `js-cache-storage` | Niche (heavy localStorage reads) |
| `js-combine-iterations` | Often hurts readability |
| `js-early-exit` | Universal coding practice |
| `js-length-check-first` | Obvious; rarely missed |
| `js-request-idle-callback` | Niche; specific use cases |

### Adapted (14 rules — examples rewritten)

| Upstream → This skill | Change |
|---|---|
| `async-cheap-condition-before-await` → `async/cheap-condition-before-await` | Strip Next.js framing |
| `async-defer-await` → `async/defer-await` | Strip Next.js framing |
| `async-parallel` → `async/parallel-promises` | + `Promise.allSettled` for UI tolerance |
| `async-suspense-boundaries` → `async/suspense-boundaries` | Rewrite using `useSuspenseQuery` (TanStack Query) |
| `bundle-analyzable-paths` → `bundle/analyzable-paths` | Vite framing |
| `bundle-barrel-imports` → `bundle/barrel-imports` | Vite `optimizeDeps` instead of Next.js `optimizePackageImports` |
| `bundle-conditional` → `bundle/conditional-load` | Generic dynamic import |
| `bundle-defer-third-party` → `bundle/defer-third-party` | Vanilla `<script async>` instead of `next/script` |
| `bundle-dynamic-imports` → `bundle/dynamic-imports` | `React.lazy` + `<Suspense>` instead of `next/dynamic` |
| `bundle-preload` → `bundle/preload` | `<link rel="modulepreload">` + router-agnostic prefetch |
| `client-swr-dedup` → `runtime-io/query-library-dedup` | Cover both TanStack Query and SWR |
| `rendering-conditional-render` → `render-output/conditional-render` | Reframed as correctness rule (not perf) |
| `rendering-resource-hints` → `render-output/resource-hints` | Keep — React 19 DOM hooks already framework-agnostic |
| `rendering-usetransition-loading` → `render-output/usetransition-loading` | Strip Next.js refs |
| `rerender-dependencies` → `prevent-rerender/narrow-effect-deps` | Renamed for descriptiveness |
| `rerender-memo` → `prevent-rerender/memo-component` | Renamed (component-level memo, not `useMemo`) |

### Verbatim (24 rules — framework-agnostic React)

All `prevent-rerender/*` (12 of 14, after the 2 renames above), `js-micro/*` (6), `advanced/*` (2), `runtime-io/event-listeners`, `runtime-io/passive-event-listeners`, `runtime-io/localstorage-schema`, `render-output/content-visibility`.

## Refreshing from upstream

To check for new upstream rules:

```bash
curl -sSL https://api.github.com/repos/vercel-labs/agent-skills/contents/skills/react-best-practices/rules \
  | grep '"name"' | sort > /tmp/upstream.txt
ls rules/*/*.md | xargs -n1 basename | sort > /tmp/local.txt
diff /tmp/upstream.txt /tmp/local.txt
```

New rules in upstream → decide: drop, light edit, or heavy rewrite, then add to the relevant `rules/<section>/` folder.
