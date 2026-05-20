---
title: Use a Query Library for Automatic Deduplication
impact: MEDIUM-HIGH
impactDescription: removes redundant network requests and centralizes cache/revalidation
tags: client, tanstack-query, swr, deduplication, data-fetching, cache
---

## Use a Query Library for Automatic Deduplication

Two components rendering at the same time and calling `fetch('/api/users')` produce **two network requests**. Three components → three requests. The classic anti-pattern is `useEffect` + `useState` + `fetch`:

**Incorrect (every instance fetches independently):**

```tsx
function UserList() {
  const [users, setUsers] = useState<User[]>([])

  useEffect(() => {
    fetch('/api/users')
      .then(r => r.json())
      .then(setUsers)
  }, [])

  return <List items={users} />
}
```

Render `<UserList />` three times on the same page → three GET `/api/users`. Add navigation, focus refetch, polling, retry-on-error, error states, and you're rebuilding a cache library by hand — badly.

### Correct — TanStack Query

```tsx
import { useQuery } from '@tanstack/react-query'

function UserList() {
  const { data: users = [] } = useQuery({
    queryKey: ['users'],
    queryFn: () => fetch('/api/users').then(r => r.json()),
    staleTime: 60_000, // 1min — don't refetch unless older than this
  })

  return <List items={users} />
}
```

All `useQuery` calls with the same `queryKey` share **one** in-flight request and one cache entry. The library handles:

- **Dedup** of concurrent requests
- **Cache** keyed by `queryKey`
- **Background revalidation** on window focus / reconnect / mount
- **Stale-while-revalidate** — show cached data immediately, refetch in background
- **Retry** with exponential backoff
- **Pagination / infinite scroll** primitives
- **Mutation** with optimistic updates and cache invalidation

### Suspense variant — `useSuspenseQuery`

When you want the component to suspend (and a parent `<Suspense>` to show the fallback) until data is ready:

```tsx
import { useSuspenseQuery } from '@tanstack/react-query'

function UserList() {
  const { data: users } = useSuspenseQuery({
    queryKey: ['users'],
    queryFn: () => fetch('/api/users').then(r => r.json()),
  })
  return <List items={users} />
}
```

`data` is now non-nullable — no loading state to handle inside the component. Pair with strategic Suspense boundaries (see [Strategic Suspense Boundaries](../async/suspense-boundaries.md)).

### Mutations

For writes, use `useMutation` so you can invalidate the relevant cache entries afterward:

```tsx
import { useMutation, useQueryClient } from '@tanstack/react-query'

function UpdateUserButton({ user }: { user: User }) {
  const queryClient = useQueryClient()

  const { mutate, isPending } = useMutation({
    mutationFn: (updates: Partial<User>) =>
      fetch(`/api/users/${user.id}`, {
        method: 'PATCH',
        body: JSON.stringify(updates),
      }).then(r => r.json()),

    onSuccess: () => {
      // Refetch the list so the UI reflects the change
      queryClient.invalidateQueries({ queryKey: ['users'] })
    },
  })

  return (
    <button disabled={isPending} onClick={() => mutate({ name: 'New Name' })}>
      Update
    </button>
  )
}
```

### SWR equivalent

If you're using SWR instead, the same principles apply:

```tsx
import useSWR from 'swr'

function UserList() {
  const { data: users = [] } = useSWR('/api/users', fetcher)
  return <List items={users} />
}
```

Both libraries dedupe by key (`queryKey` in TanStack Query, the first arg in SWR) — the rule is the same: **never put `fetch` directly inside `useEffect` for shared data**. Either use a query library, or wrap your own deduping primitive — but don't roll the fetch by hand.

### Key naming hygiene

Treat `queryKey` like a cache key, not a free-form string. Include every input that affects the response:

```tsx
useQuery({
  queryKey: ['users', { page, filters }],   // page and filters are part of the key
  queryFn: () => fetchUsers({ page, filters }),
})
```

Mis-keyed queries cause stale data and confusing cache hits — bigger source of bugs than the fetch logic itself.

Reference: [TanStack Query – Queries](https://tanstack.com/query/latest/docs/framework/react/guides/queries), [TanStack Query – Query Keys](https://tanstack.com/query/latest/docs/framework/react/guides/query-keys), [SWR](https://swr.vercel.app)
