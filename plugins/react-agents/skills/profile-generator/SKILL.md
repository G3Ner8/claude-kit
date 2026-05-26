---
name: profile-generator
description: Interactively scaffold a project-specific Claude Code profile (implement/polish/pre-commit/test agent quartet + optional UI inventory stub) for any React 19 / Vite SPA. Auto-scans the project (package.json, filesystem, MD docs) to pre-fill ~25 placeholders, then asks the user only what can't be inferred (~5-12 questions for a typical scaffolded project). Substitutes the result into agent templates from the `react-agents` plugin and writes the filled-in profile to a user-specified path. The output is a self-contained plugin folder ready to symlink into `.claude/agents/` or publish as its own marketplace plugin.
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

## When to invoke

User runs `/profile-generator` after installing the `react-agents` plugin, or types a phrase like:

- "scaffold a profile for <my project>"
- "set up the agent trio for this repo"
- "generate <project>-profile"

## Phase 1 — Auto-scan project state

Before any `AskUserQuestion`, scan the project to pre-fill ~25 placeholders. Each scan is independent — if a scan fails (file missing, glob empty), defer that placeholder to Phase 2.

### Scan A — `package.json`

`Read` the project's `package.json`. Infer:

| Placeholder | From `package.json` field |
|---|---|
| `{{PROJECT_NAME}}` | `name` |
| `{{BUILD_CMD}}` | `scripts.build` (prepend `npm run` if missing) |
| `{{DEV_CMD}}` | `scripts.dev` or `scripts.start` |
| `{{TEST_CMD}}` | `scripts['test:unit']` ∪ `scripts.test` |
| `{{TEST_COV_CMD}}` | `scripts['test:cov']` ∪ `scripts.coverage` |
| `{{LINT_STRUCTURE_CMD}}` | `scripts['lint:structure']` (empty if absent) |
| `{{LINT_STRUCTURE_CMD_STRICT}}` | `scripts['lint:structure:strict']` (empty if absent) |
| `{{STACK}}` | parse `dependencies` → `<React-major> / TS / <bundler> / <css-lib> / <ui-lib>` (e.g. `React 19 / TS / Vite / Tailwind / Radix`) |
| `{{TEST_STACK}}` | parse `devDependencies` → `<vitest> + <RTL> + <user-event> + <msw>` with majors |

### Scan B — Filesystem (Glob + `ls`)

| Placeholder | Check / glob |
|---|---|
| `{{CONVENTIONS_DOC}}` | `CLAUDE.md` (default if found) |
| `{{STRUCTURE_DOC}}` | `docs/architecture/feature-structure.md` ∪ `docs/structure.md` |
| `{{PROGRESS_DOC}}` | `docs/progress.md` ∪ `progress.md` ∪ `STATUS.md` |
| `{{FEATURES_ROOT}}` | `src/features/` ∪ `src/modules/` (default `src/features`) |
| `{{TEST_INFRA_ROOT}}` | `src/test/` ∪ `test/` (default `src/test`) |
| `{{POLISH_AUDIT_SOURCE}}` | glob `scripts/*polish*audit*.{mjs,js}` |
| `{{ARCHITECTURE_DOCS_GLOB}}` | `docs/architecture/*` if exists (else empty) |
| `{{COMPONENT_DOCS_GLOB}}` | `docs/components/*` if exists |
| `{{FEATURE_DOCS_GLOB}}` | `docs/features/*` if exists |
| `{{API_SERVICES_PATHS}}` | glob `src/services/{api,http,case-transform}.ts` → backtick-wrap each, comma-join |
| `{{TEST_UTILS_IMPORT}}` | if `src/test/test-utils.tsx` exists → `@/test/test-utils` |
| `{{I18N_LOCALES_PATH}}` | glob `src/i18n/locales/en/*.json` → `src/i18n/locales/en/<feature>.json` |
| `{{TEST_CANONICAL_BASELINE}}` | scan `{{FEATURES_ROOT}}/*/` → folder with most `*.test.*` files |
| `{{TEST_CANONICAL_FILES}}` | list `*.test.*` in baseline folder, markdown bullet form |
| `{{BACKEND_NAME}}` | sibling dirs matching `<project>-{api,be,backend,server}` (default `backend`) |

### Scan C — Script + MD content (Read + grep)

