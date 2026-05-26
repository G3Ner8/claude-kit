---
title: Split Hooks That Bundle Independent State
impact: MEDIUM
impactDescription: a hook that returns 6 unrelated state pieces forces every consumer to re-render when any one changes — split into focused hooks instead
tags: prevent-rerender, hooks, api-design, selectors
---

## Split Hooks That Bundle Independent State

A custom hook that bundles multiple unrelated state pieces forces consumers to re-render on every change to any of them. If `useDashboard()` returns `{ user, notifications, theme, filters, layout }`, a component that reads `theme` re-renders whenever `notifications` updates — even though it doesn't read notifications.

Split the hook into focused units, one per dimension. Consumers subscribe only to what they read.

**Incorrect — one mega-hook:**

```tsx
function useDashboard() {
  const user          = useUser();
  const notifications = useNotifications();
  const theme         = useTheme();
  const filters       = useFilters();
  const layout        = useLayout();
  return { user, notifications, theme, filters, layout };
}

function ThemeToggle() {
  const { theme, ...rest } = useDashboard();   // subscribes to all 5
  return <button>{theme}</button>;
}
```

`<ThemeToggle>` re-renders when `notifications` update, when `filters` change, when `layout` shifts — none of which it actually reads.

**Correct — one hook per concern:**

```tsx
function ThemeToggle() {
  const theme = useTheme();   // subscribes only to theme
  return <button>{theme}</button>;
}
```

`<ThemeToggle>` re-renders only when the theme actually changes.

## Compose at the consumer site

If a component genuinely needs three of the five things, call three hooks:

```tsx
function DashboardHeader() {
  const user          = useUser();
  const notifications = useNotifications();
  const theme         = useTheme();
  // Doesn't subscribe to filters or layout — won't re-render on their changes.
  return <header className={theme}>{user.name} · {notifications.count}</header>;
}
```

Three subscriptions, narrowly scoped.

## When the bundle is actually a single concept

Some bundles are correct:

```tsx
function useFormState<T>(initial: T) {
  const [values, setValues] = useState(initial);
  const [errors, setErrors] = useState<Partial<Record<keyof T, string>>>({});
  const [isDirty, setIsDirty] = useState(false);
  // values, errors, isDirty are conceptually one "form state"
  return { values, errors, isDirty, /* ... */ };
}
```

Here the three pieces form a coherent unit — consumers usually want all three together. Splitting into `useFormValues`, `useFormErrors`, `useFormDirty` would force every consumer to call three hooks just to render one form. Don't split when the bundle is the concept.

The rule is: split when consumers read **disjoint subsets** of the bundle.

## When NOT to apply

- **The bundle is conceptually inseparable** — see the form-state example. Splitting hurts ergonomics.
- **The state changes in lockstep** — if `a`, `b`, `c` only ever change together (one reducer action sets all three), the re-render savings from splitting are zero.

## Related

- [`derived-state`](./derived-state.md) — even with a bundled hook, a derived selector can narrow which changes cause re-renders.
- [`defer-reads`](./defer-reads.md) — when the bundled hook is the right shape but a consumer only reads in callbacks, skip the subscription via `getState()`.
