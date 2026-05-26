---
title: Hoist Non-Primitive Default Props
impact: LOW-MEDIUM
impactDescription: a non-primitive default prop creates a fresh object every render — defeats `memo()` and triggers child effects' dependency-change paths
tags: prevent-rerender, defaults, memo, references
---

## Hoist Non-Primitive Default Props

Default values written inline in destructuring are evaluated on every render:

```tsx
function List({ items = [] }: { items?: Item[] }) { ... }
```

If the caller doesn't pass `items`, React passes the inline `[]` — a **new array reference each render**. Downstream `useEffect([items])` re-fires every render; `memo()`'d children see fresh props and re-render.

The fix: hoist non-primitive defaults to module scope. Primitive defaults (numbers, strings, booleans) are fine inline — they're identity-stable.

**Incorrect — fresh array reference every render:**

```tsx
function List({ items = [] }: { items?: Item[] }) {
  useEffect(() => {
    console.log('items changed', items.length);  // fires every render when caller omits prop
  }, [items]);
  return <ul>{items.map(/* ... */)}</ul>;
}
```

When called as `<List />` (no items prop), each render passes a new `[]` — the effect re-runs constantly.

**Correct — module-level constant:**

```tsx
const EMPTY_ITEMS: Item[] = [];

function List({ items = EMPTY_ITEMS }: { items?: Item[] }) {
  useEffect(() => {
    console.log('items changed', items.length);
  }, [items]);
  return <ul>{items.map(/* ... */)}</ul>;
}
```

Same array reference every render. Effects only fire when the caller actually provides a different array.

## Same idea, more cases

| Default | Defeated by inline? | Fix |
|---|---|---|
| `string` | no — strings are interned | `name = 'Anonymous'` |
| `number` / `boolean` | no | `count = 0`, `open = false` |
| `[]` | yes | hoist as `const EMPTY_X = []` |
| `{}` | yes | hoist as `const EMPTY_X = {}` |
| `() => {}` | yes | hoist as `const NOOP = () => {}` |
| `() => specificThing` | yes | hoist or `useCallback` at caller |

## When NOT to apply

- **The default is genuinely a one-shot per-render value** — rare, usually a sign you don't want a default at all.
- **TypeScript's `Required` enforces presence** — if the type makes the prop required, you don't need a default.

## In React 19

The Compiler infers stability for many cases, including some default-prop scenarios. But it can't always prove safety, so the rule still applies as a hand-write convention: hoist non-primitive defaults.

## Related

- [`memo-component`](./memo-component.md) — `memo()` is defeated by fresh object/array/function refs in props.
- [`narrow-effect-deps`](./narrow-effect-deps.md) — when the dep changes constantly because of a non-primitive default, this is often the root cause.
