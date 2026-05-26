---
title: Subscribe Only to Slices Used in Render
impact: MEDIUM
impactDescription: avoids re-renders when state the component only *reads in callbacks* (not in JSX) changes
tags: prevent-rerender, store, selector, subscription
---

## Subscribe Only to Slices Used in Render

A component re-renders when state it subscribes to changes. If the component **renders** a piece of state, it must subscribe. If the component only **reads it inside a callback** (an `onClick`, a debounced handler), subscribing is unnecessary — the callback runs fresh on each call anyway, and getting the latest value through a non-reactive read avoids the re-render.

Most state libraries (Zustand, Jotai, Redux-Toolkit) expose two access shapes:

1. A **reactive selector** that subscribes (`useStore((s) => s.count)`).
2. A **non-reactive read** that doesn't (`useStore.getState().count` for Zustand, `store.getState()` for Redux, `jotai`'s `useAtomCallback`).

Use the reactive one when the JSX displays the value; use the non-reactive one inside callbacks.

**Incorrect — subscribes to `tab` just to read it inside a click handler:**

```tsx
function TabBar() {
  // Re-renders on every tab change even though JSX doesn't depend on `tab`.
  const tab = useStore((s) => s.tab);
  const setTab = useStore((s) => s.setTab);

  return (
    <button onClick={() => {
      analytics.track('tab_switch', { from: tab, to: 'reports' });   // reads tab
      setTab('reports');
    }}>
      Reports
    </button>
  );
}
```

The button text doesn't depend on `tab`. Subscribing to it makes the component re-render on every tab change for nothing.

**Correct — non-reactive read inside the callback:**

```tsx
function TabBar() {
  const setTab = useStore((s) => s.setTab);   // setTab is stable; subscribing is cheap

  return (
    <button onClick={() => {
      const { tab } = useStore.getState();    // non-reactive: doesn't subscribe
      analytics.track('tab_switch', { from: tab, to: 'reports' });
      setTab('reports');
    }}>
      Reports
    </button>
  );
}
```

The component no longer re-renders on `tab` changes. The callback still gets the current value when invoked.

## Library-specific equivalents

| Library | Reactive subscribe | Non-reactive read |
|---|---|---|
| Zustand | `useStore((s) => s.x)` | `useStore.getState().x` |
| Redux Toolkit | `useSelector((s) => s.x)` | `store.getState().x` |
| Jotai | `useAtomValue(xAtom)` | `useAtomCallback` + `get(xAtom)` |
| TanStack Query | `useQuery({ queryKey })` | `queryClient.getQueryData(['x'])` |

## When NOT to apply

- **You need to react to changes outside the render** — if a non-render-path action should re-fire when the value changes (rare), you do need the subscription. But more often, you can `useEffect` keyed on the value instead.
- **The state is a primitive shown in JSX** — `<span>{tab}</span>` requires the subscription. There's no shortcut.

## Related

- [`derived-state`](./derived-state.md) — when you subscribe but only care about a derived boolean (`count > 0`), narrow the selector to the boolean.
- [`split-combined-hooks`](./split-combined-hooks.md) — sometimes the right fix is to split the underlying store so callback-only reads have a separate hook.
