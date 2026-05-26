---
title: `useTransition` Instead of `isLoading` Flags
impact: MEDIUM
impactDescription: avoids the spinner flash on fast operations and gives a smooth "in-progress" UI without manual loading-state bookkeeping
tags: render-output, useTransition, loading, react18, ux
---

## `useTransition` Instead of `isLoading` Flags

A common pattern: an action triggers an async operation, code flips `setIsLoading(true)` before the call and `setIsLoading(false)` after. JSX renders a spinner while `isLoading` is true.

This works, but has two annoyances:

1. **Spinner flash** — for operations that finish in 50 ms, the spinner shows for 50 ms. The flicker feels worse than no spinner.
2. **Manual bookkeeping** — every async path has its own `try / finally` to flip the flag back.

`useTransition` solves both. It marks an update as non-urgent and gives you an `isPending` flag that's automatically derived from React's scheduler. You don't manage it; you don't risk forgetting the cleanup; and React can choose not to show pending state if the work completes within a short threshold.

**Incorrect — manual flag with cleanup ritual:**

```tsx
function SaveButton() {
  const [isSaving, setIsSaving] = useState(false);

  const onSave = async () => {
    setIsSaving(true);
    try {
      await saveDraft();
    } finally {
      setIsSaving(false);     // forgetting this = stuck spinner
    }
  };

  return <button onClick={onSave}>{isSaving ? <Spinner /> : 'Save'}</button>;
}
```

Risks: a thrown error before `finally`, a cancellation path that bypasses cleanup, double-flipping when the user clicks twice quickly.

**Correct — `useTransition` manages the flag:**

```tsx
function SaveButton() {
  const [isPending, startTransition] = useTransition();

  const onSave = () => {
    startTransition(async () => {
      await saveDraft();
    });
  };

  return (
    <button onClick={onSave} disabled={isPending}>
      {isPending ? <Spinner /> : 'Save'}
    </button>
  );
}
```

React's scheduler manages `isPending`. It's true while the transition is in flight, false when done. No try/finally; no risk of stuck spinner.

## React 19 form integration

For forms, React 19 ships `<form action={fn}>` with automatic pending state via `useFormStatus`:

```tsx
import { useFormStatus } from 'react-dom';

function Submit() {
  const { pending } = useFormStatus();   // reads parent <form>'s pending state
  return <button disabled={pending}>{pending ? 'Saving...' : 'Save'}</button>;
}

function EmployeeForm() {
  return (
    <form action={async (formData) => { await saveEmployee(formData); }}>
      <input name="name" />
      <Submit />
    </form>
  );
}
```

The `<form action>` is a transition under the hood. `<Submit>` reads `pending` from `useFormStatus` without prop drilling.

## Naming convention

For consistency across the codebase:

- `isLoading` = data fetch in flight (TanStack Query / SWR).
- `isPending` = transition in flight (`useTransition` / form submission).

`isLoading` and `isPending` are not the same flag and shouldn't be aliased.

## When NOT to apply

- **Long-running operations (> 1 second)** — transitions are tuned for short interactive work. For long uploads, use explicit progress UI.
- **Async work that runs outside React** — a fetch driven by a non-React store; transitions don't see it. Use the store's loading state.
- **You need timing data** — `useTransition` doesn't expose elapsed time. Manual flags + `performance.now()` give that.

## Related

- [`prevent-rerender/transitions`](../prevent-rerender/transitions.md) — same primitive, used to keep input responsive during slow renders.
- [`prevent-rerender/use-deferred-value`](../prevent-rerender/use-deferred-value.md) — the receive-side equivalent for downstream renders.
