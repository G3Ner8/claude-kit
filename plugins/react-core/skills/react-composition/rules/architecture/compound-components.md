---
title: Use Compound Components
impact: HIGH
impactDescription: enables flexible composition without prop drilling
tags: composition, compound-components, context, architecture
---

## Use Compound Components

Structure complex components as a **compound component**: a small set of subcomponents that share state via context. Consumers compose the pieces they need; no prop drilling, no render-prop callbacks, no monolithic parent component knowing about every variant.

This is the pattern behind Radix UI, shadcn/ui, Reach UI, and Ariakit.

**Incorrect (monolithic component with render props):**

```tsx
function Composer({
  renderHeader,
  renderFooter,
  renderActions,
  showAttachments,
  showFormatting,
  showEmojis,
}: Props) {
  return (
    <form>
      {renderHeader?.()}
      <input type="text" />
      {showAttachments && <Attachments />}
      {renderFooter ? (
        renderFooter()
      ) : (
        <Footer>
          {showFormatting && <Formatting />}
          {showEmojis && <Emojis />}
          {renderActions?.()}
        </Footer>
      )}
    </form>
  )
}
```

The parent knows about every possible piece (`showAttachments`, `renderFooter`, etc.). Adding a new variant means adding a new prop.

**Correct (compound components with shared context):**

```tsx
import { createContext, use, useRef, type ReactNode, type RefObject } from 'react'

interface ComposerContextValue {
  state: { input: string }
  actions: { update: (text: string) => void; submit: () => void }
  meta: { inputRef: RefObject<HTMLInputElement | null> }
}

const ComposerContext = createContext<ComposerContextValue | null>(null)

function ComposerProvider({
  children,
  state,
  actions,
  meta,
}: { children: ReactNode } & ComposerContextValue) {
  return (
    <ComposerContext value={{ state, actions, meta }}>
      {children}
    </ComposerContext>
  )
}

function ComposerFrame({ children }: { children: ReactNode }) {
  return <form>{children}</form>
}

function ComposerInput() {
  const ctx = use(ComposerContext)
  if (!ctx) throw new Error('ComposerInput must be inside ComposerProvider')
  return (
    <input
      ref={ctx.meta.inputRef}
      type="text"
      value={ctx.state.input}
      onChange={(e) => ctx.actions.update(e.target.value)}
    />
  )
}

function ComposerSubmit() {
  const ctx = use(ComposerContext)
  if (!ctx) throw new Error('ComposerSubmit must be inside ComposerProvider')
  return (
    <button type="button" onClick={ctx.actions.submit}>
      Send
    </button>
  )
}

// Export as a compound component
export const Composer = {
  Provider: ComposerProvider,
  Frame: ComposerFrame,
  Input: ComposerInput,
  Submit: ComposerSubmit,
  // Header, Footer, Attachments, Formatting, Emojis defined the same way…
}
```

**Usage:**

```tsx
<Composer.Provider state={state} actions={actions} meta={meta}>
  <Composer.Frame>
    <Composer.Header />
    <Composer.Input />
    <Composer.Footer>
      <Composer.Formatting />
      <Composer.Submit />
    </Composer.Footer>
  </Composer.Frame>
</Composer.Provider>
```

Consumers explicitly compose what they need. The state, actions, and meta are dependency-injected by the provider — see [Lift State into Provider Components](../state/lift-state.md) and [Define Generic Context Interfaces](../state/context-interface.md).

### Note on the context type

The `throw new Error(...)` guard in `use(ComposerContext)` consumers is what lets you type the context as `ComposerContextValue | null` while still using non-null `ctx.state` downstream. Alternatives: assert non-null at the call site, or create a custom `useComposer()` hook that throws.
