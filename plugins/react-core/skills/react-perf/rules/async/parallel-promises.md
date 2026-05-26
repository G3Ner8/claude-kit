---
title: Promise.all for Independent Work
impact: CRITICAL
impactDescription: 2-10x speedup whenever two unrelated awaits happen back-to-back
tags: async, parallelization, promises, waterfalls
---

## Promise.all for Independent Work

When two async operations have no data dependency on each other, run them concurrently. Each sequential `await` adds its full latency to the critical path; `Promise.all` collapses them to the maximum, not the sum.

This is the single most common waterfall pattern. If a profiler shows multiple sequential network calls in the same function, this rule applies.

**Incorrect — sequential awaits even though the calls are independent:**

```ts
async function loadDashboard(userId: string) {
  const profile      = await fetchProfile(userId);       // 220 ms
  const tasks        = await fetchTasks(userId);         // 180 ms
  const notifications = await fetchNotifications(userId); // 240 ms
  return { profile, tasks, notifications };              // total: 640 ms
}
```

The browser waits 640 ms to render. Nothing in `fetchTasks` or `fetchNotifications` needs the result of `fetchProfile`.

**Correct — Promise.all (or destructured):**

```ts
async function loadDashboard(userId: string) {
  const [profile, tasks, notifications] = await Promise.all([
    fetchProfile(userId),         // 220 ms
    fetchTasks(userId),           // 180 ms ┐
    fetchNotifications(userId),   // 240 ms │ in parallel
  ]);                                       // ┘
  return { profile, tasks, notifications }; // total: 240 ms (max of 3)
}
```

Three round-trips, one round-trip cost.

## When one failure shouldn't kill the others

`Promise.all` rejects as soon as any call fails — the other (already-running) responses are discarded. If partial success is acceptable, use `Promise.allSettled`:

```ts
async function loadDashboardPartial(userId: string) {
  const results = await Promise.allSettled([
    fetchProfile(userId),
    fetchTasks(userId),
    fetchNotifications(userId),
  ]);

  return {
    profile:       results[0].status === 'fulfilled' ? results[0].value : null,
    tasks:         results[1].status === 'fulfilled' ? results[1].value : [],
    notifications: results[2].status === 'fulfilled' ? results[2].value : [],
  };
}
```

`allSettled` always resolves — each item carries its own success/failure. Use it for dashboards where a degraded view is better than no view.

## When NOT to apply

- **Sequential dependency** — if `B` needs `A`'s id, you can't parallelize them. Refactor the API instead (return both in one call), or `Promise.all` only the truly-independent calls.
- **Rate-limited APIs** — three calls hitting the same upstream can trip a per-IP rate limiter. Run a queue or batch instead.
- **Memory-heavy responses** — three 50 MB downloads in parallel use 150 MB of RAM transiently. Sequence on resource-constrained clients (mobile).

## In React

Inside a component, parallel fetches usually take the form of multiple `useQuery` calls on the same render:

```tsx
function Dashboard({ userId }: { userId: string }) {
  // All three queries fire on mount in parallel — TanStack Query handles concurrency.
  const profile       = useQuery({ queryKey: ['profile', userId],       queryFn: () => fetchProfile(userId) });
  const tasks         = useQuery({ queryKey: ['tasks', userId],         queryFn: () => fetchTasks(userId) });
  const notifications = useQuery({ queryKey: ['notifications', userId], queryFn: () => fetchNotifications(userId) });

  if (profile.isLoading) return <Skeleton />;
  return <DashboardLayout profile={profile.data} tasks={tasks.data} notifications={notifications.data} />;
}
```

No manual `Promise.all` needed — the library kicks off all three concurrently on mount.

## Related

- [`defer-await`](./defer-await.md) — when only one of N is sometimes-needed, defer instead of parallelize.
- [`suspense-boundaries`](./suspense-boundaries.md) — when each part should *render* independently as it arrives, not just *fetch* in parallel.
