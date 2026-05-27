# Placeholder reference

Every `{{PLACEHOLDER}}` used by the agent templates, with example values from a fictional `shop-web` project (showing one consistent set of filled values).

## Identity

| Placeholder | What it is | Example (`shop-web`) |
|---|---|---|
| `{{PROJECT_NAME}}` | Project slug used in agent descriptions and conventions text | `shop-web` |
| `{{AGENT_PREFIX}}` | Short prefix for agent names (becomes `<prefix>-implement`, etc.) | `shop` |
| `{{STACK}}` | One-line stack summary for `implement` + `polish` agent `description:` frontmatter | `React 19 / TS / Vite / Tailwind / Radix` |
| `{{TEST_STACK}}` | Test-stack one-liner for `test` agent description (Vitest/RTL/MSW + versions) | `Vitest 4 + React Testing Library 16 + @testing-library/user-event 14 + MSW 2` |
| `{{OUTPUT_LANG}}` | Language for `implement` + `polish` + `test` reports (`pre-commit` is always English) | `Thai` |
| `{{BACKEND_NAME}}` | Backend project / repo name (used in implement Debug Protocol) | `shop-api` |

## Paths

| Placeholder | What it is | Example |
|---|---|---|
| `{{CONVENTIONS_DOC}}` | Path to your project's Mandatory Conventions doc | `shop-web/CLAUDE.md` |
| `{{CONV_SECTION_REF}}` | Optional clause naming the section that holds the rules (empty = the whole doc is conventions). Agents enumerate rules at runtime — no count is baked. | `` (its `Mandatory Conventions` section)`` |
| `{{STRUCTURE_DOC}}` | Path to feature/folder structure rules doc | `shop-web/docs/architecture/feature-structure.md` |
| `{{STRUCTURE_PREWRITE_TABLE}}` | (Optional) Project-specific "new file kind → required sections to Read" table + worked example, inserted into `implement` Step 0.1 Structure pre-write check. Empty if generic | (multi-line table; see PROFILE-GENERATOR.md crib sheet) |
| `{{STRUCTURE_EXTRACT_MAPPING}}` | (Optional) Project-specific extraction-kind → section bullet list for `polish` Structure check when extracting. Empty if generic | `- Schema extraction → Section 4.1 + 4.4 + 9`<br>`- Component split / extract → Section 4.2 + 6` |
| `{{PROGRESS_DOC}}` | Path to the doc that lists Polished baseline pages | `shop-web/docs/progress.md` |
| `{{FEATURES_ROOT}}` | Root path for feature folders | `src/features` |
| `{{POLISHED_PAGE_EXAMPLES}}` | Comma-separated examples of reference (baseline) pages agents anchor on | `OrderListPage, ProductListPage, ProductDetailPage` |
| `{{REFERENCE_PAGE_TERM}}` | Adjective for a known-good reference page (default `Polished`; `reference` if the project has no page-maturity model) | `Polished` |
| `{{ANTI_REFERENCE_CLAUSE}}` | Inline warning against anchoring on immature pages (empty if no maturity model) | `` — never anchor on Rough/Partial pages`` |
| `{{POLISH_STATUS_REPORT_BLOCK}}` | The `## Polish status` flip/regression report subsection (empty unless a page-status audit script exists) | (see POLISH_STATUS_REPORT_BLOCK template) |
| `{{ARCHITECTURE_DOCS_GLOB}}` | Glob of architectural docs (drives pre-commit doc-sync gate) | `shop-web/docs/architecture/*` |
| `{{COMPONENT_DOCS_GLOB}}` | Glob of per-component docs | `shop-web/docs/components/*` |
| `{{FEATURE_DOCS_GLOB}}` | Glob of per-feature docs | `shop-web/docs/features/*` |
| `{{PLAN_FILE_PATTERN}}` | (Optional) Trailing parenthetical hint for Plan-file path convention in `implement` Mode table | ` (\`session-working-space/tasks/*-plan.md\`)` |
| `{{MC_WALK_INCIDENT_REF}}` | (Optional) Trailing sentence cited as motivation for the MC-walk forcing functions (typically a past incident). Empty if no incident | ` A precedent miss exists (org-config revamp 2026-05-19, 18 issues escaped); the forcing functions below are designed to make that impossible to repeat.` |
| `{{MC_MECHANICAL_CATCH_MAP}}` | (Optional) Trailing sentence listing which MC sections the structure linter mechanically catches. Empty if not applicable | ` It catches MC-5 (factory schema), MC-6 (shared namespace), MC-7 (console.*).` |
| `{{COMMIT_SCOPE_OPTIONS}}` | Scope-options sentence in `pre-commit` commit-draft section | `` `(shop-web)` when diff is purely frontend · `(shop-api)` when purely backend · omit for cross-cutting / repo-level `` |
| `{{API_TRIGGER_HINT}}` | Inline phrase in `pre-commit` Bug+regression scan describing what API surface touched looks like | `` `services/api.ts` or feature `api/` `` (default: `network surface`) |
| `{{STRUCTURE_LEGACY_REF}}` | Phrase used to refer to pre-existing structure violations (project's backlog name, if any) | `Tech-debt backlog` (default: `legacy`) |
| `{{STRUCT_PENDING_RULES}}` | Multi-line block under Structure regression check step 4 — project's pending-list workflow. Empty = single-line generic Non-blocking note | (see PROFILE-GENERATOR.md crib sheet — bullet list referencing project pending-list names) |

## Commands

| Placeholder | What it is | Example |
|---|---|---|
| `{{BUILD_CMD}}` | One-liner that must pass before reporting done | `cd shop-web && npm run build` |
| `{{DEV_CMD}}` | Dev server command (reserved — not currently embedded in templates) | `cd shop-web && npm run dev` |
| `{{TEST_CMD}}` | Test runner used by the pre-commit "test-only diff" fast path and `shop-test` chunk runs (`{{TEST_CMD}} -- <files>`) | `cd shop-web && npm run test:unit` |
| `{{TEST_COV_CMD}}` | Coverage-variant test runner (`shop-test` baseline + delta capture) | `cd shop-web && npm run test:cov` |
| `{{LINT_STRUCTURE_CMD}}` | Project structure linter (or empty if not used) | `npm run lint:structure` |
| `{{LINT_STRUCTURE_CMD_STRICT}}` | Strict variant (non-zero exit on `✖`) | `npm run lint:structure:strict` |
| `{{POLISH_AUDIT_SCRIPT_REF}}` | Either ` + skim <script> (PAGE_STATUS map)` or empty | ` + skim shop-web/scripts/page-polish-audit.mjs (PAGE_STATUS map)` |
| `{{POLISH_STATUS_CHECK_SECTION}}` | Full Polish-status check block (or empty) | (see template — only rendered if a polish audit script is configured) |
| `{{POLISH_AUDIT_CMD}}` | Command that emits the page polish status map (referenced inside `{{POLISH_STATUS_CHECK_SECTION}}`) | `cd shop-web && node scripts/page-polish-audit.mjs` |
| `{{POLISH_AUDIT_SOURCE}}` | Source file path used as the `PAGE_STATUS` reference | `shop-web/scripts/page-polish-audit.mjs` |

## Backend

| Placeholder | What it is | Example |
|---|---|---|
| `{{SWAGGER_URL}}` | Full URL to your backend's API-contract doc — Swagger/OpenAPI UI or GraphQL schema (or empty for FE-only) | `https://api.example.com/swagger-ui/index.html` |
| `{{API_CONTRACT_NAME}}` | Report-wording term for the contract source (default `Swagger`; set `OpenAPI` / `GraphQL schema` for non-Swagger backends) | `Swagger` |
| `{{BE_KEYWORDS_PRIMARY}}` | First group of BE-scope opt-in keywords | `Thai: เช็ค BE, เช็ค swagger, sync api` |
| `{{BE_KEYWORDS_SECONDARY}}` | Second group | `English: check BE, verify BE, sync api types` |
| `{{API_SERVICES_PATHS}}` | Comma-separated paths of shared API client / interceptor / transform files (Swagger drift gate evidence list) | `shop-web/src/services/api.ts, shop-web/src/services/http.ts, shop-web/src/services/case-transform.ts` |

## Testing

| Placeholder | What it is | Example |
|---|---|---|
| `{{TEST_CANONICAL_BASELINE}}` | Folder of the canonical/reference test suite that `shop-test` mirrors when retrofitting | `shop-web/src/features/orders/` |
| `{{TEST_CANONICAL_FILES}}` | Multi-line markdown bullet list of specific baseline test files to read in full (one per line, backtick-wrapped) | `- `shop-web/src/features/orders/schemas/orders.schema.test.ts`<br>- `shop-web/src/features/orders/api/index.test.ts`<br>- ... (3 more) |
| `{{TEST_INFRA_ROOT}}` | Folder holding shared test infra (`setup`, `test-utils`, `server`, `handlers`, `factories`) | `shop-web/src/test` |
| `{{API_CLIENT_IMPORT}}` | Module path the project's API client is imported from (used in test agent for "don't `vi.mock()` this" checks) | `@/services/api` (default: same) |
| `{{TEST_UTILS_IMPORT}}` | Module path `createTestQueryClient` (or equivalent) is imported from | `@/test/test-utils` (default: same) |
| `{{I18N_LOCALES_PATH}}` | Glob/path of i18n locale JSON files (used in test agent for key-existence checks) | `src/i18n/locales/en/<feature>.json` (default: same) |
| `{{WORKFLOW_PATTERNS_TABLE}}` | Markdown table of "Polished page" regression patterns the pre-commit Workflow regression check enforces. Project fills with its specific components/hooks; default = minimal 2-row generic | (see PROFILE-GENERATOR.md crib sheet — table of project's canonical components / hooks / patterns) |
| `{{BP_APPLIED_UX}}` | UX/UI bullet examples in `implement` Report's "Best Practices Applied" section. Default = `<pattern enforced>` placeholder | `- <enforced pattern, e.g. dirty-aware Save / validation auto-switch-to-error-tab / LoadingOverlay during submit>` |
| `{{BP_APPLIED_ARCH}}` | Arch/Dev bullet examples in `implement` Report's "Best Practices Applied" section. Default = `<pattern enforced>` placeholder | `- <enforced pattern, e.g. useTabDirtyState mirror / atomic mutation / form values vs defaultValues>` |
| `{{POLISH_MODE_ROWS}}` | Data rows of `polish` agent's Mode table (4 rows: Component-audit / Visual-consistency / Feature-audit / Diff-polish). Project fills with its trigger phrases | (see PROFILE-GENERATOR.md crib sheet — 4 markdown table rows) |
| `{{TEST_MODE_ROWS}}` | Data rows of `test` agent's Mode-detection table (3 rows: retrofit / expand / integration). Project fills with its trigger phrases | (see PROFILE-GENERATOR.md crib sheet — 3 markdown table rows) |
| `{{MSW_URL_PATTERN}}` | One-line description of project's MSW URL matching convention in `test` agent's Conventions section | `` `*/api/v1/<path>` (wildcard host, matches baseURL + path) `` (default: `wildcard host + path (matches project baseURL + path)`) |
| `{{MUTATION_SCENARIOS}}` | Required test scenarios for Mutation hook row in `test` agent's Required-scenarios-per-layer table. Project fills with its tenant/cache invalidation patterns | `invalidates correct keys on success; does NOT invalidate on error; does NOT invalidate when tenantId missing; removeQueries for delete` (default: `invalidates correct keys on success; does NOT invalidate on error; removeQueries for delete`) |

## Triggers (per-agent description lines)

| Placeholder | What it is | Example |
|---|---|---|
| `{{POLISH_TRIGGER_KEYWORDS}}` | Comma-separated quoted triggers for `polish` agent description (multi-language allowed) | `"clean up", "DRY up X", "ทำไม X หน้าตาไม่เหมือนกันข้ามหน้า", "align features X, Y, Z", "polish diff"` |
| `{{POLISH_SCOPE_NOTE}}` | Optional parenthetical clarifier in `polish` description (or empty) | ` (distinct from user-global \`polish\` design skill)` |
| `{{TEST_TRIGGER_KEYWORDS}}` | Comma-separated quoted triggers for `test` agent description (multi-language allowed) | `"เขียน test ให้ X", "test ให้ X", "write tests for X", "เพิ่ม coverage X", "expand tests X", "fill test gaps X", "integration test X", "test flow X"` |
| `{{IMPLEMENT_TRIGGER_KEYWORDS}}` | Comma-separated quoted triggers for `implement` agent description (multi-language allowed) | `"implement X", "build Y", "apply this plan", "revamp X"` |
| `{{PRECOMMIT_TRIGGER_KEYWORDS}}` | Comma-separated quoted triggers for `pre-commit` agent description (multi-language allowed). **Triggers may be localized, but `pre-commit` output — commit title + body, PR / push text — is always English.** | `"review my changes", "ship it", "pre-commit check", "draft commit"` |

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

## Empty / conditional sections

The generator strips entire sections when key placeholders are empty:

| When empty | What gets removed |
|---|---|
| `{{SWAGGER_URL}}` | Step 0.0 BE-scope gate (implement) + API-contract drift gate (pre-commit) |
| `{{LINT_STRUCTURE_CMD}}` | Shared `lint:structure` run + Structure regression check (pre-commit) |
| `{{POLISH_AUDIT_SOURCE}}` / `{{POLISH_AUDIT_CMD}}` (both empty when no polish auditor configured) | Entire Polish-status check section (pre-commit) + `{{POLISH_AUDIT_SCRIPT_REF}}` collapses to empty |
| `{{ARCHITECTURE_DOCS_GLOB}}` / `{{COMPONENT_DOCS_GLOB}}` / `{{FEATURE_DOCS_GLOB}}` (any empty) | Matching row in pre-commit `## Docs update` table is dropped |
| `{{TEST_CANONICAL_BASELINE}}` + `{{TEST_CANONICAL_FILES}}` (both empty) | "Canonical baseline" sections in `<prefix>-test` render empty; agent falls back to in-repo conventions |

When you hand-fork, you can either delete those sections or leave them with comments — both are fine. The generator deletes for cleanliness.
