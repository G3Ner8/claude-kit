# Placeholder reference

Every `{{PLACEHOLDER}}` used by the agent templates, with example values from the `pps-web` reference profile.

## Identity

| Placeholder | What it is | Example (`pps-web`) |
|---|---|---|
| `{{PROJECT_NAME}}` | Project slug used in agent descriptions and conventions text | `pps-web` |
| `{{AGENT_PREFIX}}` | Short prefix for agent names (becomes `<prefix>-implement`, etc.) | `web` |
| `{{STACK}}` | One-line stack summary for `implement` + `polish` agent `description:` frontmatter | `React 19 / TS / Vite / Tailwind / Radix` |
| `{{TEST_STACK}}` | Test-stack one-liner for `test` agent description (Vitest/RTL/MSW + versions) | `Vitest 4 + React Testing Library 16 + @testing-library/user-event 14 + MSW 2` |
| `{{OUTPUT_LANG}}` | Language for `implement` + `polish` + `test` reports (`pre-commit` is always English) | `Thai` |
| `{{BACKEND_NAME}}` | Backend project / repo name (used in implement Debug Protocol) | `pps-api` |

## Paths

| Placeholder | What it is | Example |
|---|---|---|
| `{{CONVENTIONS_DOC}}` | Path to your project's Mandatory Conventions doc | `pps-web/CLAUDE.md` |
| `{{MC_MAX}}` | Highest MC-N section number in your conventions doc | `7` |
| `{{STRUCTURE_DOC}}` | Path to feature/folder structure rules doc | `pps-web/docs/architecture/feature-structure.md` |
| `{{PROGRESS_DOC}}` | Path to the doc that lists Polished baseline pages | `pps-web/docs/progress.md` |
| `{{FEATURES_ROOT}}` | Root path for feature folders | `src/features` |
| `{{POLISHED_PAGE_EXAMPLES}}` | Comma-separated examples of canonical baseline pages | `PayrollListPage, EmployeeListPage, EmployeeDetailPage` |
| `{{ARCHITECTURE_DOCS_GLOB}}` | Glob of architectural docs (drives pre-commit doc-sync gate) | `pps-web/docs/architecture/*` |
| `{{COMPONENT_DOCS_GLOB}}` | Glob of per-component docs | `pps-web/docs/components/*` |
| `{{FEATURE_DOCS_GLOB}}` | Glob of per-feature docs | `pps-web/docs/features/*` |

## Commands

| Placeholder | What it is | Example |
|---|---|---|
| `{{BUILD_CMD}}` | One-liner that must pass before reporting done | `cd pps-web && npm run build` |
| `{{DEV_CMD}}` | Dev server command (reserved — not currently embedded in templates) | `cd pps-web && npm run dev` |
| `{{TEST_CMD}}` | Test runner used by the pre-commit "test-only diff" fast path and `web-test` chunk runs (`{{TEST_CMD}} -- <files>`) | `cd pps-web && npm run test:unit` |
| `{{TEST_COV_CMD}}` | Coverage-variant test runner (`web-test` baseline + delta capture) | `cd pps-web && npm run test:cov` |
| `{{LINT_STRUCTURE_CMD}}` | Project structure linter (or empty if not used) | `npm run lint:structure` |
| `{{LINT_STRUCTURE_CMD_STRICT}}` | Strict variant (non-zero exit on `✖`) | `npm run lint:structure:strict` |
| `{{POLISH_AUDIT_SCRIPT_REF}}` | Either ` + skim <script> (PAGE_STATUS map)` or empty | ` + skim pps-web/scripts/page-polish-audit.mjs (PAGE_STATUS map)` |
| `{{POLISH_STATUS_CHECK_SECTION}}` | Full Polish-status check block (or empty) | (see template — only rendered if a polish audit script is configured) |
| `{{POLISH_AUDIT_CMD}}` | Command that emits the page polish status map (referenced inside `{{POLISH_STATUS_CHECK_SECTION}}`) | `cd pps-web && node scripts/page-polish-audit.mjs` |
| `{{POLISH_AUDIT_SOURCE}}` | Source file path used as the `PAGE_STATUS` reference | `pps-web/scripts/page-polish-audit.mjs` |

## Backend

| Placeholder | What it is | Example |
|---|---|---|
| `{{SWAGGER_URL}}` | Full URL to your backend's Swagger UI (or empty for FE-only) | `https://payroll-dev-api.aware.co.th/swagger-ui/index.html` |
| `{{BE_KEYWORDS_PRIMARY}}` | First group of BE-scope opt-in keywords | `Thai: เช็ค BE, เช็ค swagger, sync api` |
| `{{BE_KEYWORDS_SECONDARY}}` | Second group | `English: check BE, verify BE, sync api types` |
| `{{API_SERVICES_PATHS}}` | Comma-separated paths of shared API client / interceptor / transform files (Swagger drift gate evidence list) | `pps-web/src/services/api.ts, pps-web/src/services/http.ts, pps-web/src/services/case-transform.ts` |

