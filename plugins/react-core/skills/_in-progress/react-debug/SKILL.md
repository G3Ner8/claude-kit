---
name: react-debug
description: A 5-step debug discipline for "data not flowing" bugs in a React SPA — symptoms like "API not called", "no data", "no error", "isLoading forever". Walks the BE↔FE chain layer by layer instead of patching the symptom. Use when triaging a data-fetch bug before touching frontend code. Triggers - "debug X", "why isn't X loading", "no data on X", "API not firing for X", "investigate X bug".
license: MIT
user-invocable: true
metadata:
  version: "0.1.0"
  type: reference
  status: experimental
  stack: React 19, TanStack Query / SWR, any HTTP backend
  scope: data-fetch debugging (FE chain + BE contract)
---

# React Debug Protocol

A 5-step discipline for the most common React bug shape: "the data isn't there." Symptoms include `isLoading` stuck `true`, `data` stuck `undefined`, the network tab showing no request, the request firing but the response being mis-parsed, or the component rendering nothing despite a successful response.

The discipline matters because the bug is **almost never where the symptom is**. The component shows nothing → the developer reflexively edits the component. But the broken layer is upstream — usually the query key, the request shape, or the backend itself.

This skill walks the layers in order. You name the broken layer **before** proposing a fix.

## When to use

Reach for this skill when:

- The user reports "API not called / no data / no error / isLoading forever"
- A component renders nothing where it should render rows
- A mutation fires but the cache doesn't refresh
- A query refetches infinitely
- Response data is present but fields are missing or `undefined`
- Network tab shows the wrong endpoint, method, payload, or status

Skip this skill for:

