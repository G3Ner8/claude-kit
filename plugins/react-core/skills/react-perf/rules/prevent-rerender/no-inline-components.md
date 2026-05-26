---
title: Never Define Components Inside Components
impact: CRITICAL
impactDescription: a nested component definition produces a fresh component type every render — React remounts the entire subtree, losing state and DOM and breaking memoization
tags: prevent-rerender, components, identity, remount, anti-pattern
---

## Never Define Components Inside Components

A component defined inside another component's body is **a different component type on every render**. React identifies components by reference equality on their function. Two functions created during two different renders look identical but are different references, so React assumes a different component type and:

1. **Unmounts the previous instance entirely** — destroying its state, its DOM nodes, and any effects.
2. **Mounts a fresh instance** — running effects from scratch, re-running every initialization.
3. **Re-fires the layout/paint cycle** — no DOM reuse, no smooth animations.
4. **Defeats `memo()`** — the wrapped component is never the same component twice.

This bug looks like "the form keeps resetting itself," "the input loses focus when typing," or "the animation restarts every interaction." All trace back to a component defined in a render body.

**Incorrect — `Item` defined inside `List`:**

```tsx
function List({ items }: { items: Item[] }) {
  // `Item` is a NEW function reference every time List renders.
  function Item({ item }: { item: Item }) {
    const [hovered, setHovered] = useState(false);
    return (
      <li onMouseEnter={() => setHovered(true)} onMouseLeave={() => setHovered(false)}>
        {item.name} {hovered ? '👈' : ''}
      </li>
    );
  }

  return <ul>{items.map((item) => <Item key={item.id} item={item} />)}</ul>;
}
```

Every render of `List` produces a new `Item` type → React unmounts all rows and remounts them. The `hovered` state resets on every render of the parent. Hovering becomes impossible.

**Correct — hoist to module scope:**

```tsx
function Item({ item }: { item: Item }) {
  const [hovered, setHovered] = useState(false);
  return (
    <li onMouseEnter={() => setHovered(true)} onMouseLeave={() => setHovered(false)}>
      {item.name} {hovered ? '👈' : ''}
    </li>
  );
}

function List({ items }: { items: Item[] }) {
  return <ul>{items.map((item) => <Item key={item.id} item={item} />)}</ul>;
}
```

`Item` is now a module-level function. Its reference is stable. React reuses each row's instance across `List` renders; state persists; hovers work.

## The "I need parent state" trap

The reason developers nest is usually "the child needs access to the parent's state/props." That's a misread of closure visibility. The fix is to pass it as a prop:

```tsx
function Item({ item, onSelect }: { item: Item; onSelect: (id: string) => void }) {
  return <li onClick={() => onSelect(item.id)}>{item.name}</li>;
}

function List({ items }: { items: Item[] }) {
  const [selected, setSelected] = useState<string | null>(null);
  return <ul>{items.map((it) => <Item key={it.id} item={it} onSelect={setSelected} />)}</ul>;
}
```

Hoisted `Item`, prop-passed callback. State persists.

## When NOT to apply (the exception is null)

There is no legitimate "OK if it's small" exception. The bug is structural — even a 2-line inline component breaks state in subtle ways. Always hoist.

The one case that looks similar but is fine: returning a **JSX expression** (not a component definition) inside another component:

```tsx
// This is fine: it's JSX, not a new component type.
function App() {
  const badge = <Badge variant="alert" />;
  return <div>{badge}</div>;
}
```

JSX values are not component definitions. Only `function Component(...)` declarations or function-as-component arrow expressions count as nested definitions.

## Verify

React DevTools Profiler → look for components remounting (highlighted purple) when they shouldn't. Trace up to the parent; check whether anything is defined inside it.

## Related

- [`memo-component`](./memo-component.md) — nested definitions defeat `memo()`.
- [`move-effect-to-event`](./move-effect-to-event.md) — nested defs are often added because someone wanted "this code to run only when X clicks." Move it to a handler instead.
