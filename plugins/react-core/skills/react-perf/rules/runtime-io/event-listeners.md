---
title: Share One Global Listener Across Subscribers
impact: MEDIUM
impactDescription: avoids attaching a listener-per-component, which becomes O(N) work on every event for N components
tags: runtime, dom-events, listener, subscribers, cleanup
---

## Share One Global Listener Across Subscribers

When many components react to the same browser event (`resize`, `scroll`, `keydown`, online/offline), don't attach a fresh listener per component. Each component's `useEffect` adds a new listener; on every event the browser fires N callbacks; teardown adds N more attach/detach calls during navigation.

Better: maintain **one** listener at module level that fans out to a list of subscribers. Components subscribe/unsubscribe from the list — the global listener stays attached as long as anyone is subscribed.

**Incorrect — listener-per-component:**

```tsx
function useWindowSize() {
  const [size, setSize] = useState({ w: window.innerWidth, h: window.innerHeight });

  useEffect(() => {
    const onResize = () => setSize({ w: window.innerWidth, h: window.innerHeight });
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
  }, []);

  return size;
}
```

If 30 components use `useWindowSize`, the browser invokes 30 callbacks on every `resize` event. During a slow resize, that's 100s of callbacks per second.

**Correct — module-level singleton listener:**

```ts
// useWindowSize.ts
type Size = { w: number; h: number };
type Listener = (size: Size) => void;

let current: Size = { w: window.innerWidth, h: window.innerHeight };
const subscribers = new Set<Listener>();

function notify() {
  current = { w: window.innerWidth, h: window.innerHeight };
  subscribers.forEach((cb) => cb(current));
}

let attached = false;
function ensureAttached() {
  if (attached) return;
  window.addEventListener('resize', notify);
  attached = true;
}
function maybeDetach() {
  if (subscribers.size > 0) return;
  window.removeEventListener('resize', notify);
  attached = false;
}

export function useWindowSize() {
  const [size, setSize] = useState(current);

  useEffect(() => {
    subscribers.add(setSize);
    ensureAttached();
    return () => {
      subscribers.delete(setSize);
      maybeDetach();
    };
  }, []);

  return size;
}
```

One DOM listener, N React subscribers. Detach when the last consumer unmounts.

## Even cleaner with `useSyncExternalStore`

React 19's `useSyncExternalStore` is purpose-built for this pattern:

```ts
function subscribe(callback: () => void) {
  subscribers.add(callback);
  ensureAttached();
  return () => {
    subscribers.delete(callback);
    maybeDetach();
  };
}

function getSnapshot() {
  return current;
}

export function useWindowSize() {
  return useSyncExternalStore(subscribe, getSnapshot);
}
```

Same singleton listener; `useSyncExternalStore` handles the React-side subscription bookkeeping and is safe across concurrent renders.

## When NOT to apply

- **One listener per page** — if only one component listens, the singleton machinery is overkill. Just attach in `useEffect`.
- **Component-scoped events** — `onScroll` on a specific scrollable container belongs in JSX as `onScroll={...}` or attached to that container's ref, not as a global window listener.
- **High-frequency events that *all* subscribers need synchronously** — `mousemove` during a drag-resize, where each subscriber computes layout differently. The fanout overhead may exceed the per-listener cost.

## Related

- [`passive-event-listeners`](./passive-event-listeners.md) — for `scroll` and `touchmove`, also pass `{ passive: true }`.
- [`prevent-rerender/use-ref-transient-values`](../prevent-rerender/use-ref-transient-values.md) — when the subscriber doesn't need a re-render on every event (e.g. throttled).
