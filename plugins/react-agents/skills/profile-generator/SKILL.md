---
name: profile-generator
description: Interactively scaffold a project-specific Claude Code profile (implement/polish/pre-commit/test agent quartet) for any React 19 / Vite SPA. Auto-scans the project (package.json, filesystem, MD docs) to pre-fill ~25 placeholders, then asks the user only what can't be inferred (~5-12 questions for a typical scaffolded project). Substitutes the result into agent templates from the `react-agents` plugin and writes the filled-in profile to a user-specified path. The output is a self-contained plugin folder ready to symlink into `.claude/agents/` or publish as its own marketplace plugin.
license: MIT
user-invocable: true
metadata:
  version: "1.0.0"
  type: action
  status: stable
  derived_from: project-internal
  stack: Claude Code plugin marketplace
  scope: Project profile scaffolding
---

# profile-generator

Generate a project-specific Claude Code profile (filled-in agent trio + plugin manifest) from the `react-agents` templates.

## Pre-conditions (refuse if any missing)

This skill mutates the filesystem by writing a new plugin folder. Refuse to proceed unless ALL of the following are confirmed:

1. **`react-agents` plugin is installed** — templates must exist at `plugins/react-agents/templates/agents/*.template.md`. Verify with `Glob` before any prompt.
2. **Output path is empty or absent** — never overwrite an existing `plugins/<name>-profile/` folder. If it exists, ask user to confirm a different name or explicit overwrite intent.
3. **All required inputs resolved** — via auto-scan (Phase 1) or user answer (Phase 2). Never write a profile with placeholder defaults silently substituted; surface defaults during the scan/confirm round.
4. **PLACEHOLDER-REFERENCE.md exists** — `plugins/react-agents/docs/PLACEHOLDER-REFERENCE.md` is the source of truth for placeholder names. If absent, refuse and surface the broken install.

If any pre-condition fails, list the gap and stop without writing files.

A **missing conventions doc is NOT a refuse condition** — it triggers the case-2 seed (see "Conventions-doc resolution"). The generator guarantees a conventions doc exists post-gen rather than refusing.

## When to invoke

User runs `/profile-generator` after installing the `react-agents` plugin, or types a phrase like:

- "scaffold a profile for <my project>"
- "set up the agent trio for this repo"
- "generate <project>-profile"

## Phase 1 — Auto-scan project state

Before any `AskUserQuestion`, scan the project to pre-fill ~25 placeholders. Each scan is independent — if a scan fails (file missing, glob empty), defer that placeholder to Phase 2.

### Phase 1 ground rules

1. **Locate `package.json` first.** Search in this order: cwd → `*/package.json` (one-level subdirs) → `*/*/package.json` (two-level, for monorepo submodules). Set `PROJECT_ROOT` = directory containing the chosen `package.json`. If multiple found, **AskUserQuestion** with the candidates (list each with its `name` field for context). Do NOT silently pick.

2. **Path/command style — ask user when subdir is detected.** Compute `PROJECT_RELPATH` = relative path from cwd → PROJECT_ROOT.
   - If empty (cwd == PROJECT_ROOT): set `USE_PROJECT_PREFIX = false`, `CMD_PREFIX = ""`, `PATH_PREFIX = ""`. No question needed — bare style is the only sensible choice.
   - If non-empty: surface **AskUserQuestion** to pick path/command style BEFORE running Scan A/B:
     - **(a) Prefixed monorepo style (Recommended)** — paths get `<PROJECT_RELPATH>/` prefix, commands get `cd <PROJECT_RELPATH> && ` prefix. Agent invokable from any cwd. Best for monorepos / cross-project sessions.
     - **(b) Bare style** — paths and commands relative to PROJECT_ROOT (no prefix). User must `cd <PROJECT_RELPATH>` before invoking the agent. Best when user always works inside PROJECT_ROOT.
   - Set `USE_PROJECT_PREFIX = true` for (a), `false` for (b).
   - If `USE_PROJECT_PREFIX = true`: `CMD_PREFIX = "cd <PROJECT_RELPATH> && "`, `PATH_PREFIX = "<PROJECT_RELPATH>/"`.
   - If `USE_PROJECT_PREFIX = false`: `CMD_PREFIX = ""`, `PATH_PREFIX = ""`.
   - Surface in scan summary as `Path/command style: <a-monorepo | b-bare>` followed by example: `e.g. BUILD_CMD = <build-cmd>`.

3. **Multi-candidate disambiguation.** If any glob in Scan B returns >1 match (e.g. `CLAUDE.md` exists at both cwd and `<subdir>/CLAUDE.md`), surface as AskUserQuestion. Default to the one closer to PROJECT_ROOT.

4. **Curated lists, not auto-trim.** Scans that produce ranked candidates (POLISHED_PAGE_EXAMPLES, TEST_CANONICAL_FILES) must surface as preset-template AskUserQuestion in Phase 2 — do not silently pick first-N. See "Curated-list questions" below for the 3-preset mechanism.

### AskUserQuestion mechanics (important constraint)

The `AskUserQuestion` tool has hard limits:
- **Max 4 options per question** — cannot list 12+ candidates directly.
- **Max 4 questions per call** — but can batch independent questions in one call.
- `multiSelect: true` is supported but still subject to the 4-option limit.

Workarounds:
- For long candidate lists (>4): present **3 preset templates** as options, with "Customize" as the 3rd allowing free-form text input from the user.
- For dense Round 5 richness menu (12+ items): batch into 3 separate questions (4 items each) within a single `AskUserQuestion` call.
- Never include a "Crib sheet" preset in real-flow questions — that pattern is test-only (used by maintainer for Layer B validation against pps-web reference). End users have no crib sheet.

### Scan A — `package.json` (read from PROJECT_ROOT)

