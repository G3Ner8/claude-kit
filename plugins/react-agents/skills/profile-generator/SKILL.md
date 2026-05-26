---
name: profile-generator
description: Interactively scaffold a project-specific Claude Code profile (build/polish/pre-commit agent trio + optional UI inventory stub) for any React 19 / Vite SPA. Reads agent templates from the `react-agents` plugin, gathers project facts via AskUserQuestion, substitutes placeholders, and writes the filled-in profile to a user-specified path. The output is a self-contained plugin folder ready to symlink into `.claude/agents/` or publish as its own marketplace plugin.
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
3. **All 28 question-round answers collected** — see "Inputs" below. Never write a profile with placeholder defaults silently substituted; surface defaults during the question round.
4. **PLACEHOLDER-REFERENCE.md exists** — `plugins/react-agents/docs/PLACEHOLDER-REFERENCE.md` is the source of truth for placeholder names. If absent, refuse and surface the broken install.

If any pre-condition fails, list the gap and stop without writing files.

## When to invoke

User runs `/profile-generator` after installing the `react-agents` plugin, or types a phrase like:

- "scaffold a profile for <my project>"
- "set up the agent trio for this repo"
- "generate <project>-profile"

## Inputs (gathered via AskUserQuestion)

Group the questions into 5 short rounds. Default each option so accepting blindly produces a sensible result for a typical React 19 / Vite app.

### Round 1 — Project identity

1. **Project name** (kebab-case, used in agent names like `<prefix>-implement`):
   - Default: derive from the current working directory name
2. **Agent prefix** (short tag in agent names — usually project name or `web`):
   - Default: same as project name if ≤ 8 chars; else `web`
3. **Stack one-liner** (frontmatter `description` of each agent):
   - Default: `React 19 / TypeScript / Vite / Tailwind / Radix UI`
4. **Output language** for `*-implement` + `*-polish` agent reports (`*-pre-commit` always English):
   - Options: `English` · `Thai` · `Japanese` · (free text)
   - Default: `English`

### Round 2 — Project paths

5. **Conventions doc path** (relative to repo root) — where MC-1..MC-N rules live:
   - Default: `CLAUDE.md`
6. **MC sections count** — how many MC-N sections the conventions doc has:
   - Default: `7`
7. **Structure doc path** (architecture/feature-structure rules):
   - Default: `docs/architecture/feature-structure.md` — leave empty if your project doesn't have one
8. **Progress doc path** (lists Polished baseline pages):
   - Default: `docs/progress.md` — leave empty if your project doesn't have one
9. **Features root** (where feature folders live):
   - Default: `src/features`
10. **Polished page examples** (3-5 page names, comma-separated):
    - Default: `(none — fill in after first baseline page lands)`
11. **Docs root** (parent dir of architecture/components/features doc folders — used to derive `{{ARCHITECTURE_DOCS_GLOB}}`, `{{COMPONENT_DOCS_GLOB}}`, `{{FEATURE_DOCS_GLOB}}`):
    - Default: `<parent of conventions-doc>/docs` (e.g. `pps-web/docs`)
    - Leave empty if your project doesn't split docs by category

### Round 3 — Commands & BE

12. **Build command** (one-liner that must pass):
    - Default: `npm run build`
13. **Dev command**:
    - Default: `npm run dev`
14. **Test command**:
    - Default: `npm test`
15. **Lint:structure command** (project structure linter — leave empty if none):
    - Default: `npm run lint:structure`
16. **Lint:structure strict command** (non-zero exit on `✖`):
    - Default: `npm run lint:structure:strict` (only if previous field non-empty)
17. **Polish audit script** (optional — path to a page polish auditor, e.g. `pps-web/scripts/page-polish-audit.mjs`):
    - Default: (empty)
18. **Backend Swagger URL** (full URL to Swagger UI — leave empty for FE-only projects):
    - Default: (empty)
19. **BE-scope trigger keywords** — comma-separated keywords that opt-in the BE-scope gate:
    - Default: `check BE, verify BE, sync api types, BE contract check`
20. **Shared API service paths** (comma-separated paths of shared HTTP client / API service / case-transform helper — listed in the pre-commit Swagger drift gate):
    - Default: (empty — gate will list only feature `api/*` files when no shared layer exists)

### Round 4 — Testing (for `<prefix>-test` agent)

21. **Coverage test command** (variant of `{{TEST_CMD}}` that emits per-file coverage — used by `web-test` retrofit/expand baseline + delta):
    - Default: derive from answer 14 — replace `test` with `test:cov`, or fall back to `npm run test:cov`
