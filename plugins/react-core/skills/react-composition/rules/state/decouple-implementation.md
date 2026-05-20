---
title: Decouple State Management from UI
impact: MEDIUM
impactDescription: enables swapping state implementations without changing UI
tags: composition, state, architecture
---

## Decouple State Management from UI

The **provider** is the only place that knows *how* state is managed. UI components consume the context interface — they don't know if state comes from `useState`, Zustand, a server-synced cache, or a backend WebSocket.

This is the practical payoff of [Define Generic Context Interfaces](./context-interface.md): the same `<Composer.Input />` works in a dialog backed by local state and in a channel backed by server sync.

**Incorrect (UI knows about the state implementation):**

```tsx
function ChannelComposer({ channelId }: { channelId: string }) {
  // The UI component imports a specific state hook
  const state = useGlobalChannelState(channelId)
  const sync = useChannelSync(channelId)

  return (
    <Composer.Frame>
      <Composer.Input
        value={state.input}
        onChange={(e) => sync.updateInput(e.target.value)}
      />
      <Composer.Submit onClick={() => sync.submit()} />
    </Composer.Frame>
  )
}
```

Now `ChannelComposer` can never be reused in a context that uses local state instead of global sync. It's not a UI component — it's a UI + state implementation glued together.

**Correct (state isolated in the provider):**

```tsx
// Provider handles all state-management details
function ChannelProvider({
  channelId,
  children,
}: {
  channelId: string
  children: React.ReactNode
}) {
  const { state, update, submit } = useGlobalChannel(channelId)
  const inputRef = useRef<HTMLInputElement | null>(null)

  return (
    <Composer.Provider
      state={state}
      actions={{ update, submit }}
      meta={{ inputRef }}
    >
      {children}
    </Composer.Provider>
  )
}

// UI component only knows about the context interface
function ChannelComposer() {
  return (
    <Composer.Frame>
      <Composer.Header />
      <Composer.Input />
      <Composer.Footer>
        <Composer.Submit />
      </Composer.Footer>
    </Composer.Frame>
  )
}

// Usage
function Channel({ channelId }: { channelId: string }) {
  return (
    <ChannelProvider channelId={channelId}>
      <ChannelComposer />
    </ChannelProvider>
  )
}
```

**Different providers, same UI:**

```tsx
// Local state for ephemeral forms
function ForwardMessageProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState(initialState)
  const forwardMessage = useForwardMessage()

  return (
    <Composer.Provider
      state={state}
      actions={{ update: setState, submit: forwardMessage }}
    >
      {children}
    </Composer.Provider>
  )
}

// Global synced state for channels
function ChannelProvider({ channelId, children }: ChannelProps) {
  const { state, update, submit } = useGlobalChannel(channelId)

  return (
    <Composer.Provider state={state} actions={{ update, submit }}>
      {children}
    </Composer.Provider>
  )
}
```

The same `<Composer.Input />` works in both because it only depends on the **context interface**, not the implementation.

### Test boundary

The decoupling makes testing trivial: render the UI with a `<MockComposerProvider>` that hands it whatever `{ state, actions }` the test needs. No HTTP mocks, no store setup.