`Read` `<PROJECT_ROOT>/package.json`. Infer:

| Placeholder | From `package.json` field |
|---|---|
| `{{PROJECT_NAME}}` | `name` |
| `{{BUILD_CMD}}` | `CMD_PREFIX` + `npm run build` (or whatever script key exists for build) |
| `{{DEV_CMD}}` | `CMD_PREFIX` + `npm run dev` (or `start`) |
| `{{TEST_CMD}}` | `CMD_PREFIX` + `npm run test:unit` or `npm run test` (whichever exists) |
| `{{TEST_COV_CMD}}` | `CMD_PREFIX` + `npm run test:cov` or `npm run coverage` |
| `{{LINT_STRUCTURE_CMD}}` | `CMD_PREFIX` + `npm run lint:structure` (empty if script absent) |
| `{{LINT_STRUCTURE_CMD_STRICT}}` | `CMD_PREFIX` + `npm run lint:structure:strict` (empty if absent) |
| `{{STACK}}` | parse `dependencies` + `devDependencies`. Match by pattern: React major from `react`; bundler from `vite`/`webpack`/`turbopack`; css-lib from `tailwindcss`/`styled-components`/`emotion`; UI-lib by **prefix match** against `@radix-ui/*`, `@chakra-ui/*`, `@mantine/*`, `@nextui-org/*`, `@mui/*` (label as Radix UI / Chakra / Mantine / NextUI / MUI respectively). Render: `React <X> / TypeScript / <bundler> / <css-lib> / <ui-lib>` |
| `{{TEST_STACK}}` | parse `devDependencies` → `<vitest> + <@testing-library/react> + <@testing-library/user-event> + <msw>` with majors |

### Scan B — Filesystem (Glob + `ls`, from PROJECT_ROOT and cwd)

> Always **search** at `<PROJECT_ROOT>/...` (e.g. read `<PROJECT_ROOT>/CLAUDE.md`). The **rendered placeholder value** then prepends `PATH_PREFIX` (empty for bare style, `<PROJECT_RELPATH>/` for prefixed style). So for pps-web in a monorepo with prefixed style, `{{CONVENTIONS_DOC}}` becomes `pps-web/CLAUDE.md`. For bare style, it becomes `CLAUDE.md`.

| Placeholder | Search location | Rendered value | Multi-match handling |
|---|---|---|---|
| `{{CONVENTIONS_DOC}}` | `<PROJECT_ROOT>/CLAUDE.md` ∪ `<cwd>/CLAUDE.md` | `PATH_PREFIX` + `CLAUDE.md` | If both PROJECT_ROOT and cwd have one → AskUserQuestion to pick |
| `{{STRUCTURE_DOC}}` | `<PROJECT_ROOT>/docs/architecture/feature-structure.md` ∪ `docs/structure.md` | `PATH_PREFIX` + `docs/architecture/feature-structure.md` (or chosen variant) | First match wins (rare conflict) |
| `{{PROGRESS_DOC}}` | `<PROJECT_ROOT>/docs/progress.md` ∪ `progress.md` ∪ `STATUS.md` | `PATH_PREFIX` + matched filename | First match wins |
| `{{FEATURES_ROOT}}` | `<PROJECT_ROOT>/src/features/` ∪ `<PROJECT_ROOT>/src/modules/` | `PATH_PREFIX` + `src/features` (default) | First match |
| `{{TEST_INFRA_ROOT}}` | `<PROJECT_ROOT>/src/test/` ∪ `<PROJECT_ROOT>/test/` | `PATH_PREFIX` + `src/test` (default) | First match |
| `{{POLISH_AUDIT_SOURCE}}` | glob `<PROJECT_ROOT>/scripts/*polish*audit*.{mjs,js}` | `PATH_PREFIX` + matched path | First match |
| `{{ARCHITECTURE_DOCS_GLOB}}` | `<PROJECT_ROOT>/docs/architecture/*` if exists | `PATH_PREFIX` + `docs/architecture/*` | — |
| `{{COMPONENT_DOCS_GLOB}}` | `<PROJECT_ROOT>/docs/components/*` if exists | `PATH_PREFIX` + `docs/components/*` | — |
| `{{FEATURE_DOCS_GLOB}}` | `<PROJECT_ROOT>/docs/features/*` if exists | `PATH_PREFIX` + `docs/features/*` | — |
| `{{API_SERVICES_PATHS}}` | glob `<PROJECT_ROOT>/src/services/{api,http,case-transform}.ts` | comma-joined `PATH_PREFIX` + each path, backtick-wrapped | List all found |
| `{{TEST_UTILS_IMPORT}}` | if `<PROJECT_ROOT>/src/test/test-utils.tsx` exists → `@/test/test-utils` | **No prefix** (import alias is project-internal) | — |
| `{{I18N_LOCALES_PATH}}` | glob `<PROJECT_ROOT>/src/i18n/locales/en/*.json` | `PATH_PREFIX` + `src/i18n/locales/en/<feature>.json` | — |
| `{{TEST_CANONICAL_BASELINE}}` | scan `<FEATURES_ROOT>/*/` → folder with most `*.test.*` files | `PATH_PREFIX` + chosen folder path | — |
| `{{TEST_CANONICAL_FILES}}` | list `*.test.*` in baseline folder | each path prefixed with `PATH_PREFIX`, markdown bullet form | **Surface as preset-template** in Phase 2 — see "Curated-list questions" below |
| `{{BACKEND_NAME}}` | sibling dirs at cwd matching `<PROJECT_NAME>-{api,be,backend,server}` | matched name (e.g. `pps-api`); no path prefix | First match |

### Scan C — Script + MD content (Read + grep)

