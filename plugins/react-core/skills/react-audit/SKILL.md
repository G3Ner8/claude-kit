---
name: react-audit
description: Read-only audit of one or more frontend feature folders against canonical baseline features. Single-mode (one target → per-area findings) or multi-mode (multiple targets → divergence matrix). Phases: Navigation → UI Components → Visuals → optional API. Use for "audit feature X", "check feature X against baseline", "align features X, Y, Z", or "consistency audit". Produces findings + execution plan; no edits without explicit approval.
license: MIT
user-invocable: true
metadata:
  version: "1.0.0"
  derived_from: project-internal (consolidates legacy inspect + align agents)
  stack: framework-agnostic procedure; examples target React 19 codebases
  scope: Read-only audit
---

# React Feature Audit

Audit a frontend feature folder (or set of folders) against canonical baseline features. Report consistency issues in **navigation, UI components, visuals, and API** — propose a surgical execution plan — then **stop and wait** for explicit "apply" approval before any edit happens.

Three modes, detected from the input shape:

| Mode | Trigger | Output focus |
|---|---|---|
| **Single-feature** | 1 target folder | Per-area findings + plan |
| **Multi-feature** | 2+ target folders | Divergence matrix + winner per row + plan |
| **Visual-consistency** | A primitive name (e.g. `Button`, `Card`) + a list of pages/files where it's used | Per-usage variant table + winner appearance + migration plan |

Single-feature and Multi-feature share Phases A-D; Multi-feature adds Phase E (cross-feature matrix). Visual-consistency uses its own Phase B' (cross-page primitive scan) instead of A-D — see Step 3 below.

---

## Step 1 — Gather Inputs (MANDATORY before any audit work)

Do not Read, Glob, Grep, or run any scan command until you have **all** the answers below. Use `AskUserQuestion` to collect them in one call. Wait for the response.

First detect mode from the user's framing:
- If user named a **primitive** (`Button`, `Card`, `Table`, etc.) plus pages → **Visual-consistency mode**, ask the visual-consistency inputs below.
- Otherwise → **Single/Multi-feature mode**, ask the feature inputs below.

### Inputs for Single/Multi-feature mode

1. **Target feature folders** — accept 1+ paths or names (e.g. `src/features/leave`, or "leave, attendance, timesheet"). Resolve names to concrete folder paths and confirm the resolved list back to the user before continuing.
2. **Baseline / reference feature folders** — the source-of-truth features the targets get compared against (e.g. `src/features/employee`, `src/features/payroll`). If the user doesn't know, suggest 1–2 candidates after a quick `Glob` of `src/features/`.
3. **Check API?** — `yes` or `no`. If yes, also ask for the API doc URL (Swagger / OpenAPI) or local OpenAPI spec path.
4. **Design tokens location** — auto-detect (look for `tailwind.config.*`, `tokens.css`, design-system docs) and confirm with user, or accept an explicit path.

### Inputs for Visual-consistency mode

1. **Primitive name** — the component to audit appearance for (e.g. `Button`, `Card`, `Table`, `Dialog`). Must resolve to a single component file.
2. **Page/file list** — explicit list of pages or files where the primitive is used (≥3 recommended). If user says "all", `Grep` for usages and present the list back for confirmation before scanning.
3. **Baseline page** — which page in the list (or external) defines the canonical look. Default: pick the highest-status `Polished` page from the list.
4. **Design tokens location** — auto-detect (`tailwind.config.*`, `tokens.css`) and confirm.

Conditional input (ask only if the audit will likely produce a long report):

5. **Output language** — `English` or `Thai` (Thai = ภาษาไทย). Default to English unless the user specifies otherwise. **Ask this when:** multi-feature mode, OR single-feature mode with >5 expected findings, OR if the user previously expressed a language preference in the conversation.

Stop and wait until all required inputs are answered.

---

## Step 2 — Orient

Once inputs are confirmed:

