---
name: react-dry
description: Audit every usage of one or more UI components across a codebase. Find CSS/style/class divergence, magic numbers, design-token bypasses, and a11y/state-parity gaps. Produces a comparison table of variants seen across call sites — discuss findings BEFORE planning detailed fixes. Use when asked to "audit Button usages", "standardize Table styles across pages", "DRY up our Card components", or invoked as `/react-dry`. Read-only — findings table first, never edits without explicit approval.
license: MIT
user-invocable: true
metadata:
  version: "1.0.0"
  derived_from: project-internal (was: legacy unify agent)
  stack: framework-agnostic procedure; examples target React 19 + Tailwind codebases
  scope: Read-only component-usage audit
---

# React Component DRY Audit

Audit every call site of one or more UI components — find divergence in CSS / classes / styles / a11y / state handling — produce a **findings table** that the user discusses with you BEFORE you propose a detailed plan.

The value of this audit is in the **variance across instances**, not in the source file alone. The more components you audit at once, the better the cross-component patterns surface.

Output flow:

1. Discover all usage sites
2. Produce findings table (this skill ends here)
3. **Stop and wait** — user discusses, narrows down what they want fixed
4. Only then propose a detailed execution plan (next round)
5. Only after user approves the plan does any agent edit code

---

## Step 1 — Gather Inputs (MANDATORY before any work)

Do not Read, Glob, or Grep until you have **all** the required inputs. Use `AskUserQuestion` to collect them in one call. Wait for the response.

Required:

1. **Components to audit** — accept one or more. Acceptable forms:
   - Component names (`Button`, `Table`, `Dialog`)
   - Import paths (`@/components/ui/Button`, `src/features/employee/components/EmployeeCard`)
   - Mix of both

   If a name maps to multiple components, list candidates back and ask the user which one(s). If only one component is given, ask once: "Want to add more? Cross-component patterns surface better with a wider net." — then proceed regardless of answer.

2. **Codebase root for usage search** — where to grep for usage sites (e.g. `src/**`, `apps/web/src/**`). Default to the repo's `src/` if not specified.

3. **Design tokens location** — auto-detect (look for `tailwind.config.*`, `tokens.css`, design-system docs) and confirm with user, or accept an explicit path. The tokens are the standard the audit measures against.

Conditional:

4. **Output language** — `English` or `Thai`. **Ask this** when auditing ≥ 2 components or when the codebase is large (likely > 20 usage sites total). Default to English otherwise.

Stop and wait until all required inputs are answered.

---

## Step 2 — Locate (per component)

For each component in the input list:

- Find the **source file** — `Glob` for the component definition, confirm with `Grep "export.*<Name>"`.
- Find **every import and JSX usage** across the codebase root.
- Note the **count of usage sites**. If long (> 10), sample 5–10 representative sites — pick a spread (early files + recent files + different features).
- Read each sampled site enough to extract its className/style/prop usage.

Build a per-component usage list before moving on.

---

## Step 3 — Audit Phases

Run all three phases for each component. Use `Read`, `Glob`, `Grep`, `Bash` (query commands only). No edits.

### Phase A — CSS standardization (DRY)

For each component, look across its usage sites for:

- **className variants** — list the distinct class clusters seen. Are 2–3 clusters that look like "primary / secondary / muted" candidates to bake into the component as a `variant` prop?
- **Inline styles** — any `style={{...}}` should be a smell. Flag and identify what they're trying to do.
- **Magic numbers in classes** — `mt-[13px]`, `text-[#3a3a3a]`, `w-[247px]`. Flag every one; suggest the nearest token.
- **Tailwind classes that bypass tokens** — e.g. `text-gray-500` when the project has `text-text-secondary`; `bg-red-50` when there's `bg-error-bg`.
- **Repeated class clusters** — same long className appearing in 3+ call sites is a candidate for extraction (variant prop, utility class, or wrapper component).

### Phase B — Visual alignment

For each component, across its usage:

- **Typography** — font size + weight + line-height variance. Should all instances use the same? Flag every divergence vs design tokens.
- **Spacing** — margin / padding rhythm across usage sites. Token-based? Consistent?
- **Colors** — text / icon / background / border. Semantic tokens or raw values?
- **Motion** — hover / focus / transition durations + easing. Uniform across instances?
- **Match against design language** — does each instance feel like the same component, or do older usages feel "off"?

### Phase C — Other UI inconsistencies

