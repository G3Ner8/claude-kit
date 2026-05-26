---
title: Hoist RegExp Outside Loops and Hot Paths
impact: LOW
impactDescription: RegExp construction is non-trivial — moving it out of the loop saves the parse on every iteration
tags: js-micro, regexp, hoisting, hot-path
---

## Hoist RegExp Outside Loops and Hot Paths

A RegExp literal inside a loop or a frequently-called function gets parsed and constructed on every call. The parse isn't free — for non-trivial patterns it's measurable, and the GC churn from throwing away the object is just as bad.

Hoist the RegExp to module scope (or to the top of the calling function, outside the loop).

**Incorrect — constructed every iteration:**

```ts
function sanitizeRows(rows: string[]) {
  return rows.map((row) => row.replace(/[^a-zA-Z0-9_-]/g, ''));
}
```

For 10,000 rows, the engine parses the literal 10,000 times.

**Correct — hoisted, parsed once:**

```ts
const SAFE_CHARS = /[^a-zA-Z0-9_-]/g;

function sanitizeRows(rows: string[]) {
  return rows.map((row) => row.replace(SAFE_CHARS, ''));
}
```

One construction; reused across all iterations.

## Stateful flags

A `g` (global) or `y` (sticky) RegExp keeps its `lastIndex` across `exec()` calls — sharing one across consumers can cause skipping or double-matches. For those, either:

- Use `String.prototype.matchAll` (returns an iterator without mutating the RegExp), or
- Use `replace` / `match` (these reset `lastIndex` automatically), or
- Construct fresh per call (back to the original problem — but local scope makes the trade-off explicit).

```ts
const NUM = /\d+/g;
function countNumbers(s: string) {
  // matchAll doesn't mutate NUM.lastIndex
  return Array.from(s.matchAll(NUM)).length;
}
```

## When NOT to apply

- **Per-call RegExp built from dynamic strings** — `new RegExp(userInput)` can't be hoisted because the input changes. Cache by key if many calls share the same input.
- **One-shot helpers** — if `sanitize` runs once per page load, the saving is invisible.

## Related

- [`hoist-immutable-defaults`](./set-map-lookups.md) — same general idea: hoist immutable values out of hot paths.
