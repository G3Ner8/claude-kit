---
title: Lift State into Provider Components
impact: HIGH
impactDescription: enables state sharing outside the visual component tree
tags: composition, state, context, providers
---

## Lift State into Provider Components

Move state management into a dedicated **provider component**. This lets sibling components — including ones outside the main UI tree — read and modify the same state without prop drilling, callbacks, or refs.

The provider boundary is what matters, not visual nesting. If two components need the same state, they don't need to be inside the same parent — they just need to be inside the same provider.

**Incorrect (state trapped inside the component):**

```tsx
function ForwardMessageComposer() {
  const [state, setState] = useState(initialState)
  const forwardMessage = useForwardMessage()

  return (
    <Composer.Frame>
      <Composer.Input />
      <Composer.Footer />
    </Composer.Frame>
  )
}

// Problem: how does this button access the composer's state?
function ForwardMessageDialog() {
  return (
    <Dialog>
      <ForwardMessageComposer />
      <MessagePreview /> {/* needs the composer's current input */}
      <DialogActions>
        <CancelButton />
        <ForwardButton /> {/* needs to call submit() */}
      </DialogActions>
    </Dialog>
  )
}
```

**Incorrect (useEffect to sync state up):**

```tsx
function ForwardMessageDialog() {
  const [input, setInput] = useState('')
  return (
    <Dialog>
      <ForwardMessageComposer onInputChange={setInput} />
      <MessagePreview input={input} />
    </Dialog>
  )
}

function ForwardMessageComposer({ onInputChange }: { onInputChange: (v: string) => void }) {
  const [state, setState] = useState(initialState)
  useEffect(() => {
    onInputChange(state.input) // sync on every change — fragile, double-renders
  }, [state.input])
  // ...
}
```

**Incorrect (reading state from a ref on submit):**

```tsx
function ForwardMessageDialog() {
  const stateRef = useRef<ComposerState | null>(null)
  return (
    <Dialog>
      <ForwardMessageComposer stateRef={stateRef} />
      <ForwardButton onClick={() => submit(stateRef.current)} />
    </Dialog>
  )
}
```

This breaks reactivity — `<MessagePreview>` can't re-render when the input changes because it's reading from a ref.

**Correct (state lifted to a provider):**

```tsx
function ForwardMessageProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState(initialState)
  const forwardMessage = useForwardMessage()
  const inputRef = useRef<HTMLInputElement | null>(null)

  return (
    <Composer.Provider
      state={state}
      actions={{ update: setState, submit: forwardMessage }}
      meta={{ inputRef }}
    >
      {children}
    </Composer.Provider>
  )
}

function ForwardMessageDialog() {
  return (
    <ForwardMessageProvider>
      <Dialog>
        <ForwardMessageComposer />
        <MessagePreview /> {/* now reads from context */}
        <DialogActions>
          <CancelButton />
          <ForwardButton />  {/* now reads submit() from context */}
        </DialogActions>
      </Dialog>
    </ForwardMessageProvider>
  )
}

function ForwardButton() {
  const ctx = use(Composer.Context)
  return <button type="button" onClick={ctx?.actions.submit}>Forward</button>
}

function MessagePreview() {
  const ctx = use(Composer.Context)
  return <Preview value={ctx?.state.input ?? ''} />
}
```

`ForwardButton` and `MessagePreview` live **outside** `<Composer.Frame>` but still access the composer's state — because they're inside the same provider. The visual tree and the data tree are independent.

**Key insight:** components that share state don't have to be visually nested. They just need to share a provider.
