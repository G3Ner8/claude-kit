---
title: Move Interaction Logic to Event Handlers, Not Effects
impact: HIGH
impactDescription: `useEffect` is for syncing with external systems — using it for user actions causes extra renders and turns simple flows into infinite loops
tags: prevent-rerender, useEffect, events, react-philosophy
---

## Move Interaction Logic to Event Handlers, Not Effects

`useEffect` fires *after* render in response to a change in dependencies. It's the wrong place for logic that should happen *because the user did something*. If the trigger is a click, a submit, a keypress, or any direct interaction, the logic belongs in the **event handler**.

The anti-pattern:

> "When `selectedId` changes, send a tracking event."

`selectedId` only changes because the user clicked. The handler is where the click happens. Putting the tracking in a `useEffect` keyed on `selectedId` is indirection that:

1. **Renders once extra** — the state updates and renders before the effect fires.
2. **Fires on initial mount unintentionally** — `useEffect(() => track(...), [selectedId])` fires when `selectedId` is set to its initial value too.
3. **Risks infinite loops** when the effect itself modifies state in the dep array.
4. **Decouples cause from effect** — six months later, no one remembers which click is firing the tracking.

**Incorrect — effect chained off a state change:**

```tsx
function Tabs() {
  const [tab, setTab] = useState<TabId>('overview');

  // Fires on every tab change AND on first mount.
  useEffect(() => {
    analytics.track('tab_view', { tab });
  }, [tab]);

  return (
    <>
      <button onClick={() => setTab('overview')}>Overview</button>
      <button onClick={() => setTab('reports')}>Reports</button>
    </>
  );
}
```

The first render fires `analytics.track('tab_view', { tab: 'overview' })` — usually unwanted. Adding a guard (`if (isFirstRender) return;`) is the smell.

**Correct — track inside the click handler:**

```tsx
function Tabs() {
  const [tab, setTab] = useState<TabId>('overview');

  const onTabClick = (next: TabId) => {
    analytics.track('tab_view', { tab: next });   // fires only on user action
    setTab(next);
  };

  return (
    <>
      <button onClick={() => onTabClick('overview')}>Overview</button>
      <button onClick={() => onTabClick('reports')}>Reports</button>
    </>
  );
}
```

The tracking runs only when the user clicks — never on mount, never on unrelated re-renders.

## What `useEffect` is actually for

`useEffect` is for syncing React with an **external system** that isn't aware of your render cycle:

| Right `useEffect` use | Why |
|---|---|
| Attach/detach a DOM event listener | External system: the browser |
| Subscribe to a WebSocket or store | External system: the network / store |
| Set `document.title` | External system: the document |
| Start/stop a `setInterval` | External system: the platform timer |
| Sync an imperative library (chart, map) with React state | External system: the library |

Notice the pattern: each one has a cleanup function. If you're writing a `useEffect` without a `return () => ...`, ask whether an event handler would be more honest.

## When NOT to apply

- **The trigger is state changing for non-user reasons** — e.g., a query resolves and you want to focus an input. That's a legitimate `useEffect`: the trigger isn't a click.
- **Multiple unrelated callers can cause the same state change** — if state can mutate from 5 different paths and you need to react once, an effect centralizes the response. But consider whether the state itself should be replaced with explicit actions instead.

## Related

- [`derived-state-no-effect`](./derived-state-no-effect.md) — sibling rule for read-only derived values.
- [`narrow-effect-deps`](./narrow-effect-deps.md) — when you do need an effect, keep deps minimal to avoid spurious fires.
