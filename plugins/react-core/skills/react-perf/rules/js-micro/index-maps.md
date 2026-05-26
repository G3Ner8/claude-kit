---
title: Build a Map for O(1) Lookups, Not Repeated `.find()`
impact: MEDIUM
impactDescription: turns an O(N) lookup into O(1); the cost of building the Map is amortized once per N lookups, with breakeven at N = 2-3
tags: js-micro, map, lookup, complexity, find
---

## Build a Map for O(1) Lookups, Not Repeated `.find()`

`array.find((x) => x.id === target)` is O(N) per call. If you do this inside a loop or for every row in a list, you've got O(N²) — fine for 10 items, painful for 1000.

A `Map` (or a plain object index) is O(1) per lookup. The setup cost is one O(N) walk to build the Map. Past ~2 lookups, you're already winning.

**Incorrect — nested `.find()` is O(N²):**

```ts
function joinEmployeesWithRoles(employees: Employee[], roles: Role[]) {
  return employees.map((e) => ({
    ...e,
    role: roles.find((r) => r.id === e.roleId),   // O(N) per row → O(N×M) total
  }));
}
```

For 500 employees × 200 roles, that's 100,000 comparisons.

**Correct — Map index, O(N+M):**

```ts
function joinEmployeesWithRoles(employees: Employee[], roles: Role[]) {
  const rolesById = new Map(roles.map((r) => [r.id, r]));    // O(M)
  return employees.map((e) => ({
    ...e,
    role: rolesById.get(e.roleId),    // O(1) per row → O(N) total
  }));
}
```

500 employees × 1 lookup each = 500. Plus 200 to build the Map. Total 700 — 142x faster than the original 100k.

## `Map` vs plain object

| | `Map` | Plain object `{}` |
|---|---|---|
| Key type | any | strings/symbols only |
| Performance | optimized for frequent set/get | optimized for fixed shapes |
| Iteration order | insertion | undefined (mostly insertion) |
| Size | `.size` (constant time) | `Object.keys(...).length` (O(N)) |
| When? | dynamic key sets, non-string keys | static-ish shapes, JSON-friendly |

For hot indexing paths, `Map` is the right choice.

## Memoize the index

If the source array doesn't change often (rolesById built from a stable list), wrap the construction in `useMemo`:

```ts
const rolesById = useMemo(() => new Map(roles.map((r) => [r.id, r])), [roles]);
```

The Map rebuilds only when `roles` changes.

## When NOT to apply

- **One lookup per render** — the Map build cost equals the find cost. Net zero.
- **Very small N** — 5-element arrays don't benefit. The Map's per-operation overhead is comparable to a find.
- **You're iterating in array order anyway** — don't switch to Map just to lose the ordering. Use a Map but keep the array for iteration.

## Related

- [`set-map-lookups`](./set-map-lookups.md) — Set for membership checks (just "is X present"), Map for key→value lookups.