| Placeholder | Method |
|---|---|
| `{{CONV_SECTION_REF}}` | Read `{{CONVENTIONS_DOC}}` → detect how rules are identified (numbered like `MC-N`, or named sections). If the rules sit under a dedicated heading in a larger doc, render ` (its \`<heading>\` section)`; if the doc is a dedicated conventions file, leave empty (agents walk the whole file). Surface the detected rule identifiers in the Phase 1 summary (D-10). **No rule count is baked** — agents enumerate at runtime. |
| `{{POLISHED_PAGE_EXAMPLES}}` | **Primary**: Read `<POLISH_AUDIT_SOURCE>` → parse `PAGE_STATUS` map → grep `<PageName>:\s*['"]Polished['"]`. **Fallback** (if no audit script): Read `<PROGRESS_DOC>` → extract pages with `Polished` status. **Surface as preset-template** in Phase 2 — see "Curated-list questions" below. Never silently pick first-N. |

### Scan D — Derive

| Placeholder | From |
|---|---|
| `{{AGENT_PREFIX}}` | first hyphenated segment of `{{PROJECT_NAME}}` (e.g. `pps-web` → `web`); use whole name if ≤ 4 chars |
| `{{API_CLIENT_IMPORT}}` | `@/services/api` if API services paths found |
| `{{POLISH_AUDIT_CMD}}` | `node <POLISH_AUDIT_SOURCE>` |
| `{{POLISH_AUDIT_SCRIPT_REF}}` | `` ` + skim ` + ` `` + POLISH_AUDIT_SOURCE + `` ` `` + ` (` + `` ` `` + `PAGE_STATUS` + `` ` `` + ` map)` (empty if no audit script) |
| `{{REPORT_*_HDR}}` placeholders | derived from `{{OUTPUT_LANG}}` after Phase 2 Round 1 (see "Report-header derivation") |

### Conventions-doc resolution (run after Scan C)

The MC-walk machinery needs a readable conventions doc whose rules the agents enumerate **at runtime**. Split two decisions Scan B/C surface separately — *is there a doc?* and *can its rules be enumerated?* — then branch:

**Case 1 — doc found, rules enumerable.** Bind to its own scheme:
- numbered (`MC-N`, `CONV-N`, `R-N` — regex `([A-Z]+)-(\d+)`) → identifiers = the numbers found (no max; gaps are fine).
- named sections (headings under the conventions area) → identifiers = the section titles.
Set `{{CONV_SECTION_REF}}` per Scan C. **Show the detected identifiers in the scan summary** (D-10); add no extra question when unambiguous.

**Case 2 — no doc found.** Seed one (see "Stack-aware conventions seed"): write `<PROJECT_ROOT>/CONVENTIONS.md` from the starter taxonomy, examples grounded in the detected stack, framed as a draft. Set `{{CONVENTIONS_DOC}}` to it, `{{CONV_SECTION_REF}}` empty (whole file). Announce in the final report.

