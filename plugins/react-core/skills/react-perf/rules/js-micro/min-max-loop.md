---
title: One-Pass Loop Beats Sort-Then-Pick for Min/Max
impact: LOW
impactDescription: O(N) instead of O(N log N), with constant-factor wins from avoiding allocation
tags: js-micro, sort, min-max, complexity, loop
---

## One-Pass Loop Beats Sort-Then-Pick for Min/Max

To find the min or max of an array, walking once and tracking the best value is O(N). Sorting is O(N log N), plus it allocates a new array (with `.toSorted` or `[...arr].sort()`).

For *just min or just max*, a loop is strictly better.

**Incorrect — sort just to pick one:**

```ts
function newestPostDate(posts: Post[]): Date {
  const sorted = posts.toSorted((a, b) => b.createdAt - a.createdAt);
  return sorted[0].createdAt;
}
```

O(N log N) + allocation, when O(N) suffices.

**Correct — single pass:**

```ts
function newestPostDate(posts: Post[]): Date | undefined {
  if (posts.length === 0) return undefined;
  let newest = posts[0].createdAt;
  for (let i = 1; i < posts.length; i++) {
    if (posts[i].createdAt > newest) newest = posts[i].createdAt;
  }
  return newest;
}
```

For comparable primitives, `reduce` reads even cleaner:

```ts
const newest = posts.reduce(
  (best, p) => (p.createdAt > best ? p.createdAt : best),
  posts[0].createdAt,
);
```

Or for numbers specifically:

```ts
const max = Math.max(...nums);    // fine for small arrays
```

`Math.max(...arr)` is concise but spreads the array into arguments — engines impose limits (~100k items) and the spread allocates. For known-small arrays it's fine; for larger ones, prefer the loop.

## When you need top-K

If you actually need the **K smallest/largest** (not just min/max), sorting wins past K = log N. For K=3 in a 1000-item array, a single pass with three pointers beats sort by a few constants but the code is ugly — sort + slice is more readable and fast enough.

## When NOT to apply

- **You need a sorted result anyway** — sort once; pick from the result.
- **The array is tiny (< 20)** — engine overhead makes both approaches identical.

## Related

- [`tosorted-immutable`](./tosorted-immutable.md) — when you do want a sorted copy, prefer `toSorted()` over `[...arr].sort()`.
