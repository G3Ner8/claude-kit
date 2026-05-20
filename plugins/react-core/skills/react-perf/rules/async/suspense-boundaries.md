---
title: Strategic Suspense Boundaries
impact: HIGH
impactDescription: faster perceived load — wrapper UI paints before data resolves
tags: async, suspense, streaming, layout-shift, tanstack-query
---

## Strategic Suspense Boundaries

When a parent component blocks on data, *the entire subtree* waits — including layout chrome (sidebar, header, footer) that doesn't depend on the data. Wrap only the data-dependent piece in `<Suspense>` so the rest paints immediately and skeletons show only where data is actually pending.

**Incorrect (whole page blocked by one query):**

```tsx
function DashboardPage() {
  // useSuspenseQuery throws a promise — the entire DashboardPage suspends
  const { data } = useSuspenseQuery({
    queryKey: ['dashboard'],
    queryFn: fetchDashboard,
  })

  return (
    <Layout>
      <Sidebar />
      <Header />
      <main>
        <DashboardContent data={data} />
      </main>
      <Footer />
    </Layout>
  )
}
```

The user sees nothing until `fetchDashboard` resolves. Sidebar, Header, Footer all wait.

**Correct (boundary around just the data-dependent piece):**

```tsx
function DashboardPage() {
  return (
    <Layout>
      <Sidebar />
      <Header />
      <main>
        <Suspense fallback={<DashboardSkeleton />}>
          <DashboardContent />
        </Suspense>
      </main>
      <Footer />
    </Layout>
  )
}

function DashboardContent() {
  const { data } = useSuspenseQuery({
    queryKey: ['dashboard'],
    queryFn: fetchDashboard,
  })

  return <DashboardBody data={data} />
}
```

Sidebar, Header, Footer paint on first frame. Only the `<main>` shows a skeleton while data loads.

### Multiple parallel boundaries

If a page has multiple independent data sections, give each its own boundary so a slow one doesn't block the fast ones:

```tsx
function DashboardPage() {
  return (
    <Layout>
      <Sidebar />
      <Header />
      <main className="grid grid-cols-2 gap-4">
        <Suspense fallback={<RevenueSkeleton />}>
          <RevenuePanel />     {/* uses useSuspenseQuery */}
        </Suspense>
        <Suspense fallback={<UsersSkeleton />}>
          <ActiveUsersPanel /> {/* uses useSuspenseQuery */}
        </Suspense>
      </main>
    </Layout>
  )
}
```

If `ActiveUsersPanel` is faster, it paints first. They don't block each other.

### Avoid serial Suspense

A `<Suspense>` boundary that contains a *child* `<Suspense>` is fine, but make sure both children's queries **start in parallel**, not after the outer one resolves. With TanStack Query this works naturally because queries are deduped by `queryKey` and started on first render. The pitfall is:

```tsx
// Bad — Child can't start its fetch until Parent's data is read
function Parent() {
  const { data: user } = useSuspenseQuery({ queryKey: ['user'], queryFn: fetchUser })
  return <Child userId={user.id} />
}

function Child({ userId }: { userId: string }) {
  const { data: orders } = useSuspenseQuery({
    queryKey: ['orders', userId],
    queryFn: () => fetchOrders(userId),
  })
  return <OrderList orders={orders} />
}
```

If you know the `userId` ahead of time (e.g., from the route), kick off both queries at the same level so they run in parallel.

### When NOT to add a boundary

- The data is needed to decide the **layout** (e.g., user role → which sidebar to show). Showing chrome that flips after data loads causes layout shift.
- The query is fast (cached, prefetched, or local). The Suspense overhead is then more disruptive than the wait.
- A single boundary higher up gives a cleaner skeleton — don't shred the page into a dozen independently-spinning sections.

**Trade-off:** Faster initial paint vs. potential layout shift. Choose based on whether the chrome can render meaningfully without the data.

Reference: [TanStack Query — Suspense](https://tanstack.com/query/latest/docs/framework/react/guides/suspense), [React Suspense](https://react.dev/reference/react/Suspense)
