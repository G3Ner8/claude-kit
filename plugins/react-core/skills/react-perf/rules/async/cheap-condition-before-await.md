---
title: Gate Awaits Behind Cheap Sync Checks
impact: CRITICAL
impactDescription: skips an entire network round-trip whenever a synchronous check could have answered the question first
tags: async, latency, waterfall, short-circuit
---

## Gate Awaits Behind Cheap Sync Checks

Every `await` on a network call adds the full round-trip to the user's critical path — even when the result will be discarded. Before committing to that latency, ask whether a cheap synchronous check can rule the request out entirely.

The pattern is mechanical: put the cheap check first, return early, and only `await` when you're actually going to use the value.

**Incorrect — fires the request unconditionally, then discards:**

```ts
async function loadUserDetail(id: string, viewer: Viewer) {
  const user = await fetchUser(id);          // network round-trip
  if (viewer.role === 'guest') return null;          // could have known this from the prop
  if (id.length !== 36) return null;                 // could have known this from the argument
  return user;
}
```

Every guest visitor pays the round-trip cost of a request they were never allowed to see.

**Correct — sync filters first, network only when needed:**

```ts
async function loadUserDetail(id: string, viewer: Viewer) {
  if (viewer.role === 'guest')   return null;
  if (id.length !== 36)          return null;
  return await fetchUser(id);
}
```

The check order matters: arrange by cost, ascending. Constant-time scalar checks before object-property checks before array/object scans before any IO.

## When NOT to apply

- **The cheap check depends on the network result** — if `viewer.canView` requires the user record to evaluate, you can't gate on it.
- **Speculative prefetch** — if you're warming a cache that may serve other call sites later, the early bail-out wastes the cache fill. That's a deliberate trade-off; mark it in a comment.
- **Race-free invariants you're trying to *verify*** — if the point of fetching is to confirm the sync check was right (e.g., revalidating an authorization claim against the server), don't skip the fetch.

## In React

Inside a query hook, the equivalent is the `enabled` flag:

```ts
function useUser(id: string) {
  const { viewer } = useViewer();
  return useQuery({
    queryKey: ['user', id],
    queryFn: () => fetchUser(id),
    enabled: viewer.role !== 'guest' && id.length === 36,
  });
}
```

`enabled: false` prevents the query from running at all — the hook still returns a stable shape with `isLoading: false, data: undefined`.
