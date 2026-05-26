---
name: react-revamp
description: Propose a production-grade UX/UI flow revamp for a single frontend page. Reviews the target page against canonical reference pages and (if provided) the live API surface, then proposes a detailed execution plan with layout sketches, state maps, and best practices. Use when asked to "revamp the flow on page X", "redesign the user flow for X", "fix the UX flow on page X", or invoked as `/react-revamp`. Read-only — produces a proposal; never edits code without explicit approval.
license: MIT
user-invocable: true
metadata:
  version: "1.0.0"
  derived_from: project-internal (was: legacy flow agent)
  stack: framework-agnostic procedure; examples target React 19 codebases
  scope: Read-only proposal — single page only
---

# React Page Flow Revamp

Propose a production-grade UX/UI flow revamp for **one** page. The output is a complete deliverable — revamped user flow, layout sketches per state, component decisions, execution plan, best practices — grounded in the project's existing design language and real API surface.

This skill is **frontend-only**. If the backend feels wrong, flag it as a question for the user; don't propose API changes.

Output is a proposal. After producing it, **stop and wait** for explicit "apply" approval before any edit.

---

## Step 1 — Gather Inputs (MANDATORY before any work)

Do not Read, Glob, Grep, or fetch anything until you have **all** required inputs. Use `AskUserQuestion` to collect them in one call. Wait for the response.

Required:

1. **Target page path** — page folder + entry file (e.g. `src/features/leave/pages/LeaveListPage/index.tsx`). If the user gives only a feature/page name, resolve to a concrete path and confirm before continuing.
2. **Reference / canonical page paths** — 1–2 pages that define the project's idioms (e.g. `src/features/employee/pages/EmployeeListPage/index.tsx`). Your proposal must feel like a natural sibling of these.
3. **Design tokens location** — auto-detect (look for `tailwind.config.*`, `tokens.css`, design-system docs) and confirm with user, or accept an explicit path.
4. **API discovery method** — one of:
   - URL to Swagger / OpenAPI doc (used with `WebFetch` if the agent has it)
   - Local OpenAPI spec path
   - `skip` (proceed without API verification — note this in the report)

Optional (ask only if scope is genuinely ambiguous, max 1–2 follow-ups):

5. **Primary user goal on this page** — review information, take an action, or both? Affects flow weight.
6. **Constraints** — deadline, partial revamp, must keep current route shape, must keep current data layer, etc.

Conditional:

7. **Output language** — `English` or `Thai`. **Ask this** — page-flow output is almost always long. Default to English if user doesn't specify.

Stop and wait until all required inputs are answered.

---

## Step 2 — Discovery

Once inputs are confirmed:

- `Read` the target page in full plus its immediate dependencies (skeleton, sections, dialogs it owns).
- Map the page's current responsibilities: what data it loads, which components it renders, what user flows it supports, what's broken or awkward.
- `Read` the closest equivalent reference page(s) to lock in the project's idioms.
- API discovery:
  - If a Swagger/OpenAPI URL was given and `WebFetch` is available: fetch the doc and identify every endpoint the target page touches.
  - If a local spec path was given: `Read` the relevant sections.
  - If `skip` was chosen: note "API verification skipped — flow proposal will not assume backend changes" in the report.
- For each identified endpoint: note `method`, `path`, request shape, response shape, error responses.

Do not yet write findings or proposal. This step is data gathering only.

---

## Step 3 — UX / UI Flow Audit

Critique the target page across five dimensions. Each finding names **what** is wrong and **why** it hurts the user.

- **Flow** — Is the happy path direct? Redundant steps? Modal-on-modal stacks? Confirm fatigue? Unclear next-action?
- **Layout** — Visual hierarchy, density, scan path, primary-action visibility, calm vs cockpit
- **Components** — Are buttons / tables / dialogs / comboboxes / empty-states consistent with the references?
- **Visuals** — Typography scale, spacing rhythm, color usage (semantic tokens?), motion vocabulary
- **Edge cases** — Loading, empty, error, partial-permission, long-string handling

---

## Step 4 — Proposal

Produce the following four artifacts. Be concrete — name components, props, tokens — not vague principles.

### 4a. Revamped flow

Narrate the new user journey in **5–10 numbered steps**. Each step is a user action plus what the UI does in response.

### 4b. Layout sketches

ASCII or markdown layouts for **each major screen state**. Use the project's vocabulary (page header, toolbar, table, side panel, etc.).

