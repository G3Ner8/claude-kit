---
title: Defer Awaits to Where the Value Is Used
impact: HIGH
impactDescription: moves expensive awaits out of the common code path so callers that never reach the branch don't pay for the network call
tags: async, latency, lazy-evaluation, hot-path
---

## Defer Awaits to Where the Value Is Used

Resolve a Promise at the moment you need its value, not at the top of the function. Top-of-function awaits force every caller to wait for the result — even callers that take an early branch and never read it.

The fix is a refactor, not a configuration: pass the Promise down, and `await` it only inside the branch that consumes it.

**Incorrect — awaits up front, even when the branch may not need the value:**

```ts
async function renderEmployeeCard(id: string, mode: 'compact' | 'detail') {
  const employee = await fetchEmployee(id);          // ALWAYS paid
  const role     = await fetchRoleHierarchy(id);     // ALWAYS paid

  if (mode === 'compact') {
    return { name: employee.name };                  // didn't need `role` at all
  }
  return { name: employee.name, role };
}
```

The `compact` path pays a network round-trip for `role` it discards.

**Correct — kick off both fetches in parallel, but only await `role` in the branch that uses it:**

```ts
async function renderEmployeeCard(id: string, mode: 'compact' | 'detail') {
  const employeePromise = fetchEmployee(id);         // start, don't await
  const rolePromise     = fetchRoleHierarchy(id);    // start, don't await

  const employee = await employeePromise;            // always needed

  if (mode === 'compact') {
    return { name: employee.name };                  // rolePromise garbage-collected
  }
  const role = await rolePromise;                    // only paid in detail branch
  return { name: employee.name, role };
}
```

Starting the Promise (without awaiting) lets it run concurrently with the other work. The `await` happens only where the consumer reads the value. Branches that don't read it never block on it.

## When the Promise hangs forever

A Promise that's started but never awaited isn't a leak — once it's unreachable, JS garbage-collects it. The request still hits the wire and resolves; the result is just ignored. For HTTP this is acceptable; for expensive server-side work (sending an SMS, charging a card), don't start operations whose side effects you'll discard — use a real predicate first.

## When NOT to apply

- **Sequential dependency** — if call B needs the result of call A as input, you can't defer A past B's `await`. The await order is fixed by the dependency.
- **Error handling** — an unawaited rejected Promise can warn ("unhandled promise rejection") in Node. In a browser, it's logged but doesn't crash. If error reporting matters and you may not await, attach a `.catch(() => {})` at start time.

## Related

- [`parallel-promises`](./parallel-promises.md) — when both promises are *always* needed, hoist them with `Promise.all`.
- [`cheap-condition-before-await`](./cheap-condition-before-await.md) — gate awaits behind synchronous checks before starting them at all.
