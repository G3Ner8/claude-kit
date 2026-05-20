---
title: Prefer Children Over Render Props
impact: MEDIUM
impactDescription: cleaner composition, better readability
tags: composition, children, render-props
---

## Prefer Children Over Render Props

Use `children` for composition instead of `renderHeader` / `renderFooter` / `renderActions` props. Children compose naturally, don't require understanding callback signatures, and let consumers nest arbitrary structure.

**Incorrect (render props):**

```tsx
function Composer({
  renderHeader,
  renderFooter,
  renderActions,
}: {
  renderHeader?: () => React.ReactNode
  renderFooter?: () => React.ReactNode
  renderActions?: () => React.ReactNode
}) {
  return (
    <form>
      {renderHeader?.()}
      <input type="text" />
      {renderFooter ? renderFooter() : <DefaultFooter />}
      {renderActions?.()}
    </form>
  )
}

// Usage — every slot is a callback
return (
  <Composer
    renderHeader={() => <CustomHeader />}
    renderFooter={() => (
      <>
        <Formatting />
        <Emojis />
      </>
    )}
    renderActions={() => <SubmitButton />}
  />
)
```

Three problems:

1. Every slot is a function — readers have to scan signatures
2. Slots are *defined by the parent* (`renderHeader`, `renderFooter`) — adding a new slot means changing the parent's API
3. Conditional fallback (`renderFooter ? renderFooter() : <DefaultFooter />`) is awkward

**Correct (compound components with children):**

```tsx
function ComposerFrame({ children }: { children: React.ReactNode }) {
  return <form>{children}</form>
}

function ComposerFooter({ children }: { children: React.ReactNode }) {
  return <footer className="flex gap-2">{children}</footer>
}

// Usage — direct JSX, no callbacks
return (
  <Composer.Frame>
    <CustomHeader />
    <Composer.Input />
    <Composer.Footer>
      <Composer.Formatting />
      <Composer.Emojis />
      <SubmitButton />
    </Composer.Footer>
  </Composer.Frame>
)
```

The consumer writes JSX exactly as it renders. Adding a new variant means writing a new variant component (see [Explicit Variants](./explicit-variants.md)), not adding a new `renderX` prop.

### When render props ARE the right answer

Render props (and the related "render callback") are appropriate when the parent must **pass data back** to the child:

```tsx
// Render prop because the row data is created by the list, not the consumer
<List
  data={items}
  renderItem={({ item, index }) => <Item item={item} index={index} />}
/>

// Or in modern form, use children-as-function:
<List data={items}>
  {({ item, index }) => <Item item={item} index={index} />}
</List>
```

Use render props when the parent **owns data** the child needs to render. Use plain children when composing static structure.
