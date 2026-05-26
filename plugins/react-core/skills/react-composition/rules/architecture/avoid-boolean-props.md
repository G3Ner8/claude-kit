---
title: Avoid Boolean Prop Proliferation
impact: CRITICAL
impactDescription: prevents the exponential state space and conditional maze that bloated boolean APIs create
tags: composition, props, architecture, api-design
---

## Avoid Boolean Prop Proliferation

A component with `n` boolean props has `2^n` reachable states. Every new boolean — `isThread`, `isEditing`, `isPreview`, `isSticky`, `isCompact` — doubles the implementation's branching and the call sites a reader must hold in their head. Most of those `2^n` combinations are nonsense (`isEditing && isPreview && !isThread` may not even be valid), but the component still has to handle them.

The fix is one of three patterns, in order of preference:

1. **Lift to variants** — make distinct modes their own components (`<ThreadComposer />` vs `<EditComposer />`). See [`explicit-variants`](../patterns/explicit-variants.md).
2. **Lift to a discriminated union** — replace 3+ interacting booleans with a single `mode: 'thread' | 'edit' | 'preview'` prop.
3. **Lift to composition** — let the consumer compose primitives (`<Composer><Composer.Header /><Composer.Footer /></Composer>`). See [`compound-components`](./compound-components.md).

Single orthogonal boolean props are fine when the binary state truly doesn't interact with anything else (`disabled`, `required`, `autoFocus`, `open`). The pattern bites when booleans **combine to imply a mode**.

**Incorrect — five booleans that interact:**

```tsx
// 2^5 = 32 reachable states, of which only ~6 are meaningful.
<Composer
  isThread
  isEditing
  isPreview
  isSticky
  isCompact
/>;

function Composer({
  isThread,
  isEditing,
  isPreview,
  isSticky,
  isCompact,
}: ComposerProps) {
  // Branching explodes — and the linter can't tell you which combos are bugs.
  const showHeader = !isCompact && (isThread || isEditing);
  const showFooter = !isPreview && !isCompact;
  const className = [
    isSticky && 'sticky',
    isCompact && 'compact',
    isPreview && 'preview',
    isEditing && 'editing',
  ].filter(Boolean).join(' ');

  // ... 40 more lines that the reader has to hold in their head
}
```

**Correct — discriminated union for the mode dimension, isolated boolean for the orthogonal one:**

```tsx
type ComposerMode = 'thread' | 'edit' | 'preview';

function Composer({ mode, sticky = false }: { mode: ComposerMode; sticky?: boolean }) {
  // Each mode renders deliberately — no implicit cross-talk.
  if (mode === 'preview') return <ComposerPreview sticky={sticky} />;
  if (mode === 'edit')    return <ComposerEdit sticky={sticky} />;
  return <ComposerThread sticky={sticky} />;
}

// The layout dimension (compact) becomes its own wrapper because it
// changes structure, not just style.
function CompactComposer({ mode }: { mode: ComposerMode }) {
  return (
    <div className="compact">
      <Composer mode={mode} />
    </div>
  );
}
```

`sticky` stays a boolean — it's a one-axis visual flag that does not interact with `mode`. That's the right shape for an isolated binary.

## The smell test

You have a boolean problem when:

- Two booleans appear together in the same `if` branch (`isEditing && !isPreview`)
- You add an exhaustiveness `assertNever()` because TS can't narrow flag combinations
- The component README has a table listing "valid combinations"
- A new variant requires touching 6 conditionals across the file

You don't have a boolean problem when:

- The booleans mirror native HTML attributes (`required`, `readOnly`, `disabled`)
- Each boolean only appears once in the implementation, in its own branch
- The component is internal-only and small enough that 2-3 booleans don't compound

## When NOT to apply

- **A single orthogonal boolean is fine** — don't refactor `<Button disabled>` into a union.
- **HTML primitives mirror native attributes** — keep `<Input required readOnly>` matching `<input>`'s API.
- **Loading/disabled/open** — these are conventions Radix, Headless UI, and the W3C ARIA APG all use. Don't invent a `state: 'loading' | 'idle'` union just to avoid `isLoading`.

The trigger is **booleans combining to imply a mode**. When you find yourself writing `if (isA && !isB)` to decide rendering, that's when to introduce a `mode` prop or split the component.
