---
title: Create Explicit Component Variants
impact: MEDIUM
impactDescription: self-documenting code, no impossible state combinations
tags: composition, variants, architecture
---

## Create Explicit Component Variants

Instead of one component with many boolean props, create **explicit variant components**. Each variant composes the pieces it needs. The code documents itself: you can see at a glance what each variant does.

This is the natural follow-on to [Avoid Boolean Props](../architecture/avoid-boolean-props.md) — the boolean props get replaced by named variant components.

**Incorrect (one component, many modes):**

```tsx
// What does this actually render? You have to read the implementation to know.
<Composer
  isThread
  isEditing={false}
  channelId="abc"
  showAttachments
  showFormatting={false}
/>
```

You can also produce nonsense combinations: `<Composer isThread isEditing isForwarding />` compiles fine but means nothing.

**Correct (explicit variants):**

```tsx
// Immediately clear what this is
<ThreadComposer channelId="abc" />

<EditMessageComposer messageId="xyz" />

<ForwardMessageComposer messageId="123" />
```

Each variant is self-contained and impossible to misuse.

### Implementation

Each variant wires its own provider and composes the shared subcomponents:

```tsx
function ThreadComposer({ channelId }: { channelId: string }) {
  return (
    <ThreadProvider channelId={channelId}>
      <Composer.Frame>
        <Composer.Input />
        <AlsoSendToChannelField channelId={channelId} />
        <Composer.Footer>
          <Composer.Formatting />
          <Composer.Emojis />
          <Composer.Submit />
        </Composer.Footer>
      </Composer.Frame>
    </ThreadProvider>
  )
}

function EditMessageComposer({ messageId }: { messageId: string }) {
  return (
    <EditMessageProvider messageId={messageId}>
      <Composer.Frame>
        <Composer.Input />
        <Composer.Footer>
          <Composer.Formatting />
          <Composer.Emojis />
          <Composer.CancelEdit />
          <Composer.SaveEdit />
        </Composer.Footer>
      </Composer.Frame>
    </EditMessageProvider>
  )
}

function ForwardMessageComposer({ messageId }: { messageId: string }) {
  return (
    <ForwardMessageProvider messageId={messageId}>
      <Composer.Frame>
        <Composer.Input placeholder="Add a message, if you'd like." />
        <Composer.Footer>
          <Composer.Formatting />
          <Composer.Emojis />
          <Composer.Mentions />
        </Composer.Footer>
      </Composer.Frame>
    </ForwardMessageProvider>
  )
}
```

Each variant is explicit about:

- Which provider/state implementation it uses
- Which UI elements it includes
- Which actions are available

No boolean prop combinations to reason about. No impossible states. The diff for "add a new composer variant" is a new component, not a modified API.

### When this is overkill

For a component with **one** binary variation (e.g., `<Button size="sm" | "md">`), a variant prop is fine. The smell is when:

1. Multiple booleans stack (`isThread && isEditing`)
2. Different "modes" actually render different sets of subcomponents (not just different styles)
3. The component has props that only make sense in one mode (`channelId` only used when `isThread`)

Any of these → split into named variant components.
