---
title: Compound Components
impact: HIGH
impactDescription: lets consumers compose primitives instead of configuring monoliths through dozens of props
tags: composition, architecture, context, compound, api-design
---

## Compound Components

A **compound component** is a parent that exposes its subcomponents as named static properties (`Dialog.Trigger`, `Dialog.Content`, `Dialog.Title`) and shares state with them through context. Consumers compose the parts they need; the parent owns coordination.

This is the API that Radix UI, Headless UI, Reach UI, Ark UI, and shadcn/ui all converge on. The reason: it scales linearly. Adding `<Dialog.Description>` to the library doesn't require touching every other subcomponent or props bag.

The alternative — a single component with `header`, `footer`, `showClose`, `closeLabel`, `description`, `descriptionPosition`, `actions` props — degrades into [boolean-prop bloat](./avoid-boolean-props.md) within a few releases.

**Incorrect — monolithic config object:**

```tsx
<Dialog
  title="Delete employee"
  description="This will permanently remove the record."
  showClose
  closeLabel="Cancel"
  showFooter
  footerActions={[
    { label: 'Cancel', variant: 'ghost', onClick: onCancel },
    { label: 'Delete', variant: 'destructive', onClick: onConfirm },
  ]}
  size="md"
  preventOutsideClose={false}
/>;
```

To add a new feature (custom icon next to title), you grow the prop surface again. Custom layouts are impossible without a new prop.

**Correct — compound API with context-shared state:**

```tsx
import { createContext, use, useId, useState, type ReactNode } from 'react';

interface DialogContextValue {
  open: boolean;
  setOpen: (open: boolean) => void;
  titleId: string;
}

const DialogContext = createContext<DialogContextValue | null>(null);

function useDialog() {
  const ctx = use(DialogContext);
  if (!ctx) throw new Error('Dialog.* must be rendered inside <Dialog>');
  return ctx;
}

function Dialog({ children, defaultOpen = false }: { children: ReactNode; defaultOpen?: boolean }) {
  const [open, setOpen] = useState(defaultOpen);
  const titleId = useId();
  return (
    <DialogContext value={{ open, setOpen, titleId }}>
      {children}
    </DialogContext>
  );
}

function DialogTrigger({ children }: { children: ReactNode }) {
  const { setOpen } = useDialog();
  return <button onClick={() => setOpen(true)}>{children}</button>;
}

function DialogContent({ children }: { children: ReactNode }) {
  const { open, titleId } = useDialog();
  if (!open) return null;
  return (
    <div role="dialog" aria-labelledby={titleId} aria-modal="true">
      {children}
    </div>
  );
}

function DialogTitle({ children }: { children: ReactNode }) {
  const { titleId } = useDialog();
  return <h2 id={titleId}>{children}</h2>;
}

function DialogClose({ children }: { children: ReactNode }) {
  const { setOpen } = useDialog();
  return <button onClick={() => setOpen(false)}>{children}</button>;
}

Dialog.Trigger = DialogTrigger;
Dialog.Content = DialogContent;
Dialog.Title = DialogTitle;
Dialog.Close = DialogClose;
```

Consumer code:

```tsx
<Dialog>
  <Dialog.Trigger>Delete</Dialog.Trigger>
  <Dialog.Content>
    <Dialog.Title>Delete employee</Dialog.Title>
    <p>This will permanently remove the record.</p>
    <Dialog.Close>Cancel</Dialog.Close>
    <button onClick={onConfirm}>Delete</button>
  </Dialog.Content>
</Dialog>
```

Adding a new piece (e.g., `Dialog.Description` that auto-wires `aria-describedby`) is purely additive — no existing usage breaks, no existing prop changes meaning.

## Key conventions

- **Use `createContext(null)` + a throwing `useX()` hook.** Throwing surfaces "rendered outside parent" as a clear error instead of a silent default.
- **Generate IDs with `useId`** for ARIA wiring (`aria-labelledby`, `aria-describedby`) — never hand-write IDs.
- **Subcomponents are named static properties** (`Dialog.Trigger`) — not separate named exports — so the relationship is obvious at the import.
- **React 19**: read context with `use(Context)`, not `useContext(Context)`. `use()` works in conditional branches; `useContext` doesn't. See [`no-forwardref`](../react19/no-forwardref.md).

## When NOT to apply

- **Single-use internal components** — `<EmptyState />` doesn't need to be compound; just take a `title` and `description` prop.
- **Components where the layout never varies** — a `<Badge>` is always icon-then-label; no value in `<Badge.Icon>` + `<Badge.Label>`.
- **Performance-sensitive lists** — context-sharing across hundreds of compound instances can re-render more than necessary. Profile first; if you measure a problem, hoist the shared state out and pass via props.

The compound pattern earns its complexity when:

1. The component has 3+ optional structural parts (header, footer, description, close, etc.)
2. Different consumers compose them in different orders or omit some entirely
3. The parts need to share state (open/close, selection, current step) or ARIA wiring
