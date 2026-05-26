---
title: Promise.all for Independent Operations
impact: CRITICAL
impactDescription: 2-10× speedup for unrelated async work
tags: async, parallelization, promises, waterfalls
---

## Promise.all for Independent Operations

When async operations have no interdependencies, run them concurrently using `Promise.all()` (or `Promise.allSettled()`) instead of sequential `await`s. Each sequential `await` adds the full latency of that call to the critical path.

**Incorrect (sequential — 3 round trips on the critical path):**

```ts
const user = await fetchUser()
const posts = await fetchPosts()
const comments = await fetchComments()
```

Total time ≈ `t(user) + t(posts) + t(comments)`.

**Correct (parallel — 1 round trip on the critical path):**

```ts
const [user, posts, comments] = await Promise.all([
  fetchUser(),
  fetchPosts(),
  fetchComments(),
])
```

Total time ≈ `max(t(user), t(posts), t(comments))`.

### `Promise.all` vs `Promise.allSettled` — pick the right one

`Promise.all` rejects as soon as **any** input rejects. The other in-flight requests are not cancelled, but their results are discarded. For UI work this is usually wrong — you almost never want a single failed sidebar widget to throw away the user's main content.

Prefer `Promise.allSettled` when **partial success is acceptable**:

```ts
const [userResult, postsResult, commentsResult] = await Promise.allSettled([
  fetchUser(),
  fetchPosts(),
  fetchComments(),
])

const user = userResult.status === 'fulfilled' ? userResult.value : null
const posts = postsResult.status === 'fulfilled' ? postsResult.value : []
const comments = commentsResult.status === 'fulfilled' ? commentsResult.value : []
```

Use `Promise.all` only when **all** results are strictly required (e.g., the page literally cannot render without every value) and you want the failure to bubble up.

### When operations have partial dependencies

If `fetchComments()` needs the `user.id`, restructure so the part that *doesn't* need the user runs in parallel:

```ts
// Bad: comments waits even though posts could run in parallel
const user = await fetchUser()
const comments = await fetchComments(user.id)
const posts = await fetchPosts()

// Better: posts runs in parallel with the user fetch
const [user, posts] = await Promise.all([fetchUser(), fetchPosts()])
const comments = await fetchComments(user.id)
```

### In React: prefer letting the query library parallelize

If you're using TanStack Query, SWR, or similar, the library already runs independent `useQuery` calls in parallel — you usually don't need explicit `Promise.all`. The trap to avoid is awaiting one query result before starting the next, which forces a waterfall the library cannot eliminate.
