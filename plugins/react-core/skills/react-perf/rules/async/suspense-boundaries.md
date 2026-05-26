---
title: Suspense Boundaries for Streaming Render
impact: HIGH
impactDescription: lets ready-to-render parts of a page paint immediately while slower parts continue loading — pages feel faster even when total fetch time is unchanged
tags: async, suspense, streaming, ux, react19
---

## Suspense Boundaries for Streaming Render

`Promise.all` collapses N parallel fetches into the time of the slowest. But until the slowest finishes, the user sees a single page-wide skeleton — every fast result is held hostage by the slowest.

Suspense boundaries unblock that. Each boundary paints **as soon as its own data is ready**. The fast 50 ms widget paints in 50 ms; the slow 800 ms widget keeps its skeleton until 800 ms. Perceived performance improves even when the total work is unchanged.

The pattern requires two pieces:

1. A data-fetching primitive that **suspends** (throws a Promise during render) — `useSuspenseQuery` from TanStack Query, or React 19's `use(promise)`.
2. A `<Suspense>` boundary somewhere above the suspending component, with a `fallback` to show until it resolves.

**Incorrect — one boundary at the top: fast widgets blocked by the slowest:**

```tsx
function Dashboard() {
  return (
    <Suspense fallback={<DashboardSkeleton />}>
      {/* All three suspend; the page only paints when all three resolve. */}
      <ProfileCard />        {/* 50 ms fetch */}
      <TaskList />           {/* 200 ms fetch */}
      <ActivityFeed />       {/* 800 ms fetch — gates the entire page */}
    </Suspense>
  );
}
```

The user waits 800 ms staring at one skeleton.

**Correct — one boundary per independently-paintable region:**

```tsx
function Dashboard() {
  return (
    <DashboardLayout>
      <Suspense fallback={<ProfileSkeleton />}>
        <ProfileCard />        {/* paints at 50 ms */}
      </Suspense>
      <Suspense fallback={<TaskListSkeleton />}>
        <TaskList />           {/* paints at 200 ms */}
      </Suspense>
      <Suspense fallback={<ActivityFeedSkeleton />}>
        <ActivityFeed />       {/* paints at 800 ms */}
      </Suspense>
    </DashboardLayout>
  );
}

function ProfileCard() {
  // useSuspenseQuery throws the in-flight Promise — caught by the nearest <Suspense>.
  const { data: profile } = useSuspenseQuery({
    queryKey: ['profile'],
    queryFn:  fetchProfile,
  });
  return <ProfileCardLayout profile={profile} />;
}
```

Each component suspends independently; each boundary resolves on its own timeline.

## Boundary placement rules

- **One boundary per independently-paintable region.** Not per component — components that should appear together (e.g. a label and its value) share a boundary.
- **The boundary must be a *parent* of the suspending component**, not a sibling. React walks up the tree to find the nearest boundary; the layout above stays painted.
- **Place the fallback at the layout level the user will actually see**. A page-shell `<Suspense>` is rarely what you want; per-section boundaries usually are.

## Loading transitions

When the user navigates between two views that both suspend, you usually don't want the second view's fallback to flash. Wrap the navigation in `startTransition` (or `useTransition`):

```tsx
const [isPending, startTransition] = useTransition();

function navigate(next: string) {
  startTransition(() => setRoute(next));
}
```

While the transition is pending, React keeps the old UI visible and shows `isPending`. The fallback fires only if the new view takes longer than the transition deadline.

## When NOT to apply

- **Above-the-fold content** — putting your hero widget behind a Suspense boundary delays the largest contentful paint. Render hero content eagerly; suspend the below-fold parts.
- **Sequential dependencies** — if widget B's query depends on widget A's data, B can't paint until A is done anyway. The second `<Suspense>` is redundant.
- **Tests** — Suspense in tests usually requires a wrapping `<Suspense>` boundary in your render utility. Without it, every test fails with a thrown Promise. Bake it into your test setup.

## Related

- [`parallel-promises`](./parallel-promises.md) — when you need *all* data before rendering anything, parallelize but skip the boundaries.
- [`render-output/usetransition-loading`](../render-output/usetransition-loading.md) — when navigating between suspending views, hide the fallback flash with `useTransition`.
