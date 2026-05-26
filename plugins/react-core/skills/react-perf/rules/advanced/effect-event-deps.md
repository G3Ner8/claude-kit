---
title: Keep `useEffectEvent` Out of Effect Deps
impact: MEDIUM
impactDescription: `useEffectEvent` is the React 19 escape hatch for "always-fresh callback that shouldn't trigger effect re-runs" — listing it in deps defeats its entire purpose
tags: advanced, useEffectEvent, useEffect, react19
---

## Keep `useEffectEvent` Out of Effect Deps

React 19's `useEffectEvent` (still under the `experimental_` prefix in some builds) wraps a function so that:

1. The function always reads the **latest** state and props (no stale closure).
2. The function is **referentially stable** — it doesn't change between renders.
3. **Crucially**, the effect that calls it does **not** re-run when state/props change.

The third property is the whole reason `useEffectEvent` exists. If you list the wrapped function in the effect's dep array, you defeat that property — the effect re-runs because of the captured state, even though the wrapper is stable.

The rule is enforced by lint (`react-hooks/exhaustive-deps` handles `useEffectEvent` correctly and explicitly **excludes** it from the deps it requires).

**Incorrect — `onPing` listed in deps:**

```tsx
function Chat({ roomId, userId }: { roomId: string; userId: string }) {
  const onPing = useEffectEvent(() => {
    analytics.track('ping', { roomId, userId });   // always reads latest
  });

  useEffect(() => {
    const id = setInterval(onPing, 5000);
    return () => clearInterval(id);
  }, [roomId, userId, onPing]);   // ❌ userId/roomId here re-fires every change
}
```

Every time `userId` changes, the interval tears down and re-sets — defeating the "stable interval" goal.

**Correct — only the effect's *real* deps (the room subscription itself):**

```tsx
function Chat({ roomId, userId }: { roomId: string; userId: string }) {
  const onPing = useEffectEvent(() => {
    analytics.track('ping', { roomId, userId });
  });

  useEffect(() => {
    const id = setInterval(onPing, 5000);
    return () => clearInterval(id);
  }, []);   // ✅ no deps — the effect stays mounted; onPing reads fresh state
}
```

The interval mounts once. Every tick, `onPing` reads the current `roomId` and `userId` from the latest render.

## When to reach for `useEffectEvent`

The pattern earns its keep when:

- A long-lived effect (interval, subscription, event listener) calls back into your component.
- The callback needs the latest state, but the effect itself shouldn't restart on every state change.

This is the textbook "Effect Event" — the *event* part of an effect that should fire fresh, while the rest of the effect lifecycle is stable.

## When NOT to apply

- **The effect actually depends on the value** — if the subscription URL changes when `roomId` changes, the effect *should* tear down and resubscribe. `useEffectEvent` is the wrong tool.
- **Pre-React-19 codebases** — the hook isn't shipped. Workaround: store the callback in a ref and read `ref.current()` inside the effect.

## Related

- [`prevent-rerender/move-effect-to-event`](../prevent-rerender/move-effect-to-event.md) — many `useEffect` calls should be event handlers; only the remainder needs `useEffectEvent`.
- [`prevent-rerender/narrow-effect-deps`](../prevent-rerender/narrow-effect-deps.md) — the linter that enforces deps also handles `useEffectEvent`. Don't silence it.
