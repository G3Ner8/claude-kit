---
title: `useDeferredValue` for Lagging Derived Renders
impact: MEDIUM
impactDescription: like startTransition but you don't need to own both state pieces — derives a "stale-OK" version of a value that lags behind the live one
tags: prevent-rerender, useDeferredValue, transition, concurrent
---

## `useDeferredValue` for Lagging Derived Renders

`useDeferredValue` is `startTransition` for the receiving side. Given a value, it returns a copy that lags the original — React updates the deferred value at lower priority, interrupting if a higher-priority update arrives.

Use it when you have one value (typically a controlled input or a prop) and want to derive a slow-rendering downstream from it, **without** having to own the lower-priority state piece.

**Incorrect — both renders fire on every keystroke, slow one blocks fast one:**

```tsx
function App({ query }: { query: string }) {
  // Both inputs see the same query; the slow list blocks the fast metadata.
  return (
    <>
      <Metadata query={query} />              {/* cheap */}
      <ExpensiveList query={query} />          {/* slow */}
    </>
  );
}
```

**Correct — defer the value that drives the slow render:**

```tsx
function App({ query }: { query: string }) {
  const deferredQuery = useDeferredValue(query);   // lags behind `query`
  const isStale       = query !== deferredQuery;

  return (
    <>
      <Metadata query={query} />                            {/* always uses fresh */}
      <ExpensiveList query={deferredQuery} className={isStale ? 'opacity-50' : ''} />
    </>
  );
}
```

`<Metadata>` re-renders with the fresh query on every keystroke. `<ExpensiveList>` re-renders with the lagging value at lower priority. When typing is faster than the list can render, the list shows the stale result with a visual cue (`opacity-50`) instead of blocking.

## `useTransition` vs `useDeferredValue`

| Use | When |
|---|---|
| `useTransition` | You own both state pieces (urgent input value + downstream query). |
| `useDeferredValue` | You receive a value from above (prop, context) and just want to derive a slow render from it without re-architecting state ownership. |

They produce similar UX. The choice is structural: do you control the urgent state or not?

## Stale indicator

`useDeferredValue` doesn't expose an `isPending` flag. Derive it manually: `const isStale = query !== deferredQuery;`. Use it to dim or skeleton the slow region while it catches up.

## When NOT to apply

- **The downstream is cheap** — no perceived benefit; adds a stale state to reason about.
- **You can hoist `startTransition` into the input handler** — when you own the input, that's the preferred shape (see [`transitions`](./transitions.md)).
- **The deferred value drives navigation or other side effects** — `useDeferredValue` is for *render output* only. Don't put it on a route param.

## Related

- [`transitions`](./transitions.md) — the alternative shape when you own both state pieces.
- [`render-output/usetransition-loading`](../render-output/usetransition-loading.md) — the loading-indicator UX layer.
