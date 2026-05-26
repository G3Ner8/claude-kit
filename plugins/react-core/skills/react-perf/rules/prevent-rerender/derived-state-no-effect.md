---
title: Derive State During Render, Not in `useEffect`
impact: HIGH
impactDescription: removes a redundant render — the `useEffect`+`setState` pattern always renders twice for the same input
tags: prevent-rerender, derived-state, useEffect, render
---

## Derive State During Render, Not in `useEffect`

If a value is purely a function of other state/props, derive it **during render**. The common anti-pattern is to keep the derived value in its own `useState`, then sync it via `useEffect`:

```tsx
const [fullName, setFullName] = useState('');
useEffect(() => { setFullName(`${first} ${last}`); }, [first, last]);
```

This works, but it always renders **twice** for the same input:

1. Component renders with old `fullName`.
2. Effect runs, calls `setFullName`.
3. Component re-renders with new `fullName`.

The second render is wasted — the value could have been computed in step 1.

**Incorrect — derived state stored in `useState`, synced by `useEffect`:**

```tsx
function NameDisplay({ first, last }: { first: string; last: string }) {
  const [fullName, setFullName] = useState('');

  useEffect(() => {
    setFullName(`${first} ${last}`);
  }, [first, last]);

  return <span>{fullName}</span>;
}
```

Every change to `first` or `last` triggers two renders, and on first mount the JSX shows the empty default before the effect catches up.

**Correct — derive during render:**

```tsx
function NameDisplay({ first, last }: { first: string; last: string }) {
  const fullName = `${first} ${last}`;
  return <span>{fullName}</span>;
}
```

One render. No empty-default flash. The compiler can also inline this.

## When the derivation is expensive

If the derivation is genuinely costly (parsing a large blob, computing a layout), wrap with `useMemo`:

```tsx
const sortedRows = useMemo(
  () => rows.slice().sort((a, b) => a.created.localeCompare(b.created)),
  [rows],
);
```

`useMemo` re-derives only when `rows` changes — still during render, still no extra round-trip through state.

## Heuristic — "do I need `useState` here?"

If the value can be expressed as a function of the current props/state, you don't need `useState`. Reach for `useState` only when:

- The value persists across renders independently of any input (e.g. `isMenuOpen`).
- The value comes from outside React (data fetched, event-driven).
- The user can change it directly (form input).

Anything else: derive.

## When NOT to apply

- **The derivation depends on an effect's side effect** — e.g. you compute a value after measuring DOM. That's not derived state; it's a side-effect result. `useEffect` + `useState` is correct.
- **You want to throttle/debounce the derivation** — `useDeferredValue` or `useTransition` is the React 19 idiom, not effect-synced state.

## Related

- [`move-effect-to-event`](./move-effect-to-event.md) — even more `useEffect` calls can be replaced by event handlers.
- [`render-output/usetransition-loading`](../render-output/usetransition-loading.md) — when the derivation is slow, mark the update as a transition rather than an effect.