- Compile/build errors — those are not "data not flowing" bugs
- Layout/styling bugs — wrong colors, wrong sizes, broken responsive
- Form validation that displays the wrong message — that's UI logic, not data flow
- Genuine FE state bugs (the data arrived but state didn't update) — start from the component instead

## The protocol

Five steps. Do them in order. The order is the whole point — skipping ahead is how teams end up patching the symptom.

### Step 1 — Verify the backend contract

**Do not touch FE code first.** Confirm what the backend actually expects and returns before assuming the FE is at fault.

For projects with a Swagger / OpenAPI doc:

- Fetch the relevant endpoint's spec.
- Note: path, method, required params, request body shape, response shape, auth requirements.
- Cross-reference: does the FE's intended call match this spec?

For projects without Swagger, read the backend controller + service for the endpoint. The signature is the contract.

Common Step-1 findings:

- The endpoint is `POST` but the FE sends `GET`.
- A required header (auth, tenant) is missing.
- A query param is named differently (`employee_id` vs `employeeId`) — see Step 2 for case conventions.
- The endpoint moved to a new path in a recent BE deploy.
- The response status is 200 but the body is `{ error: ... }` — the FE assumes 200 = success.

If Step 1 finds a divergence, that's the bug. Don't proceed to Step 2.

### Step 2 — Walk the FE chain top-to-bottom

If Step 1 confirms the backend matches, the bug is in the FE chain. Walk every link in order:

| Layer | What to check |
|---|---|
| **Hook mounted?** | Is the component that calls the hook actually rendered? React Devtools → component tree. |
| **`enabled` gate** | If using TanStack Query / SWR, is `enabled` evaluating to `true`? A `false` `enabled` makes `isLoading: false, data: undefined` — looks like "no data" but is intentional. |
| **Query key** | Does the key include **every** input the query depends on? Missing `userId` in the key = stale-cache reuse across users. |
| **Request shape** | Compare to Step 1's contract: path, method, params, body. Pay attention to case (snake_case ↔ camelCase) conversion if your project uses a transform layer. |
| **Response handler** | Does the parser correctly map BE shape to FE shape? A `case-transform` helper that doesn't recurse into arrays-of-objects is a common miss. |
| **Component read** | Does the component read `data` (not `data.data`, not `result`), `isLoading` (not `loading`), `error` (not `errors`)? Library-specific naming matters. |

Stop at the first broken link. The fix goes there.

### Step 3 — Strategic logging when inspection isn't enough

If Step 2 can't isolate the layer by reading code (e.g., the request shape *looks* right but the BE rejects), add **one** `console.log` per layer, in order:

```ts
// Layer 1: hook actually called?
console.log('[debug] useEmployee called with', { id, enabled });

// Layer 2: query fn fired?
const queryFn = async () => {
  console.log('[debug] queryFn fired for', id);
  return fetchEmployee(id);
};

// Layer 3: API service shape?
async function fetchEmployee(id: string) {
  const req = { path: `/employees/${id}` };
  console.log('[debug] fetchEmployee request', req);
  const res = await http.get(req.path);
  console.log('[debug] fetchEmployee response', res);
  return parseEmployee(res);
}
```

Run the scenario, read the logs in order:

- Layer 1 missing → component isn't mounting or hook is gated.
- Layer 1 present, Layer 2 missing → `enabled` is false or query is suspended.
- Layer 2 present, Layer 3 missing → service-layer code is throwing before the call.
- Layer 3 request fires, response missing → backend issue (re-check Step 1).
- Response present, parsed wrong → parser/transform bug.

**Clean up the logs before declaring done.** A `[debug]` left in production code is a code-review failure. Some teams enforce this with a lint rule (`no-console` with `{ allow: ['warn', 'error'] }`).

### Step 4 — Name the broken layer before proposing a fix

Before writing any code change, state out loud (or in chat):

> "The broken layer is **[Step 2 layer name]**. The fix is to **[specific action]**."

Examples:

- "Broken layer: query key. Fix: add `userId` to `['employee', userId]` so the cache isn't shared across users."
- "Broken layer: backend contract. Fix: backend ticket — the `roles` field returns `null` instead of `[]` for new employees."
- "Broken layer: response handler. Fix: the `case-transform` helper needs to recurse into array values."

This step exists to prevent the "patch the symptom" reflex. If you can't name the broken layer cleanly, you don't understand the bug yet — go back to Step 2.

### Step 5 — Don't patch FE if the root cause is BE

If the broken layer is the backend contract (Step 1) or BE behavior (e.g., BE returns 200 with an error body):

- **Don't** "handle the edge case" in the FE by checking for the error body. That bakes the BE quirk into the FE forever.
- **Do** open a backend ticket. Document the divergence between Swagger and actual behavior, or between docs and code.
- If a FE workaround is **temporarily** necessary (BE fix is gated behind a deploy), gate the workaround behind a TODO with the ticket URL and a removal date.

The same applies to "BE returns inconsistent casing" or "BE sometimes returns `null`, sometimes `[]`" — symptoms are FE-visible but the fix lives in the BE.

## Common anti-patterns

- **FE-first patching** — "the response is `undefined`, let me default to `{}`." This silences the symptom and removes the signal that something upstream is broken.
- **Try/catch swallowing** — wrapping the whole call in `try { ... } catch { /* ignore */ }` so errors don't crash. The errors were the only feedback you had.
- **Console.log explosion** — sprinkling 30 logs across the file. Strategic placement is the discipline; spray-logging is its anti-pattern.
- **"Fixing" the query key without understanding why** — adding more values "to be safe" instead of including exactly the values the query depends on.
- **Mutating the query cache directly** — `queryClient.setQueryData(...)` to paper over a stale read instead of figuring out why the cache went stale.

## When NOT to apply

- **Build errors** — the protocol is for runtime data-flow bugs. A failing build is a different debugging exercise.
- **Performance bugs** — see `react-perf` (and specifically `prevent-rerender/*` for re-render storms).
- **Pure FE state bugs** — the data arrived correctly, but `useState` is being mismanaged. Skip ahead to Step 2's "Hook mounted? `enabled`?" but the rest doesn't apply.
- **Auth/redirect flows** — when "no data" means "the user was bounced to login," the bug is in the auth flow, not the data layer.

## Related

- For backend contract verification, projects with Swagger should plumb a backend URL into the debug skill's invocation context (e.g., as a parameter to the agent that wraps this skill).
- For mutation-cache invalidation bugs specifically, see `react-perf/runtime-io/query-library-dedup` for key-naming conventions that make invalidation predictable.
- For "the data is right but the component renders nothing," return to React Devtools and inspect the component tree — the bug is in conditional rendering, not data flow.
