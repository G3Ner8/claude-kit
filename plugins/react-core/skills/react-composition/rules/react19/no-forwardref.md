---
title: ref as a Regular Prop, `use(Context)` over `useContext`
impact: MEDIUM
impactDescription: React 19 removed the need for `forwardRef` and made `use(Context)` the preferred reader — both unlock simpler component APIs and conditional context reads
tags: react19, ref, context, api-changes, modernization
---

## React 19: `ref` as a prop, `use()` as the context reader

React 19 deprecated `forwardRef` and added `use()` as a first-class read primitive. Two distinct rewrites, paired here because they sit on the same boundary: how a parent reaches into a child's tree.

### Part 1 — `ref` is now a regular prop

Pre-19, exposing a DOM node (or imperative handle) to the parent meant wrapping the component in `forwardRef`. In React 19, function components accept `ref` directly through their props bag.

**Incorrect (pre-19 pattern, now deprecated):**

```tsx
import { forwardRef } from 'react';

interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label: string;
}

const Input = forwardRef<HTMLInputElement, InputProps>(({ label, ...rest }, ref) => {
  return (
    <label>
      <span>{label}</span>
      <input ref={ref} {...rest} />
    </label>
  );
});
Input.displayName = 'Input';
```

`forwardRef` adds a function wrapper, an awkward `displayName` ritual, and a generic with two type parameters that the rest of your code doesn't share.

**Correct (React 19):**

```tsx
interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label: string;
  ref?: React.Ref<HTMLInputElement>;
}

function Input({ label, ref, ...rest }: InputProps) {
  return (
    <label>
      <span>{label}</span>
      <input ref={ref} {...rest} />
    </label>
  );
}
```

That's it. `ref` is a normal prop. No wrapper, no `displayName`, no double-generic.

### Part 2 — `use(Context)` over `useContext(Context)`

`useContext` still works in React 19, but `use()` is the preferred reader for two reasons:

1. **`use()` can be called conditionally.** `useContext` is bound by the rules of hooks — never inside `if`, never after a `return`. `use()` is a regular function with a special compiler contract; it can sit inside any branch that runs during render.
2. **`use()` works on more than context.** The same primitive reads a Promise during render (Suspense), making it a general "wait for this" call. Consistency across primitives matters more as the codebase grows.

**Incorrect (works, but pre-19 idiom):**

```tsx
import { useContext } from 'react';

function ToolbarSaveButton() {
  const ctx = useContext(EditorContext);
  if (!ctx) return null;
  return <button onClick={ctx.save}>Save</button>;
}
```

The early-return `if (!ctx)` is fine — but the `useContext` call still happens unconditionally, even on renders where the toolbar shouldn't exist at all.

**Correct (React 19):**

```tsx
import { use } from 'react';

function ToolbarSaveButton({ enabled }: { enabled: boolean }) {
  if (!enabled) return null;
  // `use()` legally sits after the early-return.
  const ctx = use(EditorContext);
  if (!ctx) return null;
  return <button onClick={ctx.save}>Save</button>;
}
```

The reader-after-return-guard pattern works cleanly. The component bails out earlier, and `use()` never runs when the toolbar is disabled.

The provider also gets a small win — React 19 accepts `<Context value={...}>` directly instead of the older `<Context.Provider value={...}>`:

```tsx
// React 19 — preferred
<EditorContext value={editorValue}>{children}</EditorContext>

// Pre-19 — still works, but the shorthand is the convention now
<EditorContext.Provider value={editorValue}>{children}</EditorContext.Provider>
```

## Migration checklist

When converting a pre-19 component:

1. Replace `forwardRef<RefType, Props>((props, ref) => { ... })` with `function Component({ ref, ...props }: Props & { ref?: Ref<RefType> }) { ... }`.
2. Drop the `.displayName = '...'` line — React 19 infers it from the function name.
3. Replace `useContext(X)` with `use(X)`.
4. Replace `<X.Provider value={v}>` with `<X value={v}>`.
5. Run the type checker — any `forwardRef` import or `useContext` call that survives is a regression.

## When NOT to apply

- **Compatibility with React 18 or earlier** — if the library targets multiple React majors, keep `forwardRef` + `useContext`. The deprecated APIs still work in 19; the migration is a fitness move, not a correctness fix.
- **`React.memo` wrappers** — `memo()` is separate from `forwardRef` and is **not** deprecated. Don't strip it accidentally during the migration.
- **`useImperativeHandle`** — still the right API for exposing a custom imperative handle via `ref`. The change is only in how `ref` reaches the component, not in how it's customized.

The trigger is **a React 19 codebase that hasn't yet migrated**. New code in a 19 project should never reach for `forwardRef` or `useContext`.
