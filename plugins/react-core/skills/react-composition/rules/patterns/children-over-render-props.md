---
title: Prefer children over render props
impact: MEDIUM
impactDescription: keeps the JSX call site readable and the slot contract small — render functions for slots are almost always avoidable in modern React
tags: composition, children, slots, patterns
---

## Prefer `children` over render props

When a component needs to render content the consumer supplies in a fixed slot, accept it through `children`. Reach for render props (`renderHeader`, `renderItem`, `children: (ctx) => ReactNode`) only when the consumer needs values produced **inside** the component — and even then, modern React often has a cleaner alternative (compound + context, or hooks).

`children` slots win because:

1. **The JSX call site reads top-to-bottom in DOM order.** Render-prop call sites scramble that — the header lives inside a function further down the file.
2. **No closure capture surprises.** A render prop captures variables from the consumer's scope; subtle stale-closure bugs follow.
3. **Editors render JSX inside `children` natively** — autocomplete, prop type checking, refactor-safe renames.
4. **Refactoring is mechanical.** Lifting a `children` slot one level up just moves JSX; lifting a render-prop slot up requires unwinding the function signature.

**Incorrect — render props for content the consumer already has:**

```tsx
<DataPanel
  renderHeader={() => <h2>Q3 totals</h2>}
  renderBody={() => (
    <p>Revenue up 4.2%.</p>
  )}
  renderFooter={() => (
    <button onClick={onExport}>Export</button>
  )}
/>;
```

Two layers of indirection (3 closures and 3 prop names) for content the JSX could state directly.

**Correct — children with named slot subcomponents:**

```tsx
<DataPanel>
  <DataPanel.Header>Q3 totals</DataPanel.Header>
  <DataPanel.Body>
    <p>Revenue up 4.2%.</p>
  </DataPanel.Body>
  <DataPanel.Footer>
    <button onClick={onExport}>Export</button>
  </DataPanel.Footer>
</DataPanel>
```

The call site reads as the rendered output. New slots are additive — adding `<DataPanel.Toolbar>` doesn't change any existing usage.

## When render props are still the right call

Render props (or function-as-children) are genuinely useful when the component **produces values** that the consumer needs to render. The component holds the state; the consumer holds the markup.

The classic case is virtualization or async-resource libraries — `react-window`, `react-intersection-observer`, `<RouteLoader>` — where the consumer can't compose the inner DOM without per-item context (index, isVisible, ref, isLoading).

```tsx
<VirtualList items={rows} estimateSize={48}>
  {(item, index) => (
    <Row key={item.id} index={index}>
      {item.name}
    </Row>
  )}
</VirtualList>
```

Here the consumer **needs `index`** to render correctly, and `VirtualList` owns the index space. A `children` slot can't carry per-item values.

## When NOT to apply

- **Lists** — function-as-children is correct for per-item rendering. Don't replace `<Items>{(item) => <Row item={item} />}</Items>` with a `<Items.Row />` slot pattern; the API loses the ability to control rendering.
- **Async boundaries** that yield data (`<Loader>{(data) => ...}</Loader>`) — same reason. The data needs to come out of the boundary; a static slot can't carry it.
- **Compound components** — these already use children correctly via static subcomponents. No conflict.

## The decision matrix

| Need | Use |
|---|---|
| Static structural slot (header, footer, sidebar) | `children` + named subcomponents (`<X.Header>...</X.Header>`) |
| Single content slot | `children` |
| Per-item rendering for a list | Function-as-children with item param |
| Async boundary yielding loaded data | Function-as-children with data param |
| Inner state exposed to consumer | Compound component + context hook, OR function-as-children if the state is per-render-cycle |

The trigger is **"the component has nothing the consumer doesn't already have at the call site"** — that means `children`. The moment the consumer needs `index`, `isVisible`, `data`, or any other value the parent produces, function-as-children earns its place.
