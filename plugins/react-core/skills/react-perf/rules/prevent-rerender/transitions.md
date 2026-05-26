---
title: Use `startTransition` for Non-Urgent Updates
impact: MEDIUM
impactDescription: marks a state update as interruptible so a slower render doesn't block typing/clicking — input feels responsive even when the visible result lags
tags: prevent-rerender, transition, useTransition, react18, concurrent
---

## Use `startTransition` for Non-Urgent Updates

Not every state update is equally urgent. Updating the value of a controlled input must happen on the next render — the user is waiting to see what they typed. Updating a filtered list of 5,000 rows based on that input can wait a frame or two — the user knows the work is happening and would rather keep typing smoothly.

`startTransition` marks the second kind of update as "non-urgent." React renders it concurrently with the urgent update, and if more urgent work arrives (the user types again), the transition restarts with the new value instead of completing the old render first.

The result: input stays at 60Hz even when downstream computation is slow.

**Incorrect — sync update on every keystroke:**

```tsx
function SearchableList({ items }: { items: Item[] }) {
  const [query, setQuery] = useState('');
  const filtered = useMemo(
    () => items.filter((it) => it.name.toLowerCase().includes(query.toLowerCase())),
    [items, query],
  );

  return (
    <>
      <input value={query} onChange={(e) => setQuery(e.target.value)} />
      <ul>{filtered.map((it) => <li key={it.id}>{it.name}</li>)}</ul>
    </>
  );
}
```

With 10,000 items, the filter takes ~30 ms. Each keystroke blocks for 30 ms. Typing feels laggy.

**Correct — split urgent and non-urgent updates:**

```tsx
function SearchableList({ items }: { items: Item[] }) {
  const [inputValue, setInputValue] = useState('');
  const [query, setQuery]           = useState('');
  const [isPending, startTransition] = useTransition();

  const filtered = useMemo(
    () => items.filter((it) => it.name.toLowerCase().includes(query.toLowerCase())),
    [items, query],
  );

  return (
    <>
      <input
        value={inputValue}
        onChange={(e) => {
          setInputValue(e.target.value);     // urgent — shows the user what they typed
          startTransition(() => setQuery(e.target.value));   // non-urgent — list catches up
        }}
      />
      {isPending && <Spinner size="sm" />}   // optional: signal stale results
      <ul>{filtered.map((it) => <li key={it.id}>{it.name}</li>)}</ul>
    </>
  );
}
```

The input updates instantly on every keystroke. The list re-renders when it can — interrupted and restarted whenever the user types again. The visible input stays at 60Hz; the list catches up at its own pace.

## `useTransition` vs `startTransition`

- `useTransition()` returns `[isPending, startTransition]` — use inside components.
- The standalone `startTransition(fn)` (imported from `react`) — use outside components (event handlers attached imperatively, store actions). No `isPending` flag.

## When NOT to apply

- **Fast updates** — if the work is under a few ms, `startTransition` adds overhead with no perceived benefit.
- **The update is the user's intent** — if the user clicks "filter," the filter result is the urgent thing. Don't transition the user's primary action.
- **Form submissions, mutations** — these should complete synchronously from the user's POV. Use loading states, not transitions.

## Verify

Chrome DevTools → Performance → record typing into the input. With `startTransition`, you should see frequent low-priority "render" tasks that get interrupted, never blocking input handling.

## Related

- [`use-deferred-value`](./use-deferred-value.md) — same idea, but with two-derived-values where you can't (or don't want to) hold two state pieces.
- [`render-output/usetransition-loading`](../render-output/usetransition-loading.md) — for the loading-spinner pattern using `isPending`.