Mandatory states to sketch (omit any that genuinely don't apply to this page):

- **Default** (data loaded, primary flow)
- **Loading** (initial fetch / refetch)
- **Empty** (no data yet, with CTA)
- **Error** (recoverable / non-recoverable)
- **Success / mutation feedback** (toast / banner / inline)

Example sketch shape:

```
┌─────────────────────────────────────────────────────────┐
│  PageHeader                                              │
│  Leave Requests                       [+ New Request]   │
│  Approve, reject, and track leave activity              │
├─────────────────────────────────────────────────────────┤
│  Toolbar                                                 │
│  [ Search ] [ Filter: Status ▾ ] [ Date range ▾ ]       │
├─────────────────────────────────────────────────────────┤
│  Table                                                   │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Employee   │ Type    │ Dates    │ Status │ ⋯    │   │
│  │ ...                                                │   │
│  └─────────────────────────────────────────────────┘   │
│  ◀ 1 2 3 ▶                       12 of 142             │
└─────────────────────────────────────────────────────────┘
```

### 4c. Component decisions

Three lists, short and concrete:

- **Reuse** — existing primitives the new design uses as-is (with import path)
- **Copy pattern from** — patterns lifted from the reference pages (with source page + which pattern)
- **New (if any)** — components that don't exist yet, with a 1-sentence justification each. Be conservative — every new primitive is a maintenance cost.

### 4d. State map

For each state (loading / empty / error / success / partial-permission), a 1–2 line description of what the UI shows + which component handles it.

---

## Step 5 — Execution Plan

A concrete, ordered, surgical plan. File-by-file:

- What to **add**, what to **refactor**, what to **delete**.
- Group changes into **commit-sized chunks** (each chunk = one logical PR/commit).
- Call out **risky parts** (data migrations, breaking prop changes, route changes).
- Estimate touch surface — number of files and rough LOC delta.

---

## Step 6 — Best Practices Applied

Two short sections — only points that **genuinely apply** to this revamp, not boilerplate.

- **UX/UI** — e.g. progressive disclosure here, optimistic update there, skeleton parity, focus management on dialog close
- **Arch/Dev** — e.g. memoize this list cell, move this fetch to a route loader, collocate types, extract this shared form into the feature's `components/`, drop this dead prop

---

## Step 7 — Output Template

```
# Flow Revamp Proposal: <page path>

## Inputs
- Target: <path>
- References: <paths>
- Tokens at: <path>
- API: <Swagger URL / OpenAPI path / skipped>

## Discovery
- Page does: <one paragraph>
- API endpoints in use:
  - <method> <path> — <one-line shape note>
  - ...
- Closest reference: <reference page path> — why

## Audit findings
- **Flow** — ...
- **Layout** — ...
- **Components** — ...
- **Visuals** — ...
- **Edge cases** — ...

## Proposed flow
1. ...
2. ...

## Layout sketches

### Default
<ascii sketch>

### Loading
<ascii sketch>

### Empty
<ascii sketch>

### Error
<ascii sketch>

### Success / mutation feedback
<ascii sketch>

## Component decisions
- **Reuse**:
  - `<ComponentName>` from `<import path>` — used for <where>
- **Copy pattern from**:
  - `<reference page>` — the <pattern name> pattern
- **New (with justification)**:
  - `<NewComponentName>` — <one-sentence reason>; or "none"

## State map
- Loading: <description>
- Empty: <description>
- Error: <description>
- Success: <description>
- Partial-permission (if applicable): <description>

## Execution plan
1. **Chunk 1 — <name>**: <file> — <change>, <file> — <change>. ~<LOC>, risk: low/med/high
2. **Chunk 2 — <name>**: ...
...

Estimated total touch: <N files>, ~<LOC>.
Risky bits: <list or "none">.

## Best practices applied
**UX/UI**
- ...

**Arch/Dev**
- ...

---
Open questions for you: <list or "none">.
Status: read-only proposal complete. Waiting for "apply" before any edit.
```

---

## Stop Conditions (READ-ONLY discipline)

This skill is **read-only by design**. After producing the proposal:

- Do not run `Edit`, `Write`, `NotebookEdit`, or any modification.
- Do not stage / commit / push.
- End the turn with the proposal and the line `Status: read-only proposal complete. Waiting for "apply" before any edit.`

The invoking agent (or the user) explicitly says "เริ่ม" / "start" / "apply" / "go ahead" / "fix it" to leave proposal mode. Even then, the agent — not this skill — performs the edits.

---

## When to Reference Other Skills

While proposing, if the audit surfaces:

- **Cross-feature consistency issues** (multiple pages disagree, not just this one) → recommend `react-audit` in multi-feature mode for a broader pass before applying this single-page revamp
- **Performance smells** (sequential awaits, missing memo, barrel imports, etc.) → flag them in **Best practices → Arch/Dev** and recommend running `react-perf` on the touched files
- **Architecture smells** (boolean-prop bloat on the page's components, inline component definitions, prop drilling) → recommend `react-composition`
- **Component CSS divergence** discovered across the page's children → recommend `react-dry`

Surface these as **recommendations**, not as additional proposal work. The user decides whether to invoke them.
