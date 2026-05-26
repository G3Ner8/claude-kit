---
title: Wrap Expensive Subtrees in `memo()`
impact: MEDIUM
impactDescription: lets a subtree skip re-render when its props are referentially unchanged — biggest wins are on heavy lists and read-only display components
tags: prevent-rerender, memo, components, optimization
---

## Wrap Expensive Subtrees in `memo()`

`React.memo(Component)` short-circuits re-renders: if the component's props are shallow-equal to the previous render's props, React skips the render entirely.

The wrap is cheap — one comparison per render. The win is large when:

1. The component renders an expensive subtree (a chart, a syntax-highlighted block, a table cell with a sub-tree of styled children).
2. The component renders inside a parent that re-renders often (a route layout, a form provider).
3. The component's props change much less often than the parent re-renders.

**Incorrect — heavy component re-renders on every parent change:**

```tsx
function ExpensiveChart({ data }: { data: ChartData }) {
  // Layout work, SVG path computation, ~10 ms per render
  return <ChartSvg data={data} />;
}

function Dashboard() {
  const [filter, setFilter] = useState('');
  const data = useChartData();   // stable; doesn't change with filter
  return (
    <>
      <input value={filter} onChange={(e) => setFilter(e.target.value)} />
      <ExpensiveChart data={data} />
    </>
  );
}
```

Every keystroke in the filter input re-renders `<ExpensiveChart>` — even though its `data` prop didn't change.

**Correct — `memo()` skips when props are referentially unchanged:**

```tsx
const ExpensiveChart = memo(function ExpensiveChart({ data }: { data: ChartData }) {
  return <ChartSvg data={data} />;
});
```

Now `<ExpensiveChart>` renders only when `data` itself changes by reference. Typing in the filter doesn't trigger it.

## Reference equality is the trap

`memo()` uses **shallow** comparison by default — so passing inline objects/arrays/functions defeats it:

```tsx
<ExpensiveChart options={{ theme: 'dark' }} />   // fresh object every render → memo() never short-circuits
<ExpensiveChart series={data.filter(x => x.visible)} />   // fresh array every render → same
<ExpensiveChart onZoom={() => setZoom(z + 1)} />   // fresh function every render → same
```

Fixes (in order of preference):

1. Hoist the value outside the render (`const DEFAULT_OPTIONS = { theme: 'dark' }`).
2. Wrap with `useMemo` / `useCallback` so the parent reuses the same reference.
3. Custom comparator: `memo(Component, (prev, next) => deepEqual(prev.options, next.options))`. Only when 1 and 2 aren't viable.

## When NOT to apply

- **Cheap components** — `memo()` adds a comparison per render. For a `<Badge>` that renders one `<span>`, the comparison costs more than the render.
- **Props that change every render anyway** — wrapping a component whose props always change (`<Stopwatch elapsed={elapsed} />`) costs the comparison without ever saving a render.
- **React 19 + React Compiler enabled** — the compiler memoizes automatically for many cases. Wrap manually only when you've measured the compiler not catching a hot path.

## Verify

React DevTools Profiler → record a session → check the component's render count and "Why did this render" hints. If a memoized component re-renders despite identity-stable props, you have an inline-object problem.

## Related

- [`memo-with-default-value`](./memo-with-default-value.md) — non-primitive default props that defeat memoization.
- [`no-inline-components`](./no-inline-components.md) — components defined inside other components defeat memoization entirely (and cause remounts).
