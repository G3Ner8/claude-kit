---
title: Avoid Boolean Prop Proliferation
impact: CRITICAL
impactDescription: prevents exponential state space and unmaintainable conditionals
tags: composition, props, architecture
---

## Avoid Boolean Prop Proliferation

Don't add boolean props like `isThread`, `isEditing`, `isDMThread` to customize component behavior. Each boolean doubles the possible states and creates unmaintainable conditional logic. Use composition instead.

**Incorrect (boolean props create exponential complexity):**

```tsx
function Composer({
  onSubmit,
  isThread,
  channelId,
  isDMThread,
  dmId,
  isEditing,
  isForwarding,
}: Props) {
  return (
    <form onSubmit={onSubmit}>
      <Header />
      <input type="text" />
      {isDMThread ? (
        <AlsoSendToDMField id={dmId} />
      ) : isThread ? (
        <AlsoSendToChannelField id={channelId} />
      ) : null}
      {isEditing ? (
        <EditActions />
      ) : isForwarding ? (
        <ForwardActions />
      ) : (
        <DefaultActions />
      )}
      <Footer />
    </form>
  )
}
```

With 4 booleans you have 16 combinations — most are nonsensical (`isEditing && isForwarding`?) and the call site can produce any of them.

**Correct (composition eliminates conditionals):**

```tsx
// Channel composer
function ChannelComposer() {
  return (
    <Composer.Frame>
      <Composer.Header />
      <Composer.Input />
      <Composer.Footer>
        <Composer.Attachments />
        <Composer.Formatting />
        <Composer.Emojis />
        <Composer.Submit />
      </Composer.Footer>
    </Composer.Frame>
  )
}

// Thread composer — adds "also send to channel" field
function ThreadComposer({ channelId }: { channelId: string }) {
  return (
    <Composer.Frame>
      <Composer.Header />
      <Composer.Input />
      <AlsoSendToChannelField id={channelId} />
      <Composer.Footer>
        <Composer.Formatting />
        <Composer.Emojis />
        <Composer.Submit />
      </Composer.Footer>
    </Composer.Frame>
  )
}

// Edit composer — different footer actions
function EditComposer() {
  return (
    <Composer.Frame>
      <Composer.Input />
      <Composer.Footer>
        <Composer.Formatting />
        <Composer.Emojis />
        <Composer.CancelEdit />
        <Composer.SaveEdit />
      </Composer.Footer>
    </Composer.Frame>
  )
}
```

Each variant is explicit about what it renders. Subcomponents (`Composer.Input`, `Composer.Footer`) share state via context — see [Use Compound Components](./compound-components.md).

### When a boolean prop IS okay

A boolean is fine when it represents a **single, true binary** that doesn't combine with other booleans:

```tsx
<button disabled>Submit</button>   // disabled has one universal meaning
<input required />                  // ditto
<dialog open={isOpen}>...</dialog>  // open/closed is genuinely binary
```

The smell is **stacks of booleans** describing *what variant* of a component you want. That's a variant, not a flag.
