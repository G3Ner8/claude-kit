---
title: Explicit Variants over Boolean Modes
impact: MEDIUM
impactDescription: replaces flag-driven mode switches inside one component with separate, deliberately-named components that share a primitive
tags: composition, variants, components, architecture
---

## Explicit Variants over Boolean Modes

When a single component supports multiple "modes" — `<Composer isThread>`, `<Composer isEdit>`, `<Composer isPreview>` — every render path inside the component has to consider every mode. Each new mode multiplies the conditional surface, and each existing mode has to be re-verified against the others.

The fix is to split the modes into **distinct components** at the layer the variation lives, sharing a common primitive underneath. The implementation becomes linear instead of branched, the names tell the reader the intent, and each variant can have its own props without polluting the others.

This is the natural follow-on to [avoid-boolean-props](../architecture/avoid-boolean-props.md): the mode dimension collapses to a name, not a flag.

**Incorrect — one component, multiple modes:**

```tsx
function Composer({ mode, threadId, draftId, previewMessageId, onSend, onSaveDraft }: ComposerProps) {
  if (mode === 'thread' && !threadId) throw new Error('threadId required in thread mode');
  if (mode === 'edit'   && !draftId)  throw new Error('draftId required in edit mode');
  if (mode === 'preview' && !previewMessageId) throw new Error('previewMessageId required in preview mode');

  const { text, setText } = useDraft(mode === 'edit' ? draftId : null);
  const previewMessage    = useMessage(mode === 'preview' ? previewMessageId : null);

  return (
    <div className="composer">
      {mode === 'preview' ? (
        <PreviewBody message={previewMessage} />
      ) : (
        <Editor value={text} onChange={setText} />
      )}
      {mode === 'thread' && <ThreadHeader threadId={threadId!} />}
      {mode !== 'preview' && (
        <Toolbar onSend={onSend} onSaveDraft={onSaveDraft} mode={mode} />
      )}
    </div>
  );
}
```

Three modes share one render tree. Each mode requires reading the whole file to spot what applies. Props are optional-by-mode (`threadId?: string`) and verified at runtime instead of compile time — a real TypeScript hole.

**Correct — distinct variants over a shared primitive:**

```tsx
// Shared primitive: knows about layout (header slot + editor slot + toolbar slot),
// knows nothing about the mode.
function ComposerFrame({ header, children, toolbar }: {
  header?:  ReactNode;
  children: ReactNode;
  toolbar?: ReactNode;
}) {
  return (
    <div className="composer">
      {header}
      {children}
      {toolbar}
    </div>
  );
}

// Variant 1 — thread reply.
function ThreadComposer({ threadId, onSend }: { threadId: string; onSend: (text: string) => void }) {
  const [text, setText] = useState('');
  return (
    <ComposerFrame
      header={<ThreadHeader threadId={threadId} />}
      toolbar={<Toolbar onSend={() => onSend(text)} />}
    >
      <Editor value={text} onChange={setText} />
    </ComposerFrame>
  );
}

// Variant 2 — draft edit.
function EditComposer({ draftId, onSaveDraft, onSend }: {
  draftId: string;
  onSaveDraft: (text: string) => void;
  onSend: (text: string) => void;
}) {
  const { text, setText } = useDraft(draftId);
  return (
    <ComposerFrame
      toolbar={
        <Toolbar
          onSend={() => onSend(text)}
          onSaveDraft={() => onSaveDraft(text)}
        />
      }
    >
      <Editor value={text} onChange={setText} />
    </ComposerFrame>
  );
}

// Variant 3 — read-only preview.
function PreviewComposer({ messageId }: { messageId: string }) {
  const message = useMessage(messageId);
  return (
    <ComposerFrame>
      <PreviewBody message={message} />
    </ComposerFrame>
  );
}
```

Each variant is short, has its own typed props, and never has to consider what another variant does. TypeScript can enforce that `draftId` is required for `EditComposer`, period — no runtime guard needed.

## Naming conventions

- **Variant components take the noun, not the flag.** `EditComposer`, not `ComposerWithEditMode`. `KebabRow`, not `RowKebabVariant`.
- **The primitive carries the family root name.** `Composer` (or `ComposerFrame`) is the shared piece; `ThreadComposer`, `EditComposer`, `PreviewComposer` are the variants. The pattern reads naturally in the IDE's import picker.
- **3+ variants is the trigger.** With 2, a discriminated union on `mode` is often cleaner: `<Composer mode="thread" />` vs `<Composer mode="edit" />`. With 3+, the conditional surface in the union version gets noisy.

## When NOT to apply

- **Pure visual variants of the same content** — `<Badge variant="success" />` vs `<Badge variant="danger" />`. No structural difference; no per-variant props; a string union prop is correct.
- **HTML primitive wrappers** — `<Button variant="primary" />` mirrors industry convention. Inventing `<PrimaryButton>` and `<DangerButton>` just to be consistent with this rule loses ecosystem familiarity.
- **Stable 2-mode components** — `<List dense />`, `<Form mode="create" | "edit" />` — when both modes are tightly related and the divergence is small. Splitting earns nothing.

The pattern earns its premium when:

1. There are 3+ modes
2. Modes have different required props
3. The implementation has a long `if (mode === '...')` chain or a switch statement that touches multiple render paths
