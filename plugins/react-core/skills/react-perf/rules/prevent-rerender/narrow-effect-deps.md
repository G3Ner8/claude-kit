---
title: Narrow Effect Dependencies
impact: LOW
impactDescription: minimizes spurious effect re-runs when only a small slice of a larger value actually matters to the effect
tags: prevent-rerender, useEffect, useMemo, dependencies
---

## Narrow Effect Dependencies

A `useEffect` dependency array re-fires the effect whenever any listed value changes by reference. If the effect only reads `user.id`, listing `user` (the whole object) makes it fire on every unrelated user-field change. List the **narrowest primitive value** the effect actually depends on.

The same rule applies to `useMemo` and `useCallback`: list only what changes drive the recomputation.

**Incorrect — depends on the whole object:**

```tsx
useEffect(() => {
  loadProfile(user.id);
}, [user]);
```

If `user.lastSeenAt` updates every minute but `user.id` is stable, the effect re-runs every minute for no reason.

**Correct — depends on the narrow primitive:**

```tsx
useEffect(() => {
  loadProfile(user.id);
}, [user.id]);
```

The effect re-fires only when `user.id` actually changes — which is what `loadProfile` cares about.

## Multiple-field deps

If the effect reads multiple fields, list each one individually:

```ts
useEffect(() => {
  if (user.id && user.role === 'admin') loadAuditLog(user.id);
}, [user.id, user.role]);
```

Listing `[user.id, user.role]` is more accurate than `[user]` and lets you read the lint rule (`exhaustive-deps`) literally.

## When the object identity is the trigger

If the *whole* object changes meaningfully when fields change (e.g., the user logged in as a different account), `[user]` is correct. The narrowing rule applies to cases where most fields are noise.

## Functional setState lets you omit state-as-dep

```tsx
useEffect(() => {
  const id = setInterval(() => setCount((c) => c + 1), 1000);
  return () => clearInterval(id);
}, []);   // empty deps — `setCount` is referentially stable
```

By using `(c) => c + 1` instead of `count + 1`, the effect doesn't capture `count` in its closure, so `count` doesn't need to be a dep. The interval mounts once and runs cleanly.

See [`functional-setstate`](./functional-setstate.md) for the wider pattern.

## When NOT to apply

- **You'd be lying to the linter** — never silence `exhaustive-deps` to omit a value the effect actually reads. The lint rule is correct; restructure the effect instead (move logic to a handler, use functional setState).
- **`useCallback` for a tiny callback that React Compiler will inline anyway** — in compiler-enabled projects, manual `useCallback` adds friction with no benefit.

## Related

- [`derived-state`](./derived-state.md) — for selectors, narrow at the subscription level, not the dependency level.
- [`functional-setstate`](./functional-setstate.md) — lets you drop state from dependency arrays safely.
