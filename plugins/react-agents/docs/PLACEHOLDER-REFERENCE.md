# Placeholder reference

Every `{{PLACEHOLDER}}` used by the agent templates, with example values from the `pps-web` reference profile.

## Identity

| Placeholder | What it is | Example (`pps-web`) |
|---|---|---|
| `{{PROJECT_NAME}}` | Project slug used in agent descriptions and conventions text | `pps-web` |
| `{{AGENT_PREFIX}}` | Short prefix for agent names (becomes `<prefix>-implement`, etc.) | `web` |
| `{{STACK}}` | One-line stack summary for agent `description:` frontmatter | `React 19 / TS / Vite / Tailwind / Radix` |
| `{{OUTPUT_LANG}}` | Language for `implement` + `polish` reports (`pre-commit` is always English) | `Thai` |

## Paths

| Placeholder | What it is | Example |
|---|---|---|
| `{{CONVENTIONS_DOC}}` | Path to your project's Mandatory Conventions doc | `pps-web/CLAUDE.md` |
| `{{MC_MAX}}` | Highest MC-N section number in your conventions doc | `7` |
| `{{STRUCTURE_DOC}}` | Path to feature/folder structure rules doc | `pps-web/docs/architecture/feature-structure.md` |
| `{{PROGRESS_DOC}}` | Path to the doc that lists Polished baseline pages | `pps-web/docs/progress.md` |
| `{{FEATURES_ROOT}}` | Root path for feature folders | `src/features` |
| `{{POLISHED_PAGE_EXAMPLES}}` | Comma-separated examples of canonical baseline pages | `PayrollListPage, EmployeeListPage, EmployeeDetailPage` |

## Commands

| Placeholder | What it is | Example |
|---|---|---|
| `{{BUILD_CMD}}` | One-liner that must pass before reporting done | `cd pps-web && npm run build` |
| `{{DEV_CMD}}` | Dev server command (reserved — not currently embedded in templates) | `cd pps-web && npm run dev` |
| `{{TEST_CMD}}` | Test runner used by the pre-commit "test-only diff" fast path | `cd pps-web && npm run test:unit` |
| `{{LINT_STRUCTURE_CMD}}` | Project structure linter (or empty if not used) | `npm run lint:structure` |
| `{{LINT_STRUCTURE_CMD_STRICT}}` | Strict variant (non-zero exit on `✖`) | `npm run lint:structure:strict` |
| `{{POLISH_AUDIT_SCRIPT_REF}}` | Either ` + skim <script> (PAGE_STATUS map)` or empty | ` + skim pps-web/scripts/page-polish-audit.mjs (PAGE_STATUS map)` |
| `{{POLISH_STATUS_CHECK_SECTION}}` | Full Polish-status check block (or empty) | (see template — only rendered if a polish audit script is configured) |

## Backend

| Placeholder | What it is | Example |
|---|---|---|
| `{{SWAGGER_URL}}` | Full URL to your backend's Swagger UI (or empty for FE-only) | `https://payroll-dev-api.aware.co.th/swagger-ui/index.html` |
| `{{BE_KEYWORDS_PRIMARY}}` | First group of BE-scope opt-in keywords | `Thai: เช็ค BE, เช็ค swagger, sync api` |
| `{{BE_KEYWORDS_SECONDARY}}` | Second group | `English: check BE, verify BE, sync api types` |

## Other

| Placeholder | What it is | Example |
|---|---|---|
| `{{APPLY_KEYWORD}}` | Single word the user types to greenlight apply | `เริ่ม` / `start` (`apply` is the English default) |
| `{{UI_INVENTORY_SKILL}}` | Backtick-wrapped name of the project's UI inventory skill | `` `pps-ui` `` |
| `{{UI_INVENTORY_REF}}` | Comma-separated extension for skill-list tables | `, `` `pps-ui` `` |

## Empty / conditional sections

The generator strips entire sections when key placeholders are empty:

| When empty | What gets removed |
|---|---|
| `{{SWAGGER_URL}}` | Step 0.0 BE-scope gate (implement) + Swagger drift gate (pre-commit) |
| `{{LINT_STRUCTURE_CMD}}` | Shared `lint:structure` run + Structure regression check (pre-commit) |
| `{{POLISH_AUDIT_SCRIPT}}` | Entire Polish-status check section (pre-commit) |
| `{{UI_INVENTORY_SKILL}}` | Replaced with `(no UI inventory skill configured)`; reference removed from skill tables |

When you hand-fork, you can either delete those sections or leave them with comments — both are fine. The generator deletes for cleanliness.
