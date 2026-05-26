---
title: Use `toSorted()` for Immutable Sort
impact: LOW
impactDescription: returns a new sorted array without mutating the source — safer in React (no in-place state mutation) and clearer than `[...arr].sort()`
tags: js-micro, sort, immutable, toSorted, react
---

## Use `toSorted()` for Immutable Sort

`Array.prototype.sort()` mutates the source array in place. In React, that's a bug waiting to happen: if the source is state, you've mutated state without going through `setState` — React doesn't see the change and downstream selectors see different references at different times.

The pre-`toSorted` workaround was `[...arr].sort()`: clone, then sort the clone. That works but creates a spread step. ES2023 ships `Array.prototype.toSorted()` — same return shape, no mutation, no intermediate spread.

**Incorrect — in-place sort on state:**

```ts
const sortedTasks = tasks.sort((a, b) => a.dueDate - b.dueDate);
// `tasks` is now mutated. If `tasks` is React state, the component's state shape is broken.
```

After this line, `tasks` and `sortedTasks` point to the same (now-sorted) array. Any other component that read `tasks` before this line still holds a reference that's now in a different order.

**Correct — `toSorted` returns a new array:**

```ts
const sortedTasks = tasks.toSorted((a, b) => a.dueDate - b.dueDate);
// `tasks` is untouched. `sortedTasks` is a fresh array.
```

Alternative for older targets:

```ts
const sortedTasks = [...tasks].sort((a, b) => a.dueDate - b.dueDate);
```

`[...arr].sort()` is functionally equivalent. `toSorted()` is one operation instead of two.

## Related ES2023 immutable companions

- `toReversed()` — `arr.reverse()` mutates; `arr.toReversed()` returns a new array.
- `toSpliced(start, deleteCount, ...items)` — `splice` mutates; `toSpliced` returns a new array.
- `with(index, value)` — equivalent of "set this index to a new value" without mutating.

All four are React-friendly defaults.

## Browser support

- Chrome / Edge 110+ (Feb 2023)
- Safari 16 (Sep 2022)
- Firefox 115 (Jul 2023)

For anything older, the spread+sort pattern is the fallback.

## When NOT to apply

- **Truly local arrays with no consumer outside the function** — in-place sort is fine for a temp.
- **You actually want to mutate (e.g., sorting a draft inside Immer)** — `sort()` in Immer-managed code is correct.

## Verify

Linter rule `no-array-sort` (or `react/no-array-mutate` in some configs) flags `.sort()` on the result of `useState` / `useQuery`. Add it.

## Related

- [`min-max-loop`](./min-max-loop.md) — when you only need min/max, skip sorting altogether.
