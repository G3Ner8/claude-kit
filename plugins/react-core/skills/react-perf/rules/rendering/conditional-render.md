---
title: Use Explicit Conditional Rendering (Avoid `&&` with Numbers)
impact: HIGH
impactDescription: prevents accidental "0" / "NaN" leaking into the DOM (correctness bug)
tags: rendering, conditional, jsx, falsy-values, correctness
---

## Use Explicit Conditional Rendering (Avoid `&&` with Numbers)

> **This is a correctness rule, not a performance rule.** It's grouped under rendering because it controls what the rendered tree looks like.

The expression `{value && <Element />}` evaluates to `value` when `value` is falsy. JSX renders most falsy values as nothing — *except numbers*. `0` becomes the text node `"0"`, and `NaN` becomes `"NaN"`. This produces visible UI bugs that get found in QA or, worse, in production.

**Incorrect (renders "0" when `count` is 0):**

```tsx
function Badge({ count }: { count: number }) {
  return (
    <div>
      {count && <span className="badge">{count}</span>}
    </div>
  )
}

// When count = 0  → <div>0</div>          ← bug
// When count = 5  → <div><span class="badge">5</span></div>
// When count = NaN → <div>NaN</div>       ← worse bug
```

**Correct option A — explicit ternary:**

```tsx
function Badge({ count }: { count: number }) {
  return (
    <div>
      {count > 0 ? <span className="badge">{count}</span> : null}
    </div>
  )
}
```

**Correct option B — coerce to boolean:**

```tsx
return <div>{!!count && <span className="badge">{count}</span>}</div>
```

`!!count` returns `false` for `0` and `NaN`, and JSX skips `false`.

**Correct option C — guard at the boundary, return early:**

```tsx
function Badge({ count }: { count: number }) {
  if (count <= 0) return null
  return <div><span className="badge">{count}</span></div>
}
```

Often the cleanest of the three when the whole component should not render.

### When `&&` is fine

`&&` is safe with values that are guaranteed boolean or guaranteed non-numeric:

```tsx
{isOpen && <Modal />}                  // boolean — safe
{user && <Profile user={user} />}      // object | null — safe (null renders nothing)
{items.length > 0 && <List />}         // comparison returns boolean — safe
```

The trap is specifically `{numericValue && <X />}` and `{maybeNumber && <X />}`.

### Lint it

Add `@typescript-eslint/strict-boolean-expressions` or `react/jsx-no-leaked-render` to your ESLint config to catch this at PR time rather than in QA.

Reference: [React docs — Conditional Rendering](https://react.dev/learn/conditional-rendering), [eslint-plugin-react — jsx-no-leaked-render](https://github.com/jsx-eslint/eslint-plugin-react/blob/master/docs/rules/jsx-no-leaked-render.md)
