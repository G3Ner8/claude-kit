---
title: Define Generic Context Interfaces for Dependency Injection
impact: HIGH
impactDescription: enables swapping state implementations without touching UI
tags: composition, context, state, typescript, dependency-injection
---

## Define Generic Context Interfaces for Dependency Injection

Give your component's context a **generic interface** with three parts: `state`, `actions`, and `meta`. The interface is the contract; *any* provider can implement it. The UI consumes the contract, not the implementation. This lets you swap state sources (local `useState`, Zustand store, server-synced cache) without changing a single UI component.

**Core principle:** Lift state, compose internals, make state dependency-injectable.

**Incorrect (UI coupled to a specific state source):**

```tsx
function ComposerInput() {
  // Tightly coupled to a specific hook
  const { input, setInput } = useChannelComposerState()
  return (
    <input type="text" value={input} onChange={(e) => setInput(e.target.value)} />
  )
}
```

Now `ComposerInput` only works with channel state. To use it in a forward-message dialog, you'd duplicate the component or thread a different hook through props.

**Correct (generic interface enables dependency injection):**

```tsx
import { createContext, use, type RefObject } from 'react'

// Define a GENERIC interface that any provider can implement
interface ComposerState {
  input: string
  attachments: Attachment[]
  isSubmitting: boolean
}

interface ComposerActions {
  update: (updater: (state: ComposerState) => ComposerState) => void
  submit: () => void
}

interface ComposerMeta {
  inputRef: RefObject<HTMLInputElement | null>
}

interface ComposerContextValue {
  state: ComposerState
  actions: ComposerActions
  meta: ComposerMeta
}

export const ComposerContext = createContext<ComposerContextValue | null>(null)
```

**UI components consume the interface, not the implementation:**

```tsx
function ComposerInput() {
  const ctx = use(ComposerContext)
  if (!ctx) throw new Error('ComposerInput must be inside a Composer.Provider')

  // This component works with ANY provider that implements the interface
  return (
    <input
      ref={ctx.meta.inputRef}
      type="text"
      value={ctx.state.input}
      onChange={(e) =>
        ctx.actions.update((s) => ({ ...s, input: e.target.value }))
      }
    />
  )
}
```

**Different providers, same UI:**

```tsx
// Provider A: local state for ephemeral forms
function ForwardMessageProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState(initialState)
  const inputRef = useRef<HTMLInputElement | null>(null)
  const submit = useForwardMessage()

  return (
    <ComposerContext
      value={{ state, actions: { update: setState, submit }, meta: { inputRef } }}
    >
      {children}
    </ComposerContext>
  )
}

// Provider B: global synced state for channels
function ChannelProvider({ channelId, children }: ChannelProps) {
  const { state, update, submit } = useGlobalChannel(channelId)
  const inputRef = useRef<HTMLInputElement | null>(null)

  return (
    <ComposerContext
      value={{ state, actions: { update, submit }, meta: { inputRef } }}
    >
      {children}
    </ComposerContext>
  )
}
```

**The same composed UI works with both:**

```tsx
// Local state
<ForwardMessageProvider>
  <Composer.Frame>
    <Composer.Input />
    <Composer.Submit />
  </Composer.Frame>
</ForwardMessageProvider>

// Global synced state
<ChannelProvider channelId="abc">
  <Composer.Frame>
    <Composer.Input />
    <Composer.Submit />
  </Composer.Frame>
</ChannelProvider>
```

### Custom UI outside the component can still access state

The provider boundary is what matters, not the visual nesting:

```tsx
function ForwardMessageDialog() {
  return (
    <ForwardMessageProvider>
      <Dialog>
        <Composer.Frame>
          <Composer.Input placeholder="Add a message, if you'd like." />
          <Composer.Footer>
            <Composer.Formatting />
            <Composer.Emojis />
          </Composer.Footer>
        </Composer.Frame>

        {/* Outside the composer frame, still inside the provider */}
        <MessagePreview />

        <DialogActions>
          <CancelButton />
          <ForwardButton />
        </DialogActions>
      </Dialog>
    </ForwardMessageProvider>
  )
}

// Outside <Composer.Frame> but still reads composer state
function ForwardButton() {
  const ctx = use(ComposerContext)
  return <button type="button" onClick={ctx?.actions.submit}>Forward</button>
}

function MessagePreview() {
  const ctx = use(ComposerContext)
  return <Preview message={ctx?.state.input ?? ''} attachments={ctx?.state.attachments ?? []} />
}
```

The UI is reusable parts you compose. State is injected by the provider. **Swap the provider, keep the UI.**
