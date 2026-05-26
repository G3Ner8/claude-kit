---
title: Use Set/Map for O(1) Membership Checks
impact: MEDIUM
impactDescription: `.includes()` inside a loop is O(N×M); a Set converts each lookup to O(1)
tags: js-micro, set, includes, lookup, complexity
---

## Use Set/Map for O(1) Membership Checks

`array.includes(x)` is O(N) — it scans the whole array on every call. Inside a loop, that's O(N×M) cost. A `Set` answers the same question in O(1).

The constants matter: V8's `Set.has` is hashtable-based and stays fast even for large sets. Don't optimize prematurely on 10-element arrays, but for membership checks against any non-trivial collection, the difference is real.

**Incorrect — N×M with `.includes`:**

```ts
function filterByAllowed(rows: Row[], allowedIds: string[]) {
  return rows.filter((r) => allowedIds.includes(r.id));   // includes is O(M) per row
}
```

For 1000 rows × 200 allowed ids = 200,000 comparisons.

**Correct — Set-backed membership:**

```ts
function filterByAllowed(rows: Row[], allowedIds: string[]) {
  const allowed = new Set(allowedIds);                    // O(M) once
  return rows.filter((r) => allowed.has(r.id));           // O(1) per row
}
```

200 to build the Set + 1000 lookups = 1200 operations. ~166x faster.

## `Set` vs `Map`

- Use **`Set`** for "is X in this collection?" — pure membership.
- Use **`Map`** for "what's the value for X?" — key-to-value lookup. See [`index-maps`](./index-maps.md).

## Memoize when the collection is stable

If `allowedIds` doesn't change every render, build the Set once:

```ts
const allowed = useMemo(() => new Set(allowedIds), [allowedIds]);
```

## When NOT to apply

- **Small collections (< 20 items)** — overhead of Set creation may equal the `.includes` cost. Stick with the array.
- **One-shot membership check** — `if (statuses.includes('archived')) { ... }` is fine; no Set helps a single call.

## Related

- [`index-maps`](./index-maps.md) — when you need the matching object, not just yes/no.
- [`flatmap-filter`](./flatmap-filter.md) — `set.has(...)` composes nicely as the predicate in flatMap.
