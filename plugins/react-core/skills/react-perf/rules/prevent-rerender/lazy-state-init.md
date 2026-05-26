---
title: Lazy Initial State for Expensive Defaults
impact: LOW-MEDIUM
impactDescription: avoids recomputing an expensive initial state on every render (it's only used on the first one)
tags: prevent-rerender, useState, initialization, lazy
---

## Lazy Initial State for Expensive Defaults

`useState(value)` evaluates `value` on every render — but React only **uses** it on the first render. If `value` is the result of an expensive computation, you're paying that cost every render for no reason.

The fix is to pass a **function** instead of a value: `useState(() => computeInitial())`. React calls the function exactly once, on mount.

This applies whenever the initial value comes from: reading a localStorage payload, parsing a JSON blob, building a Map from an array, computing a derived structure from props.

**Incorrect — expensive computation on every render:**

```tsx
function FilterPanel({ allOptions }: { allOptions: Option[] }) {
  // Builds the index every render, even though it's only used on mount.
  const [filters, setFilters] = useState(buildIndex(allOptions));

  // ...
}

function buildIndex(options: Option[]): Index {
  return options.reduce((acc, o) => { acc[o.id] = o; return acc; }, {} as Index);
}
```

`buildIndex` runs on every render. With 10,000 options, the per-render cost is real.

**Correct — initializer function, called once:**

```tsx
function FilterPanel({ allOptions }: { allOptions: Option[] }) {
  const [filters, setFilters] = useState(() => buildIndex(allOptions));
  // ...
}
```

`buildIndex` runs on mount. Subsequent renders skip the call entirely.

## When the initial value depends on props that may change

The lazy initializer runs only on mount. If `allOptions` changes after mount, the state stays with the original index. That may or may not be what you want:

- **Form initial values** — usually correct: the form should keep its initial state across prop changes, only resetting on explicit re-mount.
- **Derived index of incoming data** — usually wrong: you want the index to track new data. Use `useMemo` instead:

```tsx
const filtersIndex = useMemo(() => buildIndex(allOptions), [allOptions]);
```

`useMemo` re-derives when its dependency changes. `useState` doesn't.

The rule: lazy `useState` is for **state that persists across input changes**. `useMemo` is for **derived values that track inputs**.

## When NOT to apply

- **The initial value is cheap** — `useState(0)` or `useState([])` doesn't need an initializer; the wrapper function costs more than the value.
- **The initial value comes from a hook** — `useState(useStore.getState().x)` works, but more idiomatic is to subscribe via the store's hook in the body.

## Related

- [`memo-with-default-value`](./memo-with-default-value.md) — for non-primitive default *props* (not initial state), hoist them to module-level constants.
- [`derived-state-no-effect`](./derived-state-no-effect.md) — when the value should track inputs, derive instead of storing.