22. **Test infra root** (folder holding `setup`, `test-utils`, `server`, `handlers`, `factories`):
    - Default: `src/test`
23. **Canonical test baseline folder** (folder of the reference test suite that `<prefix>-test` mirrors when retrofitting; leave empty if no canonical example yet):
    - Default: (empty)
24. **Canonical baseline test files** (multi-line markdown bullet list of specific test files to "read in full" — one per line, backtick-wrapped; leave empty if answer 23 is empty):
    - Default: (empty)

### Round 5 — Output

25. **Apply keyword** — single word the user types to greenlight chunk apply:
    - Default: `apply`
26. **UI inventory skill name** (the `pps-ui`-style skill in your profile, if you ship one):
    - Default: `<project>-ui` (auto-derive from project name)
27. **Output folder** (absolute path where the profile is written):
    - Default: `$HOME/Workspace/<project>-profile`
28. **Profile plugin description** (one sentence, shown in marketplace listing):
    - Default: derive — `<Project> profile: implement/polish/pre-commit/test subagents + UI primitive inventory`

After Round 5: summarize all answers in a single markdown block and ask **one** final confirmation before writing.

## Substitution rules

Apply these placeholder mappings to each template file. Use Read + Edit (replace_all=true) per placeholder. Whitespace must match exactly.

| Placeholder | Replacement | Notes |
|---|---|---|
| `{{PROJECT_NAME}}` | answer 1 | |
| `{{AGENT_PREFIX}}` | answer 2 | |
| `{{STACK}}` | answer 3 | |
| `{{OUTPUT_LANG}}` | answer 4 | |
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
| `{{POLISH_AUDIT_SCRIPT_REF}}` | ` + skim ` + answer 17 + ` (PAGE_STATUS map)` (empty string if answer 17 empty) | |
| `{{POLISH_STATUS_CHECK_SECTION}}` | render full Polish-status block (see below) if answer 17 non-empty; else empty string | |
| `{{POLISH_AUDIT_CMD}}` | `cd <project> && node <relative-path-from-project-root>` derived from answer 17 (empty if answer 17 empty) | only referenced inside `{{POLISH_STATUS_CHECK_SECTION}}` |
| `{{POLISH_AUDIT_SOURCE}}` | answer 17 verbatim (empty if answer 17 empty) | |
| `{{SWAGGER_URL}}` | answer 18 | |
| `{{BE_KEYWORDS_PRIMARY}}` | answer 19 first half | |
| `{{BE_KEYWORDS_SECONDARY}}` | answer 19 second half | split at commas, group |
| `{{API_SERVICES_PATHS}}` | answer 20 (empty if FE-only project — Swagger drift gate then lists feature `api/*` files only) | |
| `{{TEST_COV_CMD}}` | answer 21 | |
| `{{TEST_INFRA_ROOT}}` | answer 22 | |
| `{{TEST_CANONICAL_BASELINE}}` | answer 23 (empty → template renders an empty "Canonical baseline" section; agent falls back to in-repo conventions) | trailing `/` preserved |
| `{{TEST_CANONICAL_FILES}}` | answer 24 (multi-line markdown bullet list, indentation = 0 spaces, one `- \`path\`` per line) | |
| `{{APPLY_KEYWORD}}` | answer 25 | |
| `{{UI_INVENTORY_SKILL}}` | answer 26 | wrap in backticks: `` `<name>` `` |
| `{{UI_INVENTORY_REF}}` | `, ` + UI_INVENTORY_SKILL if non-empty; else empty string | inline list separator |

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

1. **Verify** you're in a Claude Code session that has access to the `react-agents` plugin's template files. Read directly from the plugin install location.
2. **Round 1-5**: invoke `AskUserQuestion` five times, one per round (Round 3 may need 2 calls due to the 4-question cap). Validate answers as you go (e.g. project name kebab-case, paths look like paths).
3. **Summarize**: present all 28 answers in a single markdown block. Show the absolute path where files will be written. Ask one final `AskUserQuestion`: "Write the profile?" with options `Yes — write` / `No — let me adjust`.
4. **Write**: read each template via `Read`, perform substitutions (use repeated `Edit` with `replace_all=true`), write the result via `Write` to the target path. Handle the conditional sections (BE-scope, Polish-status, lint:structure) before writing.
5. **Report**: print absolute paths of all created files, plus the symlink install snippet from the README. Remind user to `git init` + push if they want to publish as a marketplace plugin.

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