- `Glob` each target's top-level structure (depth 2 is enough for a map).
- `Glob` baseline parallels so you know what "good" looks like.
- Locate the design tokens — read the relevant lines of `tailwind.config.*` or the tokens file. Note which tokens exist so Phase C (Visuals) can flag bypasses.
- Read 1–2 reference files per area (page header component, list table component, dialog wrapper) — just enough to recognize the patterns.

Do not yet start writing findings. This step is calibration only.

---

## Step 3 — Audit Phases

**For Single/Multi-feature mode**: run phases A through E for **every** target.
**For Visual-consistency mode**: run **Phase B'** instead (see below); skip A, C, D, E.

Use `Read`, `Glob`, `Grep` only — no edits.

> **Why Phase E was added (2026-05-19):** prior single/multi-feature audits ran only A–D and missed micro-violations — HTML nesting, NumberInput variants, table action button standards, schema-i18n factory pattern, cross-feature i18n namespace, console-error vs logger. The org-config revamp audit returned a clean A–D pass and the user's follow-up sweep found 18 high/med findings. Phase E is the explicit enumeration that catches those.

### Phase A — Navigation

For each target, compare against the baseline:

- **Page header** — same component used? Title / description / actions slot positions match?
- **URL paths** — naming convention (kebab-case, plural vs singular, depth) matches the baseline?
- **Breadcrumbs** — registered? Labels go through i18n? Hierarchy mirrors the route shape?
- **Back navigation** — pattern matches (built-in back button vs explicit, `backTo` prop, etc.)?

### Phase B — UI Components

For each of the following, check that the target's usage matches the baseline (variant, size, icon placement, density):

- **Buttons** — variants used, icon placement, loading states (`LoadingButton` vs inline spinner)
- **Tables** — header style, row density, font tokens, sticky header, action column shape
- **Empty states** — illustration vs icon, copy structure, CTA presence and position
- **Dialog / Modal / Confirm** — size, header / footer pattern, button order, destructive-action treatment
- **Drawer / Sheet** — when used vs Dialog, width, header / scroll-body / footer structure
- **Combobox / Select** — trigger style, empty state, async loading pattern
- **Input / Form fields** — label wiring (`htmlFor` auto via Field?), error placement, disabled / required indicators

Flag every divergence with `file:line` precision when possible.

### Phase C — Visuals

For each target, audit:

- **i18n coverage** — every user-visible string goes through the project's i18n helper. Grep for raw string literals in JSX and flag them.
- **Typography** — font family, scale, weight come from design tokens (no `text-[16px]`, no `font-['Inter']` inline).
- **Spacing** — margin/padding from tokens, not magic numbers (`mt-[13px]`, `gap-[7px]` etc.).
- **Colors** — text / icon / background / border from semantic tokens, not raw hex or generic Tailwind grays (`text-gray-500` when the project has `text-text-secondary`).
- **Motion** — transition durations and easing match the project's vocabulary (consistent `duration-X`, no `transition: all`).

### Phase D — API correctness (only if user opted in)

For each target:

- List every network call (search for the project's `fetch` / query / mutation patterns).
- For each call: method, path, request shape, response handling, error path.
- Cross-check against the API doc (Swagger / OpenAPI) — verify shapes match.
- Verify case conversion (snake↔camel) uses the project helper, not ad-hoc.
- Flag: swallowed errors, missing loading / empty / error UI, requests bypassing the project query layer, stale-closure dependencies in effects.

If the user opted **out** of API check, explicitly say "Phase D skipped" in the report.

> **Note:** Phase D is a static check (shapes / conversion / error handling visible in code). If a runtime API failure is suspected ("call isn't firing", "no data returns", "no error surfaces"), escalate to the `web-implement` agent's **Debug Protocol** (BE-first via Swagger → BE code → FE chain → strategic logs). Do not try to debug runtime behavior inside this audit.

### Phase E — Micro-conventions (mandatory after A–D)

**Source of truth: your project's mandatory-conventions doc** (commonly `CLAUDE.md` or `CONVENTIONS.md`, sectioned as `MC-1` through `MC-N`). A reference template ships at `claude-kit/plugins/react-core/docs/CONVENTIONS.template.md` (7 sections: HTML/a11y, Inputs, Tables, Modal/Drawer, Forms, i18n, Logging). Phases A–D catch architecture and visual divergence; Phase E catches the per-element violations that pass architectural review but ship broken behavior. Do NOT re-enumerate the rules here — read the conventions doc (auto-loaded into context if it's `CLAUDE.md`).