| Placeholder | Method |
|---|---|
| `{{MC_MAX}}` | Read `{{CONVENTIONS_DOC}}` → grep `MC-([0-9]+)` → take max |
| `{{POLISHED_PAGE_EXAMPLES}}` | **Primary**: Read `{{POLISH_AUDIT_SOURCE}}` → parse `PAGE_STATUS` map → grep `<PageName>:\s*['"]Polished['"]`. **Fallback** (if no audit script): Read `{{PROGRESS_DOC}}` → extract pages with `Polished` status. Then backtick + comma-join. Default: first 6 in source-file order — **but note this is arbitrary**; surface to user as "Suggested 6 of N — override to pick representative roles (list/detail/config/form)". |

### Scan D — Derive

| Placeholder | From |
|---|---|
| `{{AGENT_PREFIX}}` | first hyphenated segment of `{{PROJECT_NAME}}` (e.g. `pps-web` → `web`); use whole name if ≤ 4 chars |
| `{{API_CLIENT_IMPORT}}` | `@/services/api` if API services paths found |
| `{{POLISH_AUDIT_CMD}}` | `node <POLISH_AUDIT_SOURCE>` |
| `{{POLISH_AUDIT_SCRIPT_REF}}` | `` ` + skim ` + ` `` + POLISH_AUDIT_SOURCE + `` ` `` + ` (` + `` ` `` + `PAGE_STATUS` + `` ` `` + ` map)` (empty if no audit script) |
| `{{UI_INVENTORY_SKILL}}` | check claude-kit installed plugins for `<project>-ui` style skill |
| `{{REPORT_*_HDR}}` placeholders | derived from `{{OUTPUT_LANG}}` after Phase 2 Round 1 (see "Report-header derivation") |

### Scan summary presentation

After scan, present a single markdown block summarizing detected values:

```
🔍 Auto-detected project setup

Project: <name> (from package.json)
Stack: <stack>
Test stack: <test-stack>

Commands:
- Build: <build-cmd>
- Dev: <dev-cmd>
- Test: <test-cmd>  (coverage: <test-cov-cmd>)
- Lint structure: <lint-cmd>  (strict: <strict-cmd>)

Paths:
- Conventions doc: <conventions-doc>  (<MC-count> MC sections found)
- Structure doc: <structure-doc>
- Progress doc: <progress-doc>
- Features root: <features-root>
- Test infra: <test-infra>
- Polish audit script: <polish-audit-source>

Test setup:
- Canonical baseline: <baseline-folder>  (<N> test files)
- API client import: <api-client-import>
- Test utils import: <test-utils-import>
- i18n locales: <i18n-locales-path>

Backend (sibling): <backend-name>
API services: <api-services-paths>

Polished pages found: <polished-pages>
```

Then `AskUserQuestion`:

> Use these auto-detected values?
> - ✓ Yes, all correct
> - 🛠️ Edit specific items
> - ↻ Start over — ask manually

If "Edit specific items": user lists which placeholders to override + new values. Apply overrides, re-present summary.

## Phase 2 — Ask user-only (skip what scan inferred)

Group the remaining questions into 6 rounds. Skip any whose value Phase 1 already pre-filled (unless user asked to override). Default each so accepting blindly works for a typical React 19 / Vite app.

Question wording: plain, with concrete examples. Show auto-detected/default value if any. Never ask a question whose answer is already known.

### Round 1 — Identity confirm + output language

If scan succeeded, just confirm. Otherwise ask.

1. **Project name** — short name used in agent descriptions.
   - Auto-detected: `<scanned>` from `package.json` `name`
   - Override only if you want a display name different from package name.

2. **Agent prefix** — short tag prepended to agent names (e.g. `<prefix>-implement`).
   - Auto-derived: first hyphenated segment of project name (`pps-web` → `web`, `my-app` → `my-app`)
   - Override if you want a custom prefix.

3. **Output language** — what language should agents report in?
   - Choose: English · Thai · Japanese · other (free text)
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

6. **Backend Swagger URL** — full URL to your backend's Swagger UI.
   - Leave empty for frontend-only projects.
   - Example: `https://api.example.com/swagger-ui/`

7. **BE-scope trigger keywords** (only if Swagger given) — phrases that opt-in the backend-contract check during implement sessions.
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

