---
title: Use `flatMap` Instead of `.map().filter(Boolean)`
impact: LOW
impactDescription: one allocation instead of two, plus the intent ("transform-and-keep") is clearer than "transform-and-then-filter"
tags: js-micro, array, flatMap, idiom
---

## Use `flatMap` Instead of `.map().filter(Boolean)`

`.map(fn).filter(Boolean)` allocates two arrays: one from the map, one from the filter. `flatMap` produces one — and the callback can return `[]` to skip an entry or `[value]` to keep it, expressing "transform and conditionally keep" in one call.

The savings are small on each call but add up in hot paths (per-row callbacks in lists, normalize-on-render reducers).

**Incorrect — two passes, two allocations:**

```ts
const visibleNames = users
  .map((u) => (u.isActive ? u.name.trim() : null))
  .filter(Boolean);
```

The intermediate array has `null`s where the active check failed. The filter walks it again to remove them.

**Correct — one pass via `flatMap`:**

```ts
const visibleNames = users.flatMap((u) =>
  u.isActive ? [u.name.trim()] : []
);
```

Active users contribute `[name]`; inactive contribute `[]`. `flatMap` flattens — one allocation, one walk.

## When the predicate is simple

For "keep where x is truthy" without transformation, just `filter` is fine:

```ts
const activeUsers = users.filter((u) => u.isActive);
```

`flatMap` shines when you're **both** filtering and transforming.

## TypeScript inference

`flatMap` infers correctly when the return type is `T[]`:

```ts
const ids = items.flatMap((i): string[] => (i.kind === 'user' ? [i.id] : []));
//    ^? string[]
```

If you want type narrowing on the kept items, narrow inside the callback.

## When NOT to apply

- **The intermediate array is useful** — if you need both the mapped form (with nulls) and the filtered form, two separate calls are clearer.
- **Predicate-only filters** — `filter(fn)` is simpler than `flatMap((x) => fn(x) ? [x] : [])`.

## Related

- [`set-map-lookups`](./set-map-lookups.md) — when the filter checks membership against another collection, use a Set for O(1) lookup.