## Testing

| Placeholder | What it is | Example |
|---|---|---|
| `{{TEST_CANONICAL_BASELINE}}` | Folder of the canonical/reference test suite that `web-test` mirrors when retrofitting | `pps-web/src/features/holiday/` |
| `{{TEST_CANONICAL_FILES}}` | Multi-line markdown bullet list of specific baseline test files to read in full (one per line, backtick-wrapped) | `- `pps-web/src/features/holiday/schemas/holiday.schema.test.ts`<br>- `pps-web/src/features/holiday/api/index.test.ts`<br>- ... (3 more) |
| `{{TEST_INFRA_ROOT}}` | Folder holding shared test infra (`setup`, `test-utils`, `server`, `handlers`, `factories`) | `pps-web/src/test` |

## Triggers (per-agent description lines)

| Placeholder | What it is | Example |
|---|---|---|
| `{{POLISH_TRIGGER_KEYWORDS}}` | Comma-separated quoted triggers for `polish` agent description (multi-language allowed) | `"clean up", "DRY up X", "ทำไม X หน้าตาไม่เหมือนกันข้ามหน้า", "align features X, Y, Z", "polish diff"` |
| `{{POLISH_SCOPE_NOTE}}` | Optional parenthetical clarifier in `polish` description (or empty) | ` (distinct from user-global \`polish\` design skill)` |
| `{{TEST_TRIGGER_KEYWORDS}}` | Comma-separated quoted triggers for `test` agent description (multi-language allowed) | `"เขียน test ให้ X", "test ให้ X", "write tests for X", "เพิ่ม coverage X", "expand tests X", "fill test gaps X", "integration test X", "test flow X"` |

## Apply keyword

| Placeholder | What it is | Example |
|---|---|---|
| `{{APPLY_KEYWORD}}` | Primary single-word greenlight | `เริ่ม` (`apply` is the English default) |
| `{{APPLY_KEYWORD_ALIASES}}` | Trailing alias suffix appended after `{{APPLY_KEYWORD}}` (begins with ` / `) | `` ` / `start` / `apply` / `go ahead` `` (Thai); `` ` / `go ahead` `` (English default) |

## Report-block headers (OUTPUT_LANG-derived)

The Report block in `implement` / `polish` / `test` agents uses small placeholders so headers translate with `{{OUTPUT_LANG}}`. `pre-commit` always English — these are not used there.

| Placeholder | English default | Thai value |
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

The generator must ship a built-in derivation map for `English` and `Thai`. For other languages, prompt the user to supply each value during Round 5; do not silently fall back to English.

## Other

| Placeholder | What it is | Example |
|---|---|---|
| `{{UI_INVENTORY_SKILL}}` | Backtick-wrapped name of the project's UI inventory skill | `` `pps-ui` `` |
| `{{UI_INVENTORY_REF}}` | Comma-separated extension for skill-list tables | `, `` `pps-ui` `` |

## Empty / conditional sections

The generator strips entire sections when key placeholders are empty:

| When empty | What gets removed |
|---|---|
| `{{SWAGGER_URL}}` | Step 0.0 BE-scope gate (implement) + Swagger drift gate (pre-commit) |
| `{{LINT_STRUCTURE_CMD}}` | Shared `lint:structure` run + Structure regression check (pre-commit) |
| `{{POLISH_AUDIT_SOURCE}}` / `{{POLISH_AUDIT_CMD}}` (both empty when no polish auditor configured) | Entire Polish-status check section (pre-commit) + `{{POLISH_AUDIT_SCRIPT_REF}}` collapses to empty |
| `{{UI_INVENTORY_SKILL}}` | Replaced with `(no UI inventory skill configured)`; reference removed from skill tables |
| `{{ARCHITECTURE_DOCS_GLOB}}` / `{{COMPONENT_DOCS_GLOB}}` / `{{FEATURE_DOCS_GLOB}}` (any empty) | Matching row in pre-commit `## Docs update` table is dropped |
| `{{TEST_CANONICAL_BASELINE}}` + `{{TEST_CANONICAL_FILES}}` (both empty) | "Canonical baseline" sections in `<prefix>-test` render empty; agent falls back to in-repo conventions |

When you hand-fork, you can either delete those sections or leave them with comments — both are fine. The generator deletes for cleanliness.
