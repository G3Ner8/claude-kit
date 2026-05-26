---
title: Use Ternary, Not `&&`, for Non-Boolean Conditions
impact: MEDIUM
impactDescription: prevents "0" from rendering as visible text when a numeric check is intended to mean "has any"
tags: render-output, conditional, jsx, correctness, gotcha
---

## Use Ternary, Not `&&`, for Non-Boolean Conditions

`a && b` in JSX renders `b` when `a` is truthy and renders **`a` itself** when `a` is falsy. For booleans, falsy values (`false`) render as nothing. For other types, falsy values render visibly:

| Value | Rendered as |
|---|---|
| `false` | (nothing) |
| `null` / `undefined` | (nothing) |
| `0` | **"0" visible in the DOM** |
| `""` | (nothing) |
| `NaN` | **"NaN" visible in the DOM** |

The bug: when the condition is intended to mean "do we have any" via length or count, `0` renders as a stray "0" in the UI.

This is a correctness rule, not a perf rule — but it's grouped under render output because it changes what the browser paints.

**Incorrect — `items.length && <List />` renders "0" when items is empty:**

```tsx
function Container({ items }: { items: Item[] }) {
  return (
    <div>
      {items.length && <List items={items} />}   {/* "0" appears when items is empty */}
    </div>
  );
}
```

When `items.length === 0`, JSX renders the number `0`. The user sees a stray "0" in the UI.

**Correct — explicit boolean:**

```tsx
function Container({ items }: { items: Item[] }) {
  return (
    <div>
      {items.length > 0 && <List items={items} />}
    </div>
  );
}
```

Or use a ternary that returns `null` explicitly:

```tsx
{items.length > 0 ? <List items={items} /> : null}
```

Both are safe.

## When the condition is reliably boolean

If the condition is **guaranteed** boolean (`if (isLoading)`, `if (showFooter)`), `&&` is fine:

```tsx
{isLoading && <Spinner />}      {/* isLoading is a boolean — safe */}
{showFooter && <Footer />}      {/* showFooter is a boolean — safe */}
```

The danger is only with non-boolean coercion.

## Lint enforcement

ESLint rule `react/jsx-no-leaked-render` catches this. Add it to your config:

```json
{
  "rules": {
    "react/jsx-no-leaked-render": ["error", { "validStrategies": ["ternary"] }]
  }
}
```

With `validStrategies: ["ternary"]`, the rule requires either an explicit ternary or a boolean comparison (`x > 0`). The shorthand `&&` on a number is flagged.

## When NOT to apply

- **You actively want to render the falsy value** — extremely rare. If you do, `<>{value}</>` makes the intent explicit.

## Verify

Run the lint rule (above). It catches every case at build time, no runtime needed.

## Related

- [`prevent-rerender/derived-state`](../prevent-rerender/derived-state.md) — when a count is used for a boolean check, narrow the selector to the boolean rather than passing the count.
