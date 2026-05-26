---
title: Use Functional setState for Stable Callbacks
impact: MEDIUM
impactDescription: keeps callbacks stable across renders and avoids stale-closure bugs when state changes between callback creation and call
tags: prevent-rerender, setState, closures, stale-state
---

## Use Functional setState for Stable Callbacks

`setState(value)` reads the current state implicitly from the surrounding closure. If the callback was created in an old render, `value` will be computed from a stale snapshot — leading to lost updates and subtle bugs.

`setState((prev) => next)` reads the current state explicitly from React's reducer, not from the closure. Same result for one-shot updates, but **safe** when the callback may run after the closure is stale (e.g. inside a debounced handler, a Promise resolution, a multi-call sequence).

It also lets the callback be **referentially stable** — React Hook Form, TanStack Query, and many memoized children compare callback identity. A stable callback means no spurious re-renders downstream.

**Incorrect — closure-captured state, breaks on rapid updates:**

```tsx
function Counter() {
  const [count, setCount] = useState(0);

  const increment = () => {
    setCount(count + 1);
    setCount(count + 1);   // both reads see the SAME closure-captured count
    setCount(count + 1);   // → count goes up by 1, not 3
  };

  return <button onClick={increment}>Count: {count}</button>;
}
```

Click once → count goes from 0 to 1, not to 3. All three `setCount(count + 1)` reads see `count === 0`.

**Correct — functional updater, applies sequentially:**

```tsx
function Counter() {
  const [count, setCount] = useState(0);

  const increment = useCallback(() => {
    setCount((c) => c + 1);
    setCount((c) => c + 1);
    setCount((c) => c + 1);   // 0 → 1 → 2 → 3
  }, []);   // stable! No dependency on `count`.

  return <button onClick={increment}>Count: {count}</button>;
}
```

Each `setCount((c) => c + 1)` sees the latest count, in order. The callback has no closure dependency on `count`, so `useCallback([], ...)` makes it stable across renders.

## The stale-closure trap

The most common bug is in async paths:

```tsx
const onSave = async () => {
  const result = await save(data);
  setHistory(history.concat(result));   // `history` is the snapshot from when onSave was created
};
```

If `history` updates between the click and the await resolving, the concat happens on the old array — overwriting the intervening update.

Functional form fixes it:

```ts
setHistory((prev) => prev.concat(result));
```

Always read through the updater inside async paths.

## When NOT to apply

- **One-shot non-incremental update from a known source** — `setName(event.target.value)` is fine: the value doesn't depend on the previous state. The functional form adds no safety.
- **The state itself is the dependency you want** — sometimes you genuinely want the closure-captured value (e.g., logging the value at the time of click). Use a ref for that, not a stale closure.

## Related

- [`narrow-effect-deps`](./narrow-effect-deps.md) — functional updaters also let you omit `count` from effect deps without lint warnings.
- [`use-ref-transient-values`](./use-ref-transient-values.md) — for values that shouldn't trigger re-render but you still need fresh in callbacks.