```
Add project-specific richness? Pick what applies (skip all = generic):

[ ] Structure pre-write check table  ({{STRUCTURE_PREWRITE_TABLE}})
    Project's "new file kind → required-section" mapping table.

[ ] Structure extraction mapping  ({{STRUCTURE_EXTRACT_MAPPING}})
    Project's "extraction kind → section" bullet list.

[ ] MC walk incident reference  ({{MC_WALK_INCIDENT_REF}})
    Past incident that motivates strict MC walk (forcing function context).

[ ] Plan-file path convention  ({{PLAN_FILE_PATTERN}})
    Where draft plans get saved (e.g. `session-working-space/tasks/*-plan.md`).

[ ] lint:structure → MC mapping  ({{MC_MECHANICAL_CATCH_MAP}})
    Which MC sections the structure linter mechanically catches.

[ ] Commit scope examples  ({{COMMIT_SCOPE_OPTIONS}})
    Project-specific scope hints (e.g. `(pps-web)` / `(pps-api)`).

[ ] Pending-list / backlog reference  ({{STRUCTURE_LEGACY_REF}} + {{STRUCT_PENDING_RULES}})
    Project's "Section 17 backlog" style + pending-list workflow.

[ ] Workflow regression check table  ({{WORKFLOW_PATTERNS_TABLE}})
    Canonical components/hooks per Polished page (used by pre-commit gate).

[ ] BPapplied bullet examples  ({{BP_APPLIED_UX}} + {{BP_APPLIED_ARCH}})
    Concrete UX/Arch patterns for revamp-scope reports.

[ ] Polish-status signal definitions  ({{POLISH_STATUS_CHECK_SECTION}})
    Flip thresholds + signal-drop examples (only if polish audit script configured).

[ ] Polish/Test Mode-table rows  ({{POLISH_MODE_ROWS}} + {{TEST_MODE_ROWS}})
    Override default Mode-table triggers (e.g. add Thai trigger phrases).

[ ] MSW URL pattern  ({{MSW_URL_PATTERN}})
    Your project's API URL convention.

[ ] Mutation hook scenarios  ({{MUTATION_SCENARIOS}})
    Project's tenant/cache invalidation test rules.

[ ] API trigger surface  ({{API_TRIGGER_HINT}})
    Phrase describing what API surface touched looks like.
```

### Round 6 — Output (1 ask, 3 questions)

10. **Output folder** — absolute path to write the profile.
    - Default: `$HOME/Workspace/<project-name>-profile`

11. **Profile description** — one sentence for plugin.json marketplace listing.
    - Default: `<Project> profile: implement/polish/pre-commit/test subagents`

12. **UI inventory skill name** (optional) — if your project ships a UI primitive inventory skill.
    - Default: empty (no UI inventory configured)
    - Example: `pps-ui`

After Round 6: summarize all resolved values in a single markdown block and ask **one** final confirmation before writing.

## Substitution rules

Apply these placeholder mappings to each template file. Use Read + Edit (replace_all=true) per placeholder. Whitespace must match exactly.

| Placeholder | Replacement | Notes |
|---|---|---|
| `{{PROJECT_NAME}}` | answer 1 | |
| `{{AGENT_PREFIX}}` | answer 2 | |
| `{{STACK}}` | answer 3 | implement + polish description only |
| `{{TEST_STACK}}` | answer 3b (test-stack one-liner, e.g. `Vitest 4 + React Testing Library 16 + @testing-library/user-event 14 + MSW 2`) | default: `Vitest + React Testing Library + MSW` |
| `{{OUTPUT_LANG}}` | answer 4 | |
| `{{BACKEND_NAME}}` | answer 4b (backend project/repo name; default `backend`) | rendered backticked inline; if user types `none` keep template wording `backend` |
| `{{CONVENTIONS_DOC}}` | answer 5 | |
| `{{MC_MAX}}` | answer 6 | |
| `{{STRUCTURE_DOC}}` | answer 7 (or `<conventions-doc>` if empty — keep references coherent) | |
| `{{PROGRESS_DOC}}` | answer 8 (or `<conventions-doc>` if empty) | |
| `{{FEATURES_ROOT}}` | answer 9 | |
| `{{POLISHED_PAGE_EXAMPLES}}` | answer 10 (or `Polished pages in <progress-doc>` if empty) | |
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
| `{{SWAGGER_URL}}` | answer 18 | |
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
| `{{UI_INVENTORY_SKILL}}` | answer 26 | wrap in backticks: `` `<name>` `` |
| `{{UI_INVENTORY_REF}}` | `, ` + UI_INVENTORY_SKILL if non-empty; else empty string | inline list separator |
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

### Edge cases in substitution

- **Empty Swagger URL** (answer 18): strip the entire `### 0.0 BE-scope gate` section from `implement.template.md` and the `## Swagger drift gate` section from `pre-commit.template.md`. Replace with a 1-line note: `BE-scope / Swagger drift gates: not configured (no Swagger URL).`
- **Empty lint:structure** (answer 15): strip `## Shared lint:structure run` and `## Structure regression check` sections from `pre-commit.template.md`. Inline a 1-line note in their place.
- **Empty UI inventory** (answer 26): replace `{{UI_INVENTORY_SKILL}}` with `(no UI inventory skill configured)` and remove the `{{UI_INVENTORY_REF}}` entry from skill-invocation tables.
- **Empty docs root** (answer 11): the three `{{*_DOCS_GLOB}}` placeholders render empty; the generator should drop the corresponding rows from the `## Docs update` table in `pre-commit.template.md` (otherwise the table has empty cells).
- **Empty `{{API_SERVICES_PATHS}}`** (answer 20): the Swagger drift gate bullet "Project's shared HTTP client / API service / case-transform" disappears — gate triggers only on per-feature `api/*` and network-wrapping hooks.
- **Empty test baseline** (answers 23 + 24): `test.template.md` renders with an empty Canonical baseline section. The agent still works (falls back to in-repo conventions), but the user should fill in baseline files once their first feature has good tests.

## Output structure

Write the following tree under the user's chosen output folder:

```
<output>/
├── .claude-plugin/
│   └── plugin.json          # filled from Round 1 + 5
├── README.md                # boilerplate explaining what was generated + how to install
├── agents/
│   ├── <prefix>-implement.md   # filled template
│   ├── <prefix>-polish.md
│   ├── <prefix>-pre-commit.md
│   └── <prefix>-test.md
└── skills/                  # only if UI inventory skill name was provided
    └── <ui-inventory>/
        ├── SKILL.md         # empty stub with TODOs
        └── README.md        # instructions to fill in primitive inventory
```

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
mkdir -p .claude/agents .claude/skills
for a in <prefix>-implement <prefix>-polish <prefix>-pre-commit <prefix>-test; do
  ln -s "<output-path>/agents/$a.md" ".claude/agents/$a.md"
done
# Skill (if generated):
ln -s "<output-path>/skills/<ui-inventory>" ".claude/skills/<ui-inventory>"
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

### UI inventory stub (SKILL.md)

```markdown
---
name: <ui-inventory>
description: Inventory of <project>'s UI primitives and "don't roll your own" decision rules. Use whenever writing, reviewing, or refactoring <project> React code to pick the right primitive instead of rolling custom markup.
license: MIT
user-invocable: true
metadata:
  version: "0.1.0"
  derived_from: project-internal
  stack: <stack>
  scope: <project>-specific
---

# <ui-inventory>

TODO: Inventory all primitives in your `src/components/ui/` (or equivalent).

## Section A — Anti-patterns (don't roll your own)

TODO list common cases where developers typically hand-roll markup when a primitive exists:
- Modal vs Drawer choice rule
- Select vs Combobox choice rule
- Toast vs Alert choice rule

## Section B — Inventory

Group primitives by category (Buttons, Inputs, Layout, Feedback, Navigation, Data display, Overlays, Pickers).

| Primitive | Path | Use when | Don't use when |
|---|---|---|---|
| `Button` | `src/components/ui/button.tsx` | ... | ... |

See claude-kit's `pps-ui` skill for a complete worked example.
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
   - Round 6: output folder + profile description + UI inventory skill name
   - Validate answers as collected.

4. **Summarize + final confirm**:
   - Present all resolved values (scanned + answered) in a single markdown block.
   - Show absolute output path.
   - `AskUserQuestion`: "Write the profile?" → Yes / Adjust.

5. **Write**: read each template via `Read`, perform substitutions (repeated `Edit` with `replace_all=true`), write result via `Write` to target. Handle conditional sections (BE-scope, Polish-status, lint:structure) before writing — strip whole sections when their gate is empty.

6. **Report**: print absolute paths of all created files + symlink install snippet from README. Remind user to `git init` + push if they want to publish as marketplace plugin.

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