- **A11y** — missing `aria-label` on icon-only buttons, missing labels on inputs, focus visibility, keyboard nav gaps, missing `aria-*` for interactive states
- **Behavior split** — same component rendered for visually different purposes (e.g. `<Button>` used as a link vs an action)?
- **Component overlap** — different components used for the same purpose across call sites?
- **Dead variants** — props / variants that no call site uses
- **Loading / empty / error state parity** — do all usages handle these the same way? If some sites omit a state, flag it.

---

## Step 4 — Output the findings TABLE (and STOP)

End your turn with **just** the discovery + findings table. **Do not** write a detailed execution plan yet — wait for the user to discuss.

```
# Component Audit: <component list>

## Discovery
- Resolved sources:
  - `<ComponentA>` → `<source path>` — <N> usage sites
  - `<ComponentB>` → `<source path>` — <N> usage sites
- Codebase scanned: <root>
- Tokens detected at: <path>
- Sampled usage sites: <M> per component (or "all" if usage count is small)

## Findings table

| Component | Concern | Variants seen | Files (sample) | Recommendation | Severity |
|---|---|---|---|---|---|
| Button | className for primary | 4 variants (`bg-blue-500`, `bg-brand-700`, `bg-primary`, custom hex) | a.tsx:12, b.tsx:45, c.tsx:9 | Extract `variant="primary"` with canonical classes | High |
| Button | text size | `text-sm` vs `text-base` mixed | d.tsx:30, e.tsx:14 | Standardize to `text-label-md` per design tokens | Med |
| Button | icon-only missing aria-label | 7 instances | f.tsx:18, g.tsx:42, ... | Add `aria-label` on icon-only Button | High (a11y) |
| Table | header background | `bg-gray-50`, `bg-white`, `bg-[#fafafa]` | h.tsx:6, i.tsx:21, j.tsx:9 | Use `bg-surface-muted` token | High |
| Table | row spacing | `py-2` / `py-3` / `py-4` mixed | k.tsx:55, l.tsx:18, m.tsx:33 | Standardize to `py-3` per density token | Med |
| Card | padding | inline `p-4` vs `p-6` vs no padding | n.tsx:12, o.tsx:8 | Move padding to component; expose `density` prop | Med |
| ... | ... | ... | ... | ... | ... |

(Only include rows where a real divergence/issue exists. Skip clean concerns.)

## Cross-component themes
- <pattern-level issue 1 — e.g. "Spacing magic numbers (`mt-[Xpx]`) are widespread across older files">
- <pattern-level issue 2 — e.g. "Inline color hex appears in 6 places; tokens exist for all of them">
- <pattern-level issue 3 — e.g. "Icon-only buttons missing aria-label is a repeating a11y gap, not just one component">

---

Status: read-only audit complete. Findings ready for discussion.

Next: discuss this table with the user. Once you agree on which concerns to address, I (or the invoking agent) will produce a detailed execution plan in commit-sized chunks. No edits will happen until that plan is approved.
```

Then stop. Wait for the user to either:

- Pick rows to address ("fix High-severity rows" or "address Button concerns only")
- Ask clarifying questions about specific findings
- Reject some findings as intentional
- Tell you to proceed with a plan

Only when the user gives a clear direction do you proceed to plan production — and even then, the plan is a proposal, not an execution.

---

## Stop Conditions (READ-ONLY discipline)

This skill is **read-only by design**. After producing the findings table:

- Do not run `Edit`, `Write`, `NotebookEdit`, or any modification.
- Do not stage / commit / push.
- Do not jump straight to a detailed execution plan — table is the deliverable, plan comes after user discussion.
- End the turn with the table and the line `Status: read-only audit complete. Findings ready for discussion.`

The invoking agent (or the user) explicitly indicates which concerns to address and says "plan it" / "apply" / "go ahead" / "ลุย". The detailed plan, then the edits, are separate steps.

---

## When to Reference Other Skills

While auditing, if the findings surface:

- **Cross-feature pattern issues** (the divergence isn't per-component, it's per-feature) → recommend `react-audit` in multi-feature mode
- **Performance anti-patterns in the component itself** (inline component definitions inside its parent, prop bloat) → recommend `react-perf` (re-render rules) and `react-composition` (architecture)
- **Page-level redesign needed** (audit shows a single page has so much divergence the component-level fix won't work alone) → recommend `react-revamp`

Surface these as **lines under "Cross-component themes"** or appended notes — not as additional audit work.