Procedure per target:
1. **Walk MC-1..MC-N** from the conventions doc against the target's files. For each section, scan for violations and cite both the file:line of the violation and the conventions-doc line of the rule.
2. **Group findings by MC-N** in the output table.
3. **Report all MC-N lines** even when clean — `MC-N: ✓ (no violations, ref <conventions-doc>:<line>)`. The walk is the discipline.
4. **Mechanical pre-pass (if available)**: if your project ships a structure linter (e.g. `npm run lint:structure`), mentally run it — its checks usually overlap with the Forms / i18n / Logging conventions and will fire before audit reports.

### Phase B' — Cross-page primitive scan (Visual-consistency mode only)

For the named primitive on the user's page list:

1. `Read` the primitive's source file in full (e.g. `src/components/ui/button.tsx`) — list all variants/sizes/props that affect appearance.
2. `Read` the baseline page in full — record the canonical usage shape (variant, size, icon placement, density token, surrounding wrapper).
3. For each target page in the list:
   - `Grep` every usage of the primitive in that page (including its child components).
   - For each usage, record: variant, size, icon presence + placement, density classes (padding/gap), wrapping markup, any inline-className overrides.
4. Build a matrix:
   - Rows = each usage instance (page + line)
   - Columns = the appearance dimensions (variant, size, icon, density, wrapper, override)
   - Cell = the recorded value
5. Identify the **winner row** (matches baseline) and flag every diverging row.

Output the matrix in the Visual-consistency report template (Step 5).

---

## Step 4 — Multi-feature Consolidation (multi-mode only)

If you have ≥ 2 target features, after running Phases A–D **per feature**, produce a **divergence matrix**:

- Rows = audit concerns (page header, table style, button variants, dialog footer order, spacing scale, color tokens used, i18n coverage, etc.)
- Columns = one per target feature + one for the baseline
- Cells = short verdict per (concern × feature)
- Final column = **Winner** — which feature's choice should the others migrate to (usually the baseline's)

Only include rows where a **real divergence exists**. Skip rows where all targets and the baseline agree.

After the matrix, list **cross-feature themes** — patterns that repeat across multiple targets (e.g. "spacing magic numbers are widespread", "raw color hex is common in older files").

---

## Step 5 — Output

### Single-feature output template

```
# Audit: <feature path>

## Inputs
- Target: <path>
- Baseline: <paths>
- API check: <yes/no>
- Tokens detected at: <path>

## A. Navigation
- <finding> (file:line) — diverges from <baseline>: <how>
- ...

## B. UI Components
- Buttons: ...
- Tables: ...
- Empty states: ...
- Dialog / Drawer: ...
- Combobox / Select: ...
- Inputs / Forms: ...

## C. Visuals
- i18n: ...
- Typography: ...
- Spacing: ...
- Colors: ...
- Motion: ...

## D. API
<findings, or "Phase D skipped per user request">

## E. Micro-conventions (MC-1..MC-N)

Source: your project's mandatory-conventions doc (`CLAUDE.md` / `CONVENTIONS.md`). Findings table grouped by MC-N below; status line per MC mandatory. The example status lines below use the default 7-section template (`docs/CONVENTIONS.template.md`) — swap names to match your project.

| # | Sev | MC | File:Line | Finding | Conv-doc ref | Suggested fix |
|---|---|---|---|---|---|---|
| 1 | High | MC-N | … | … | CLAUDE.md:NN | … |

Status (all sections mandatory; example shown for the 7-section default template):
- MC-1 HTML & a11y: ✓ ref <doc>:<line>   |   ⚠ N findings
- MC-2 Inputs & variants: ✓ ref <doc>:<line>   |   ⚠ ...
- MC-3 Tables: ✓ ref <doc>:<line>   |   ⚠ ...
- MC-4 Modal vs Drawer: ✓ ref <doc>:<line>   |   ⚠ ...
- MC-5 Forms & validation: ✓ ref <doc>:<line>   |   ⚠ ...
- MC-6 i18n & cross-feature: ✓ ref <doc>:<line>   |   ⚠ ...
- MC-7 Logging & errors: ✓ ref <doc>:<line>   |   ⚠ ...

---

## Proposed execution plan
1. <ordered, surgical step naming files + change>
2. ...

Estimated touch: <N files>.
Status: read-only audit complete. Waiting for "apply" before any edit.
```