**Case 3 — doc found but rules not cleanly enumerable** (prose, fewer than ~2 rule-like items, or can't tell which headings are rules). Do NOT bind silently — `AskUserQuestion`:
- (a) point me at the rules section → re-scan that section
- (b) merge the 7-section starter to fill gaps → run the seed and merge
- (c) use as-is → MC-walk degrades to "walk whatever's there" (warn)

**Multi-file rules (D-9).** v1 supports a single doc. If the conventions doc links out to `docs/conventions/*.md` (rules likely span files), warn and ask the user to point at one consolidated doc or accept single-doc scoping. True multi-file support is deferred.

### Page-maturity resolution (run after Scan B)

Agents anchor on a known-good **reference page**. Whether the project tracks *page maturity* (a status model like Polished/Rough/Partial) is optional:

**Has a maturity model** — a progress/status doc with maturity labels detected (or user says so):
- `{{REFERENCE_PAGE_TERM}}` = the project's "good" label (e.g. `Polished`).
- `{{ANTI_REFERENCE_CLAUSE}}` = ` — never anchor on <bad-labels> pages` (e.g. ` — never anchor on Rough/Partial pages`).
- `{{POLISH_STATUS_REPORT_BLOCK}}` = the flip/regression report block — kept only if a page-status audit script exists (same gate as `{{POLISH_STATUS_CHECK_SECTION}}`).

**No maturity model** — `{{REFERENCE_PAGE_TERM}}` = `reference`; `{{ANTI_REFERENCE_CLAUSE}}` = empty; `{{POLISH_STATUS_REPORT_BLOCK}}` = empty (stripped). The user still names reference pages → `{{POLISHED_PAGE_EXAMPLES}}` (curated-list question worded "reference pages"). The anchor-on-a-good-reference discipline stays; only the maturity overlay drops.

Show the resolved `{{REFERENCE_PAGE_TERM}}` in the scan summary (D-10 style).

### Scan summary presentation

After scan, present a single markdown block summarizing detected values:

```
🔍 Auto-detected project setup

Project: <name> (from package.json at <PROJECT_ROOT>/package.json)
Path/command style: <a-monorepo | b-bare>  (e.g. BUILD_CMD = <build-cmd>)
Stack: <stack>
Test stack: <test-stack>

Commands:
- Build: <build-cmd>
- Dev: <dev-cmd>
- Test: <test-cmd>  (coverage: <test-cov-cmd>)
- Lint structure: <lint-cmd>  (strict: <strict-cmd>)

Paths:
- Conventions doc: <conventions-doc>  (rules detected: <list identifiers, e.g. `MC-1..MC-7` or section names — or "none: will seed">)
- Structure doc: <structure-doc>
- Progress doc: <progress-doc>
- Features root: <features-root>
- Test infra: <test-infra>
- Polish audit script: <polish-audit-source>

Test setup:
- Canonical baseline folder: <baseline-folder>  (<N> test files found — exact files picked in Phase 2)
- API client import: <api-client-import>
- Test utils import: <test-utils-import>
- i18n locales: <i18n-locales-path>

Backend (sibling): <backend-name>
API services: <api-services-paths>

Polished pages found: <N> pages (selection happens in Phase 2 — preset-template choice)
```

If cwd == PROJECT_ROOT, the `Path/command style:` line is implicitly bare — omit or note as `bare (cwd == PROJECT_ROOT)`.

**Multi-candidate disambiguation** — if Scan B's CONVENTIONS_DOC found multiple `CLAUDE.md` files, surface BEFORE the summary block via AskUserQuestion. Same for any other multi-match. Lock in the user's choice, THEN present the summary.

Then `AskUserQuestion`:

> Use these auto-detected values?
> - ✓ Yes, all correct
> - 🛠️ Edit specific items
> - ↻ Start over — ask manually

If "Edit specific items": user lists which placeholders to override + new values. Apply overrides, re-present summary.

## Phase 2 — Ask user-only (skip what scan inferred)

Group the remaining questions into 6 rounds. Skip any whose value Phase 1 already pre-filled (unless user asked to override). Default each so accepting blindly works for a typical React 19 / Vite app.

Question wording: plain, with concrete examples. Show auto-detected/default value if any. Never ask a question whose answer is already known.

### Curated-list questions (mandatory, not optional)

For two placeholders the scan produces a ranked candidate list, not a final value. AskUserQuestion's 4-option limit (see "AskUserQuestion mechanics") means we cannot list 12+ candidates directly — use **3 preset-template options** instead. The scanner runs heuristics to pre-compute each preset's content, then the user picks which preset to use (or Customize for free-form override).

1. **`{{POLISHED_PAGE_EXAMPLES}}`** (the reference pages agents anchor on) — present detected reference pages (your `{{REFERENCE_PAGE_TERM}}` pages, up to 16) as `markdown context block` (visible above the question), then ask via `AskUserQuestion` with 3 options:
   - **(a) Balanced by role (Recommended)** — pre-compute 4-6 pages balanced across roles. Use page-name heuristics:
     - ends with `ListPage` → list
     - ends with `DetailPage` → detail
     - ends with `ConfigPage` / `SettingsPage` → config
     - ends with `FormShell` / `Form` → form (or pages with `Form` infix on uniqueness)
     - ends with `OverviewPage` / `DashboardPage` → overview/dashboard
     Pick one per role, in role priority: list → detail → config → form → overview. Surface the role assignment in the option description.
   - **(b) All N detected** — render all detected pages (cap at 12 for readability). Useful when project is small or user wants comprehensive examples.
   - **(c) Customize** — user types comma-separated list. Validator: each token must match a detected page name (case-sensitive), else reject + reprompt.

2. **`{{TEST_CANONICAL_FILES}}`** — present detected `*.test.*` files (grouped by layer) as `markdown context block`, then ask via `AskUserQuestion` with 3 options:
   - **(a) One per layer (Recommended)** — pre-compute one file per layer. Use path heuristics:
     - `*/schemas/*.test.*` → schema
     - `*/api/*.test.*` → api
     - `*/hooks/*.test.*` → hook
     - `*/components/*.test.*` → component
     - `*/integration/*.test.*` or top-level `*.test.tsx` → integration
     Pick first file per layer found (alphabetical).
   - **(b) All N files** — render every detected test file. Best for canonical baselines with rich layer coverage (e.g. holiday/ in pps-web has 10 tests across 4 layers).
   - **(c) Customize** — user types comma-separated list of relative paths.

3. **Crib sheet preset (test-only, do NOT offer to end users)** — when running Layer B validation against a known reference project (e.g. pps-web), maintainer can override the preset by editing the substitution dict directly. This is NOT a 4th option in the AskUserQuestion. End users never see it.

Present these AFTER Phase 1 confirm + Round 1 (identity/language), so the user is in question-answering mode. They do NOT belong in the Phase 1 auto-scan summary.

### Round 1 — Identity confirm + output language

If scan succeeded, just confirm. Otherwise ask.

1. **Project name** — short name used in agent descriptions.
   - Auto-detected: `<scanned>` from `package.json` `name`
   - Override only if you want a display name different from package name.

2. **Agent prefix** — short tag prepended to agent names (e.g. `<prefix>-implement`).
   - Auto-derived: first hyphenated segment of project name (`pps-web` → `web`, `my-app` → `my-app`)
   - Override if you want a custom prefix.

3. **Output language** — what language should agents report in?
   - `AskUserQuestion` with **2 options**: `English` (default) · `Thai`. The tool's built-in "Other" slot takes a free-text language name.
   - If the user picks "Other" (any language that is not English or Thai), enter the non-en/th flow: during the summary step prompt once for each of the 9 Report-header values (see "Report-header derivation"). Never silently fall back to English — that would mix languages in the rendered Report block.
   - Affects: `<prefix>-implement`, `<prefix>-polish`, `<prefix>-test` reports
   - Note: `<prefix>-pre-commit` is always English

### Round 2 — Apply trigger (1 ask)

4. **Apply keyword** — the single word user types to give the agent "go-ahead" to apply changes.
   - Examples: `apply` (English default), `เริ่ม` (Thai), `start`, `do it`, `go`

5. **Apply aliases** — extra words also accepted as apply (optional).
   - Format: trailing list starting with ` / `
   - Default: ` / \`apply\` / \`go ahead\``
   - Project can extend: ` / \`start\` / \`apply\` / \`go ahead\``

### Round 3 — Backend / API (skip whole round if FE-only)

If Phase 1 found no sibling backend repo AND user has no Swagger URL → skip.

6. **Backend API-contract URL** — full URL to your backend's contract doc (Swagger / OpenAPI UI, or a GraphQL schema endpoint).
   - Leave empty for frontend-only projects.
   - Example: `https://api.example.com/swagger-ui/`
   - **Contract name** (report wording) — defaults to `Swagger`; set e.g. `OpenAPI` or `GraphQL schema` for non-Swagger backends. Fills `{{API_CONTRACT_NAME}}`.

7. **BE-scope trigger keywords** (only if Swagger given) — phrases that turn on the backend API-shape check while implementing.
   - Default: `check BE, verify BE, sync api types, contract check`
   - Multi-language allowed; agent does case-insensitive substring match.
   - Example for Thai project: add `เช็ค BE, เช็ค swagger`

### Round 4 — Trigger keywords for agents (1 ask, optional)

These define what user phrases should invoke each agent. Defaults work for English-only projects.

8. **Polish triggers** — phrases that invoke `<prefix>-polish`.
   - Default: `"clean up", "DRY up X", "align features X, Y, Z", "polish diff"`
   - Project may add multi-language variants.

9. **Test triggers** — phrases that invoke `<prefix>-test`.
   - Default: `"write tests for X", "test for X", "expand coverage X", "expand tests X", "fill test gaps X", "integration test X", "test flow X"`
   - Project may extend.

### Round 5 — Optional richness (menu — skip all = generic defaults)

Present a checklist via `AskUserQuestion` `multiSelect`. Each picked item = 1 follow-up question to gather its value. Skip all → all placeholders use generic defaults.

> Acronyms used below: **MC** = Mandatory Conventions (your project's enforceable rules — see "Conventions-doc resolution"). **BP** = Best Practices.

```
Add project-specific richness? Pick what applies (skip all = generic):

[ ] Structure rules: new-file checklist  ({{STRUCTURE_PREWRITE_TABLE}})
    Map of "when creating file kind X, follow which doc section".

[ ] Structure rules: extraction map  ({{STRUCTURE_EXTRACT_MAPPING}})
    Map of "when extracting X (schema, section), follow which doc section".

[ ] Convention-walk reminder  ({{MC_WALK_INCIDENT_REF}})
    A past bug that justifies walking every rule strictly — shown as a reminder in the agent.

[ ] Plan-file path convention  ({{PLAN_FILE_PATTERN}})
    Where draft plans get saved (e.g. `session-working-space/tasks/*-plan.md`).

[ ] Linter → rule mapping  ({{MC_MECHANICAL_CATCH_MAP}})
    Which conventions your structure linter already catches automatically.

[ ] Commit scope examples  ({{COMMIT_SCOPE_OPTIONS}})
    Project-specific scope hints (e.g. `(web)` / `(api)`).

[ ] Backlog / pending-work reference  ({{STRUCTURE_LEGACY_REF}} + {{STRUCT_PENDING_RULES}})
    Where your backlog lives + how pending work is tracked.

[ ] Workflow regression check table  ({{WORKFLOW_PATTERNS_TABLE}})
    Key components/hooks each mature page must keep (used by the pre-commit gate).

[ ] Best-practice examples for reports  ({{BP_APPLIED_UX}} + {{BP_APPLIED_ARCH}})
    Concrete UX / architecture patterns to cite in revamp-scope reports.

[ ] Page-maturity signals  ({{POLISH_STATUS_CHECK_SECTION}})
    When a page counts as "done" + what regresses it (only if a page-status audit script exists).

[ ] Polish/Test mode triggers  ({{POLISH_MODE_ROWS}} + {{TEST_MODE_ROWS}})
    Override default trigger phrases (e.g. add localized phrases).

[ ] API URL pattern  ({{MSW_URL_PATTERN}})
    Your project's API URL convention (used for test mocks).

[ ] Mutation hook test scenarios  ({{MUTATION_SCENARIOS}})
    Project rules for cache-invalidation / multi-tenant tests.

[ ] API trigger surface  ({{API_TRIGGER_HINT}})
    A phrase describing what "an API-touching change" looks like in your project.
```

### Round 6 — Output (1 ask, 2 questions)

10. **Output folder** — absolute path to write the profile.
    - Default: `$HOME/Workspace/<project-name>-profile`

11. **Profile description** — one sentence for plugin.json marketplace listing.
    - Default: `<Project> profile: implement/polish/pre-commit/test subagents`

After Round 6: summarize all resolved values in a single markdown block and ask **one** final confirmation before writing.

> **Primitive guidance is adaptive — no separate UI inventory skill is generated.** Agents read `<docs-root>/components/<X>.md` → `<docs-root>/architecture/design-system.md` → `src/components/ui/<X>.tsx` source. Keeps primitives in sync with the codebase automatically.

## Substitution rules

Apply these placeholder mappings to each template file. Use Read + Edit (replace_all=true) per placeholder. Whitespace must match exactly.

**Blank-line hygiene (multi-line optional blocks).** When a placeholder that spans multiple lines is substituted (e.g. `{{STRUCT_PENDING_RULES}}`, `{{POLISH_STATUS_CHECK_SECTION}}`, `{{POLISH_STATUS_REPORT_BLOCK}}`, `{{STRUCTURE_PREWRITE_TABLE}}`, `{{WORKFLOW_PATTERNS_TABLE}}`), collapse any resulting run of blank lines to a single blank — both when the block is **filled** (its content may carry a trailing blank) and when it is **empty** (the surrounding blanks would otherwise double up). After writing each agent file, scan for `\n\n\n` and squeeze to `\n\n`.

| Placeholder | Replacement | Notes |
|---|---|---|
| `{{PROJECT_NAME}}` | answer 1 | |
| `{{AGENT_PREFIX}}` | answer 2 | |
| `{{STACK}}` | answer 3 | implement + polish description only |
| `{{TEST_STACK}}` | answer 3b (test-stack one-liner, e.g. `Vitest 4 + React Testing Library 16 + @testing-library/user-event 14 + MSW 2`) | default: `Vitest + React Testing Library + MSW` |
| `{{OUTPUT_LANG}}` | answer 4 | |
| `{{BACKEND_NAME}}` | answer 4b (backend project/repo name; default `backend`) | rendered backticked inline; if user types `none` keep template wording `backend` |
| `{{CONVENTIONS_DOC}}` | answer 5 | |
| `{{CONV_SECTION_REF}}` | derived in Scan C (empty for a dedicated whole-file conventions doc) | renders as ` (its \`<heading>\` section)` or empty string |
| `{{STRUCTURE_DOC}}` | answer 7 (or `<conventions-doc>` if empty — keep references coherent) | |
| `{{PROGRESS_DOC}}` | answer 8 (or `<conventions-doc>` if empty) | |
| `{{FEATURES_ROOT}}` | answer 9 | |
| `{{POLISHED_PAGE_EXAMPLES}}` | answer 10 (or `{{REFERENCE_PAGE_TERM}} pages in <progress-doc>` if empty) | |
| `{{ARCHITECTURE_DOCS_GLOB}}` | `<answer 11>/architecture/*` (empty if answer 11 empty — drop row from docs-update table) | |
| `{{COMPONENT_DOCS_GLOB}}` | `<answer 11>/components/*` (empty if answer 11 empty) | |
| `{{FEATURE_DOCS_GLOB}}` | `<answer 11>/features/*` (empty if answer 11 empty) | |
| `{{BUILD_CMD}}` | answer 12 | |
| `{{DEV_CMD}}` | answer 13 | (currently unused in templates — reserved) |
| `{{TEST_CMD}}` | answer 14 | |
| `{{LINT_STRUCTURE_CMD}}` | answer 15 | |
| `{{LINT_STRUCTURE_CMD_STRICT}}` | answer 16 | |
| `{{POLISH_AUDIT_SCRIPT_REF}}` | `` ` + skim ` + `` ` ``+ answer 17 +` ` `` ` + ` (` + `` ` ``+`PAGE_STATUS`+`` ` ``+` map)` (empty string if answer 17 empty) | backtick-wrap both the script path AND `PAGE_STATUS` |
| `{{POLISH_STATUS_CHECK_SECTION}}` | render full Polish-status block (see below) if answer 17 non-empty; else empty string | |
| `{{POLISH_AUDIT_CMD}}` | `cd <project> && node <relative-path-from-project-root>` derived from answer 17 (empty if answer 17 empty) | only referenced inside `{{POLISH_STATUS_CHECK_SECTION}}` |
| `{{POLISH_AUDIT_SOURCE}}` | answer 17 verbatim (empty if answer 17 empty) | |
| `{{REFERENCE_PAGE_TERM}}` | page-maturity resolution: project's "good" page label (default `Polished`); `reference` if no maturity model | |
| `{{ANTI_REFERENCE_CLAUSE}}` | page-maturity resolution: ` — never anchor on <bad-labels> pages` (default ` — never anchor on Rough/Partial pages`); empty if no maturity model | leading ` — ` separator preserved |
| `{{POLISH_STATUS_REPORT_BLOCK}}` | the flip/regression report block (see "POLISH_STATUS_REPORT_BLOCK template") if a page-status audit script exists; else empty string | gated identically to `{{POLISH_STATUS_CHECK_SECTION}}` |
| `{{SWAGGER_URL}}` | answer 18 | |
| `{{API_CONTRACT_NAME}}` | answer 18b (default `Swagger`; e.g. `OpenAPI` / `GraphQL schema`) | report-wording term for the contract source |
| `{{BE_KEYWORDS_PRIMARY}}` | answer 19 first half | |
| `{{BE_KEYWORDS_SECONDARY}}` | answer 19 second half | split at commas, group |
| `{{API_SERVICES_PATHS}}` | answer 20 with each path backtick-wrapped (e.g. `` `a`, `b`, `c` ``); empty if FE-only | gate then lists feature `api/*` files only |
| `{{TEST_COV_CMD}}` | answer 21 | |
| `{{TEST_INFRA_ROOT}}` | answer 22 | |
| `{{TEST_CANONICAL_BASELINE}}` | answer 23 (empty → template renders an empty "Canonical baseline" section; agent falls back to in-repo conventions) | trailing `/` preserved |
| `{{TEST_CANONICAL_FILES}}` | answer 24 (multi-line markdown bullet list, indentation = 0 spaces, one `- \`path\`` per line) | |
| `{{APPLY_KEYWORD}}` | answer 25 | |
| `{{APPLY_KEYWORD_ALIASES}}` | answer 25b — trailing alias suffix beginning with ` / `, default ` / `` `apply` `` ` / `` `go ahead` ``  | comma-separated alias list user types → render each backticked, joined by ` / `, prefixed with ` / ` |
| `{{POLISH_TRIGGER_KEYWORDS}}` | answer 25c — comma-separated quoted triggers for polish description (multi-language allowed) | default: `"clean up", "DRY up X", "align features X, Y, Z", "polish diff"` |
| `{{POLISH_SCOPE_NOTE}}` | answer 25d — optional parenthetical clarifier in polish description (or empty) | default empty |
| `{{TEST_TRIGGER_KEYWORDS}}` | answer 25e — comma-separated quoted triggers for test description (multi-language allowed) | default: `"write tests for X", "test for X", "expand coverage X", "expand tests X", "fill test gaps X", "integration test X", "test flow X"` |
| Report-block headers (`{{REPORT_NOTES_HDR}}`, `{{REPORT_PENDING_HDR}}`, `{{REPORT_HANDOFF_VERB}}`, `{{REPORT_BUILD_VERB}}`, `{{REPORT_OR_REASON}}`, `{{REPORT_FILES_HDR}}`, `{{REPORT_SKIP_HDR}}`, `{{REPORT_IFANY_SUFFIX}}`, `{{REPORT_PENDING_NONE}}`) | derived from `{{OUTPUT_LANG}}` — see "Report-header derivation" below | |

### Report-header derivation (OUTPUT_LANG-driven)

For each of the 9 Report-header placeholders, look up the value from this table. If `OUTPUT_LANG` is not English or Thai, prompt the user once for each value during the summary step; never silently fall back to English (the result would mix languages in the rendered Report block).

| Placeholder | English | Thai |
|---|---|---|
| `{{REPORT_NOTES_HDR}}` | `Notes (if any)` | `Notes (ถ้ามี)` |
| `{{REPORT_PENDING_HDR}}` | `Pending / need confirm` | `ค้าง / ต้อง confirm` |
| `{{REPORT_HANDOFF_VERB}}` | `Hand off to` | `ส่งต่อ` |
| `{{REPORT_BUILD_VERB}}` | `passed` | `ผ่าน` |
| `{{REPORT_OR_REASON}}` | `or ❌ + reason` | `หรือ ❌ + เหตุผล` |
| `{{REPORT_FILES_HDR}}` | `Files touched` | `ไฟล์ที่แตะ` |
| `{{REPORT_SKIP_HDR}}` | `Skip (if any)` | `Skip (ถ้ามี)` |
| `{{REPORT_IFANY_SUFFIX}}` | ` (if any)` | ` (ถ้ามี)` |
| `{{REPORT_PENDING_NONE}}` | `none` | `ไม่มี` |

### Stack-aware conventions seed (case 2)

When no conventions doc exists, write `<PROJECT_ROOT>/CONVENTIONS.md` from the 7-section taxonomy in `react-core/docs/CONVENTIONS.template.md`, filling each section's **examples** from already-detected / normative signals — never guessed from code usage. Phrase rules as **candidates to confirm**, not settled rules.

| Section | Fill examples from |
|---|---|
| HTML & a11y | ESLint a11y plugin presence; else generic defaults |
| Input primitives & variants | UI lib in `{{STACK}}` (Radix / MUI / Chakra / Mantine / shadcn) |
| Tables | UI lib table primitive if any; else generic |
| Modal vs Drawer | UI lib dialog/drawer primitives |
| Forms & validation | form lib (RHF / Formik) + schema lib (zod / yup) from `package.json` |
| i18n & cross-feature | i18n lib + locales from `{{I18N_LOCALES_PATH}}` |
| Logging & error handling | logger dep if any; toast lib; ESLint `no-console` rule |

The seeded file's header states: *starter draft — agents walk these before every report; edit to match your team.* If the deps/config scan yields nothing usable, fall back to copying `CONVENTIONS.template.md` verbatim (option A). Either way a doc exists post-gen, so the runtime MC-walk has something to read.

### POLISH_STATUS_CHECK_SECTION template

If answer 17 is non-empty, expand `{{POLISH_STATUS_CHECK_SECTION}}` to:

```markdown
## Polish-status check (pre-commit mode only — when diff touches pages)

**Mode gate**: this check runs in **pre-commit mode only**. In diff-review mode, skip the audit script entirely.

If pre-commit mode AND any `{{FEATURES_ROOT}}/*/pages/*Page/` is in diff:

1. Run `{{POLISH_AUDIT_CMD}}` (source: `{{POLISH_AUDIT_SOURCE}}`)
2. For each touched page, compare verdict against signal score:
   - **Flip candidate** — page is `Rough`/`Partial` AND signals hit Polished bar. Surface as flip suggestion.
   - **Regression** — page is `Polished` AND a signal dropped. **Blocking.**
3. **Never auto-flip** status or `{{PROGRESS_DOC}}`. Propose only.
```

Substitute the inner placeholders too, then drop in.

### POLISH_STATUS_REPORT_BLOCK template

If a page-status audit script exists (answer 17 non-empty), expand `{{POLISH_STATUS_REPORT_BLOCK}}` to the report subsection below; otherwise render an empty string (drop it from the `## Report` block):

```markdown
## Polish status (if pages touched)
- Flip candidates: <Page> Rough → {{REFERENCE_PAGE_TERM}}? (3/5 → 5/5)   (in pre-commit mode: reply `yes flip` to update)
- Regressions: <Page> {{REFERENCE_PAGE_TERM}} → ⚠️ (signal X dropped)
- (or "no page changes")
```

### Edge cases in substitution

- **Empty Swagger URL** (answer 18): strip the entire `### 0.0 BE-scope gate` section from `implement.template.md` and the `## {{API_CONTRACT_NAME}} drift gate` section from `pre-commit.template.md`. Replace with a 1-line note: `BE-scope / API-contract drift gates: not configured (no contract URL).`
- **Empty lint:structure** (answer 15): strip `## Shared lint:structure run` and `## Structure regression check` sections from `pre-commit.template.md`. Inline a 1-line note in their place.
- **Empty docs root** (answer 11): the three `{{*_DOCS_GLOB}}` placeholders render empty; the generator should drop the corresponding rows from the `## Docs update` table in `pre-commit.template.md` (otherwise the table has empty cells).
- **Empty `{{API_SERVICES_PATHS}}`** (answer 20): the `{{API_CONTRACT_NAME}}` drift gate bullet "Project's shared HTTP client / API service / case-transform" disappears — gate triggers only on per-feature `api/*` and network-wrapping hooks.
- **Empty test baseline** (answers 23 + 24): `test.template.md` renders with an empty Canonical baseline section. The agent still works (falls back to in-repo conventions), but the user should fill in baseline files once their first feature has good tests.
- **No page-maturity model** (page-maturity resolution): `{{REFERENCE_PAGE_TERM}}` = `reference`, `{{ANTI_REFERENCE_CLAUSE}}` = empty, `{{POLISH_STATUS_REPORT_BLOCK}}` = empty (drop the `## Polish status` subsection from the `## Report` block in `pre-commit.template.md`). Agents still anchor on user-named reference pages — only the Polished/Rough/Partial overlay drops.

## Output structure

Write the following tree under the user's chosen output folder:

```
<output>/
├── .claude-plugin/
│   └── plugin.json          # filled from Round 1 + 5
├── README.md                # boilerplate explaining what was generated + how to install
└── agents/
    ├── <prefix>-implement.md   # filled template
    ├── <prefix>-polish.md
    ├── <prefix>-pre-commit.md
    └── <prefix>-test.md
```

No `skills/` folder is generated — primitive guidance is adaptive (agents read project docs + source directly).

### plugin.json template

```json
{
  "name": "<project>-profile",
  "version": "0.1.0",
  "description": "<from answer 22>",
  "author": { "name": "<git config user.name or 'TBD'>" },
  "license": "MIT",
  "keywords": ["claude-code", "claude-agent", "<project>"]
}
```

### README.md template

```markdown
# <project>-profile

Generated by [claude-kit](https://github.com/G3Ner8/claude-kit) `profile-generator` on <date>.

## What this is

Project-specific agent trio for `<project>`:

- `<prefix>-implement` — code builder + API debugger
- `<prefix>-polish` — cleanup + consistency
- `<prefix>-pre-commit` — pre-commit gate (build verify, docs sync, commit draft)
- `<prefix>-test` — test writer (Vitest + RTL + MSW) for retrofit / expand / integration modes

## Install

### Symlink (recommended for active dev)

\`\`\`bash
cd "$(git rev-parse --show-toplevel)"
mkdir -p .claude/agents
for a in <prefix>-implement <prefix>-polish <prefix>-pre-commit <prefix>-test; do
  ln -s "<output-path>/agents/$a.md" ".claude/agents/$a.md"
done
\`\`\`

### Plugin marketplace (if this folder becomes its own repo)

Initialize as a git repo, push to GitHub, then in any Claude Code session:

\`\`\`
/plugin marketplace add <owner>/<project>-profile
/plugin install <project>-profile@<project>-profile
\`\`\`

## Customizing

Edit `agents/*.md` directly. Re-running `profile-generator` will overwrite — back up first.

## License

MIT
```

## Procedure

When invoked:

1. **Verify** access to `react-agents` plugin templates. Read from the plugin install location.

2. **Phase 1 — Auto-scan**:
   - Run Scan A (`package.json`), Scan B (filesystem), Scan C (MD content), Scan D (derive).
   - Compose a single markdown summary of all detected values.
   - Ask via `AskUserQuestion`: "Use these auto-detected values?" → Yes / Edit specific / Start over.
   - If "Edit specific", let user override; re-present summary; loop until "Yes".

3. **Phase 2 — Ask user-only** (skip questions whose values came from Phase 1):
   - Round 1: identity confirm + output language (skip confirms if Phase 1 succeeded; ask only language)
   - Round 2: apply trigger (keyword + aliases)
   - Round 3: backend (skip whole round if Phase 1 found no backend AND user has no Swagger URL)
   - Round 4: trigger keywords for polish + test (offer defaults; user can extend)
   - Round 5: optional richness menu (`multiSelect` checklist; each picked item → 1 follow-up question)
   - Round 6: output folder + profile description
   - Validate answers as collected.

4. **Summarize + final confirm**:
   - Present all resolved values (scanned + answered) in a single markdown block.
   - Show absolute output path.
   - `AskUserQuestion`: "Write the profile?" → Yes / Adjust.

5. **Write**: if Conventions-doc resolution landed on **case 2**, first write the seeded `<PROJECT_ROOT>/CONVENTIONS.md` (see "Stack-aware conventions seed"). Then read each template via `Read`, perform substitutions (repeated `Edit` with `replace_all=true`), write result via `Write` to target. Handle conditional sections (BE-scope, Polish-status, lint:structure) before writing — strip whole sections when their gate is empty.

6. **Report**: print absolute paths of all created files + symlink install snippet from README. If a conventions doc was seeded (case 2), say so explicitly: "No conventions doc found — seeded `<PROJECT_ROOT>/CONVENTIONS.md` as a draft; the agents walk it before every report, so edit it to match your team." Remind user to `git init` + push if they want to publish as marketplace plugin.

### Typical question count (for reference)

| Project type | Phase 1 scan | Phase 2 ask | Total |
|---|---|---|---|
| Standard Vite React project, fully scaffolded | ~25 inferred | ~5-7 asks (language + apply + output) | ~5-7 questions |
| Frontend-only project (no BE) | ~22 inferred | ~5-7 asks | ~5-7 |
| Greenfield project (minimal scaffolding) | ~10 inferred | ~10-12 asks (more manual fill) | ~10-12 |
| Project with rich custom conventions | ~25 inferred | ~7-9 asks + 3-5 richness | ~10-14 |

Previous spec asked all 28-50 questions sequentially. New spec scans first → asks only what's not detectable.

## Do NOT

- Write outside the user-specified output folder.
- Modify the `react-agents` template files themselves.
- Skip the final confirmation step.
- Auto-`git init` or auto-push the generated folder — leave that to the user.
- Generate files in a folder that already exists with content, unless user confirms overwrite.

## Edge cases

- **Output folder exists and contains files** — ask user: overwrite, write into subfolder, or abort.
- **User wants to regenerate** — back up `agents/` to `agents.bak.<timestamp>/` before overwriting.
- **Some questions left blank** — fall back to defaults; do not error.
- **User declines at final confirmation** — print the answers verbatim so they can copy-paste back, and exit without writing.
- **Templates missing from install** — print path that was searched and tell user to reinstall `react-agents` plugin.
