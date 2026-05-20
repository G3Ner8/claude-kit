---
title: React 19 — `ref` as Prop, `use()` over `useContext()`
impact: MEDIUM
impactDescription: simpler component signatures and context consumption
tags: react19, refs, context, hooks
---

## React 19 — `ref` as Prop, `use()` over `useContext()`

> **⚠️ React 19+ only.** Skip this rule if you're on React 18 or earlier.

Two API changes in React 19 make composition code shorter:

1. **`ref` is now a regular prop.** `forwardRef` is no longer needed and is deprecated.
2. **`use(Context)` replaces `useContext(Context)`** and can be called conditionally (inside `if`, after early return, etc.).

### `forwardRef` → ref-as-prop

**Incorrect (forwardRef in React 19):**

```tsx
import { forwardRef } from 'react'

type ComposerInputProps = { placeholder?: string }

const ComposerInput = forwardRef<HTMLInputElement, ComposerInputProps>(
  (props, ref) => {
    return <input ref={ref} type="text" {...props} />
  }
)
```

**Correct (`ref` as a regular prop):**

```tsx
type ComposerInputProps = {
  placeholder?: string
  ref?: React.Ref<HTMLInputElement>
}

function ComposerInput({ ref, ...props }: ComposerInputProps) {
  return <input ref={ref} type="text" {...props} />
}
```

No `forwardRef`, no `displayName`, no generic awkwardness. Consumers use it the same way:

```tsx
const inputRef = useRef<HTMLInputElement | null>(null)
<ComposerInput ref={inputRef} placeholder="Type here…" />
```

### `useContext` → `use`

**Incorrect (useContext in React 19):**

```tsx
import { useContext } from 'react'

function ComposerSubmit() {
  const ctx = useContext(ComposerContext)
  if (!ctx) return null
  return <button type="button" onClick={ctx.actions.submit}>Send</button>
}
```

**Correct (`use` instead):**

```tsx
import { use } from 'react'

function ComposerSubmit() {
  const ctx = use(ComposerContext)
  if (!ctx) return null
  return <button type="button" onClick={ctx.actions.submit}>Send</button>
}
```

The runtime behavior is the same. The advantage of `use()` is that it can be called **conditionally** — inside an `if`, after an early `return`, inside a loop. `useContext()` couldn't be, because hooks rules forbid it.

```tsx
// Legal in React 19 with use()
function ComposerInput({ disabled }: { disabled?: boolean }) {
  if (disabled) return <input type="text" disabled />

  // use() called only on the non-disabled path — fine
  const ctx = use(ComposerContext)
  if (!ctx) return null

  return (
    <input
      type="text"
      value={ctx.state.input}
      onChange={(e) => ctx.actions.update((s) => ({ ...s, input: e.target.value }))}
    />
  )
}
```

### Bonus: `<Context value={...}>` short form

React 19 also lets you skip `.Provider`:

```tsx
// React 18
<ComposerContext.Provider value={contextValue}>

// React 19
<ComposerContext value={contextValue}>
```

Both still work in React 19; the short form is preferred for new code.

Reference: [React 19 — `ref` as a prop](https://react.dev/blog/2024/12/05/react-19#ref-as-a-prop), [`use`](https://react.dev/reference/react/use)
