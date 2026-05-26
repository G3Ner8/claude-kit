---
title: Subscribe to Derived Booleans, Not Raw Values
impact: MEDIUM
impactDescription: narrows re-renders to the moments the derived value actually flips, instead of every change to the underlying source
tags: prevent-rerender, selector, derived, store
---

## Subscribe to Derived Booleans, Not Raw Values

If your component only cares whether `count > 0`, subscribing to `count` itself makes you re-render on every increment from 5 to 6 to 7 — even though the answer to `count > 0` hasn't changed since 1.

Narrow the subscription to the derived value. The component re-renders only when the boolean (or the derived shape) actually changes.

This applies anywhere a store/query/context exposes a selector. The pattern: do the derivation **inside the selector**, not outside in JSX.

**Incorrect — subscribes to the raw count, re-renders on every change:**

```tsx
function AddToCart() {
  const items = useStore((s) => s.items);     // re-render on EVERY item change
  const isEmpty = items.length === 0;          // derived in render body

  return (
    <button disabled={isEmpty}>
      Add to cart
    </button>
  );
}
```

If `items` mutates 30 times during a session, this component re-renders 30 times — even though `isEmpty` only flipped once.

**Correct — derived selector:**

```tsx
function AddToCart() {
  const isEmpty = useStore((s) => s.items.length === 0);

  return (
    <button disabled={isEmpty}>
      Add to cart
    </button>
  );
}
```

The selector returns a boolean. The component re-renders only when that boolean changes — once, at the 0↔1 transition.

## Object-valued selectors

If you derive an object, the library needs to know how to compare equality. Most accept a custom comparator:

```ts
// Zustand
const { name, role } = useStore(
  (s) => ({ name: s.user.name, role: s.user.role }),
  shallow,   // shallow-equality comparator
);
```

Without `shallow`, the selector returns a fresh object on every store change → ref inequality → re-render every time. With `shallow`, the comparator looks at `{name, role}` field-by-field — re-render only when name or role changes.

TanStack Query has a `select` option that serves the same role:

```ts
const isEmpty = useQuery({
  queryKey: ['items'],
  queryFn: fetchItems,
  select: (data) => data.length === 0,   // derived inside the cache
});
```

## When NOT to apply

- **The raw value is what you render** — `<span>{count}</span>` requires the raw value. No selector trick avoids that re-render.
- **The selector is more expensive than the re-render** — if deriving the boolean involves walking a deep object on every store update, you're shifting cost from React to the selector. Profile before assuming.

## Related

- [`defer-reads`](./defer-reads.md) — when the value is read only in callbacks, skip the subscription entirely.
- [`narrow-effect-deps`](./narrow-effect-deps.md) — same idea for effect dependencies: depend on the narrowest value, not the source.