### Visual-consistency output template

```
# Visual Consistency Audit: <PrimitiveName>

## Inputs
- Primitive: `<PrimitiveName>` (source: `<path>`)
- Pages scanned: <list>
- Baseline page: <path> — <why this is canonical>
- Tokens at: <path>

## Appearance dimensions
- Variants in source: <list>
- Sizes in source: <list>
- Density tokens: <list>

## Usage matrix
| Usage (file:line) | Variant | Size | Icon | Density | Wrapper | Override | Status |
|---|---|---|---|---|---|---|---|
| BaselinePage.tsx:LL | primary | md | leading | px-4 py-2 | Card | none | ✅ Winner |
| TargetA.tsx:LL | primary | sm | trailing | px-3 py-1 | div | className="rounded-lg" | ⚠️ diverges |
| ...

## Divergences
- <usage> — <which dimension differs from baseline + 1-line why it matters>

## Cross-page themes
- <pattern that repeats across diverges, e.g. "Older list pages use `size=sm` for row actions; baseline uses `size=icon`">

---

## Proposed execution plan (commit-sized chunks)
1. <Chunk — files + change> — ~LOC, risk: low/med/high
2. ...

Estimated total touch: <N files>.
Status: read-only audit complete. Waiting for "apply" before any edit.
```

### Multi-feature output template

```
# Consistency Audit: <feature list>

## Inputs
- Targets: <paths>
- Baseline: <paths>
- API check: <yes/no>
- Tokens detected at: <path>

## Divergence matrix
| Concern | feat A | feat B | feat C | Baseline | Winner |
|---|---|---|---|---|---|
| Page header | ... | ... | ... | ... | ... |
| Table header style | ... | ... | ... | ... | ... |
| Button variants | ... | ... | ... | ... | ... |
| Dialog footer order | ... | ... | ... | ... | ... |
| Spacing scale | ... | ... | ... | ... | ... |
| Color tokens | ... | ... | ... | ... | ... |
| i18n coverage | ... | ... | ... | ... | ... |
| ... | | | | | |

(Only include rows where a real divergence exists.)

## Findings by feature
### <feat A>
- ...

### <feat B>
- ...

## Cross-feature themes
- <pattern-level issues that repeat across the set>

---

## Proposed execution plan (commit-sized chunks)
1. <Chunk — files + change> — ~LOC, risk: low/med/high
2. ...

Estimated total touch: <N files>.
Status: read-only audit complete. Waiting for "apply" before any edit.
```

---

## Stop Conditions (READ-ONLY discipline)

This skill is **read-only by design**. After producing the report:

- Do not run `Edit`, `Write`, `NotebookEdit`, or any modification.
- Do not stage / commit / push.
- End the turn with the report and the line `Status: read-only audit complete. Waiting for "apply" before any edit.`

The invoking agent (or the user) explicitly says "apply" / "go ahead" / "fix it" / "ลุย" to leave audit mode. Even then, the agent — not this skill — performs the edits.

---

## When to Reference Other Skills

While auditing, if you encounter:

- **Performance smells** (unnecessary re-renders, missing memoization, sequential awaits, barrel imports) → recommend running `react-perf` against the touched files
- **Architecture smells** (boolean-prop bloat, inline component definitions, `forwardRef` in React 19, prop drilling) → recommend `react-composition`
- **Component CSS inconsistencies** (same component rendered with different classes / tokens across files) → recommend `react-dry`

Surface these as **recommendations in the report**, not as additional audit work. The user decides whether to invoke them.
