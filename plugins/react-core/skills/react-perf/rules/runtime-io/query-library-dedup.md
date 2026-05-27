---
title: Use a Query Library for Automatic Dedup
impact: HIGH
impactDescription: stops the same endpoint from being fetched N times when N components ask for it simultaneously
tags: runtime, data-fetching, dedup, tanstack-query, swr, cache
---

## Use a Query Library for Automatic Dedup

If five components all need the current user, naive `fetch` calls fire five HTTP requests. A query library (TanStack Query, SWR) wraps the fetch in a keyed cache: the **first** call hits the network, the next four are deduped to the in-flight Promise. All five components subscribe; one network round-trip serves them all.

Beyond dedup, the libraries handle: caching with stale-while-revalidate, automatic refetch on window focus, request cancellation on unmount, and consistent loading/error state. That's why this rule has HIGH impact even though the savings can look invisible — a hand-rolled equivalent ends up reinventing 80% of the library badly.

**Incorrect — naive fetch in every component:**

```tsx
function CurrentUserAvatar() {
  const [user, setUser] = useState<User | null>(null);
  useEffect(() => { fetch('/api/me').then(r => r.json()).then(setUser); }, []);
  return user ? <img src={user.avatarUrl} /> : null;
}

function CurrentUserName() {
  const [user, setUser] = useState<User | null>(null);
  useEffect(() => { fetch('/api/me').then(r => r.json()).then(setUser); }, []);
  return user ? <span>{user.name}</span> : null;
}
```

Two components → two requests to `/api/me`. Per page render, per navigation. At scale: hundreds of duplicates per day.

**Correct — single shared query:**

```tsx
function useCurrentUser() {
  return useQuery({
    queryKey: ['me'],
    queryFn: () => fetch('/api/me').then(r => r.json() as Promise<User>),
    staleTime: 5 * 60 * 1000,   // 5 min: don't refetch on every mount
  });
}

function CurrentUserAvatar() {
  const { data: user } = useCurrentUser();
  return user ? <img src={user.avatarUrl} /> : null;
}

function CurrentUserName() {
  const { data: user } = useCurrentUser();
  return user ? <span>{user.name}</span> : null;
}
```

Both components mount → one HTTP request. Both read the same cache entry. When the user logs out, invalidate the key and both re-render with the new state.

## Key naming conventions

Query keys are arrays — ordered by specificity, from coarse to fine:

```ts
['users']                              // list endpoint
['users', { status: 'active' }]        // list with filters
['users', userId]                  // single resource
['users', userId, 'roles']         // nested resource
```

This shape lets you invalidate at any level:

```ts
queryClient.invalidateQueries({ queryKey: ['users'] });           // refetch everything users-related
queryClient.invalidateQueries({ queryKey: ['users', userId] }); // refetch just one user
```

Extract a `queryKey` factory per feature so call sites never hand-roll the array:

```ts
// features/users/api/keys.ts
export const userKeys = {
  all:        ['users'] as const,
  lists:      (filters: Filters) => [...userKeys.all, 'list', filters] as const,
  detail:     (id: string) =>      [...userKeys.all, 'detail', id] as const,
  roles:      (id: string) =>      [...userKeys.detail(id), 'roles'] as const,
};
```

Now `invalidateQueries({ queryKey: userKeys.all })` confidently refreshes the entire user tree without typos.

## When NOT to apply

- **One-shot, fire-and-forget calls** — analytics events, log shipping. No cache, no dedup needed.
- **Mutations that don't read back** — `POST /api/log-action` doesn't benefit from query caching. Use `useMutation` for cache invalidation semantics, not for the call itself.
- **WebSocket / SSE** — for live data, the query library isn't the right shape. Use `useSyncExternalStore` against your socket, or a dedicated streaming hook.

## Related

- **Query keys** ↔ cache invalidation. Plan the key shape before writing the first query.
- [`prevent-rerender/derived-state`](../prevent-rerender/derived-state.md) — when many consumers read the same query, narrow the selector so each re-renders only on the field it cares about.
