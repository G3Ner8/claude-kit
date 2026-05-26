---
title: Refs for Transient Values That Shouldn't Re-render
impact: MEDIUM
impactDescription: high-frequency values (timer ticks, mouse position, scroll position) stored in state cause N renders per second — use a ref when you only read them in callbacks or effects
tags: prevent-rerender, useRef, useState, transient
---

## Refs for Transient Values That Shouldn't Re-render

`useState` triggers a re-render every time it updates. For values that change at 60Hz (mouse position, scroll position) or fire often (request counts, error timestamps), a state update per change is wasteful when the *displayed UI* doesn't react to every change.

Refs are the answer. `useRef` holds a mutable value across renders without triggering re-renders. Read it in callbacks/effects when you need the latest; never read it in JSX (the ref doesn't change, so JSX wouldn't update anyway).

**Incorrect — storing high-frequency state, re-rendering 60 times/sec:**

```tsx
function MouseTracker() {
  const [pos, setPos] = useState({ x: 0, y: 0 });

  useEffect(() => {
    const onMove = (e: MouseEvent) => setPos({ x: e.clientX, y: e.clientY });
    window.addEventListener('mousemove', onMove);
    return () => window.removeEventListener('mousemove', onMove);
  }, []);

  // pos is read here, but only when the user clicks
  const onClick = () => analytics.track('click', { ...pos });

  return <button onClick={onClick}>Track me</button>;
}
```

`setPos` fires on every `mousemove` (potentially 60 times/sec). The component re-renders every time — but JSX never reads `pos`, so the renders are pure waste.

**Correct — ref for the transient value:**

```tsx
function MouseTracker() {
  const posRef = useRef({ x: 0, y: 0 });

  useEffect(() => {
    const onMove = (e: MouseEvent) => {
      posRef.current = { x: e.clientX, y: e.clientY };   // mutate; no re-render
    };
    window.addEventListener('mousemove', onMove);
    return () => window.removeEventListener('mousemove', onMove);
  }, []);

  const onClick = () => analytics.track('click', { ...posRef.current });

  return <button onClick={onClick}>Track me</button>;
}
```

`mousemove` updates the ref directly. No re-renders. The click handler reads the latest position from the ref.

## Heuristic: state or ref?

- **Will the JSX render the value?** → `useState`.
- **Will memoized children compare against it?** → `useState`.
- **Will an effect dep array depend on it?** → `useState`.
- **None of the above — you just need the value fresh in a callback?** → `useRef`.

## When you need *both*

Sometimes you want to render a value rarely but read it often. Two patterns:

1. **Throttled state from ref**: ref updates at 60Hz; a setInterval syncs the ref to state once per second for display.

```tsx
const positionRef = useRef({ x: 0, y: 0 });
const [displayed, setDisplayed] = useState({ x: 0, y: 0 });

useEffect(() => {
  const id = setInterval(() => setDisplayed(positionRef.current), 1000);
  return () => clearInterval(id);
}, []);
```

2. **`useSyncExternalStore`** if many consumers want different sampling rates from the same source — see [`runtime-io/event-listeners`](../runtime-io/event-listeners.md).

## When NOT to apply

- **You actually render the value** — refs don't update JSX. If the UI must reflect the latest mouse position, `useState` is required (and you should consider `useDeferredValue` or `useTransition` to keep it cheap).
- **You need to share across components** — refs are local. For shared mutable state, use a store (Zustand/Jotai) with a subscription model.

## Related

- [`functional-setstate`](./functional-setstate.md) — when state updates need to be sequence-safe across async callbacks.
- [`runtime-io/event-listeners`](../runtime-io/event-listeners.md) — for high-frequency events, share one listener with a ref-backed value across consumers.
