# Changelog

All notable changes to this kit are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the kit uses [Semantic Versioning](https://semver.org/).

Plugins are versioned independently in their `plugin.json`. The headings below group changes by plugin.

## [Unreleased]

### `dev-core` 0.9.0
- `drafter` 0.6.0 — force runtime use of Agent Configuration declarations. Both `agent-type:` and
  `skills:` are daemon-validated but **best-effort at runtime** (the "agent/skill not invoked"
  symptom), so drafter now pairs each with an explicit body instruction: read the target repo's
  `.claude/agents/<name>.md` for a repo-defined `agent-type:` (built-ins `general-purpose`/
  `Explore`/`Plan` exempt — no file), and invoke-the-skill (Skill tool) for each `skills:` entry
  (project or plugin). Also dedups the validation rule (was stated 3×) into one canonical
  Operating-rules bullet — light trim, no behavior change.

### `dev-core` 0.5.0
- `drafter` 0.2.0 — add `skills:` / `agent-type:` awareness for SDC agent tasks. Step 3 now scans the plan for agent orchestration intent (skills to invoke, sub-agent to delegate to, multi-phase sequences) and asks the user to confirm exact names before writing. Step 4 adds an **Agent Configuration** section to the work-order template with `model:`, `skills:`, and `agent-type:` rules including the daemon's hard-block semantics. Operating rules add: never guess skill or agent-type names — a wrong name parks the issue `agent-blocked` pre-claim.

### `dev-core` 0.4.0
- `surveyor` 0.2.0 — default contributor scope is now **my work only**: resolves `git config user.name/email` and filters `git log` with `--author`. Widen to all contributors only on explicit request ("survey everyone", "all work", "the whole team"). Terrain line appends `(author: <name>)` when scoped.

### `dev-core` 0.3.0
- `surveyor` (new) — project-status survey: reconcile DECLARED status (backlog/plan files, status docs, memory notes, tracker issues) against GROUND TRUTH (merged git history, MR/issue state, the actual code), report the drift, then recommend next work by feasibility and offer to sync the stale docs. Read-only by default; doc edits apply only on explicit go-ahead, tracker actions asked separately. Detects host (glab/gh/plain git) + repo shape (submodule/mono) and reads the project's own `CLAUDE.md` for layout; separates exists-in-source ≠ merged ≠ deployed. The discipline transfers by *showing the work* (every verdict carries the check that produced it), not by teaching tags. Persona name chosen for legibility (decision D8).
- `foreman` → `drafter` (rename) — the persona was the industrial-era outlier in the set; `drafter` reads as its job (drafts the work order) and fits the register. Same behavior, no content change beyond the persona voice (decision D9). The `/foreman` invocation becomes `/drafter`.

### `dev-core` 0.1.0 (new plugin)
- New cross-cutting tier of framework-agnostic disciplines, each named for the **persona** it adopts and mapped to a lifecycle moment:
  - `detective` (new) — debug discipline: reproduce → follow the fail path → falsify → name the root cause before fixing. The stack-agnostic counterpart to `react-core`'s React-specialized `react-debug`.
  - `inspector` (was `scrutinize`) — intent-validation diff review: does the change do what the task asked, no more / no less?
  - `archivist` (was `post-mortem`) — standardized incident post-mortem / RCA document.
- `inspector` + `archivist` moved out of `react-core`; bare names, no `react-` prefix (decision D6 + D7).

### `react-core` 0.5.0
- Promote `react-debug` (data-flow debug discipline) from `_in-progress/` to stable; cited by the implement template.
- Move `scrutinize` + `post-mortem` to the new `dev-core` plugin (renamed `inspector` + `archivist`).
- Genericize teaching examples (Employee → User, HR features → orders/products, internal URL → example.com, `pps/v1` → `api/v1`) — examples only, no behavior change.
- Remove redundant per-skill READMEs (audit / dry / revamp / ux-review) and duplicate `rules/_sections.md`.
- `react-test-patterns` 1.1.0 — add a "Fixtures — factory vs inline" section + two anti-pattern rows, closing a gap where the skill mandated a `factories/` infra layer and listed "fixture reuse" as a review criterion but never said when to use one. Rule: factories produce FE-shape (camelCase) objects for component props / hook-output assertions; MSW handler payloads stay inline wire-shape (snake_case); a `factories/` file with zero importers is dead infra (wire it in or delete it).

### `react-agents` 0.5.0
- `profile-generator` 1.3.0 — **auto-install option** in Phase 6. After writing, the generator asks `Auto-install` (default) vs `Manual`. Auto-install copies `agents/*.md` into `<launch-cwd>/.claude/agents/` and (when the output folder is under `/tmp`) `rm -rf`s it — closing the gen → copy → discard loop in one prompt. Existing destination files surface as an overwrite-list confirmation before any copy. Manual is the previous behavior (print snippet, no filesystem changes).
- Template trim batch (per-invocation token reduction, no behavior change):
  - **`test`** integration mode: condense — defer Flow selection + observe / NOT-observe rules to the `react-test-patterns` skill (already invoked in Step 0). Keep only project-specific overrides. ~16 lines / ~1.5KB.
  - **`implement` / `polish` / `test`** Conventions one-liners: drop the `· Don't commit` and `· Report {{OUTPUT_LANG}}` bullets — both already covered by the agent's description and `You DON'T` section.

### `react-agents` 0.4.0
- `profile-generator` 1.2.0 — **friendlier Round 5 richness menu**. Each of the 14 items now leads with a plain-English title and a concrete example tied to a real codebase, instead of jargon + raw `{{PLACEHOLDER_NAME}}` tags. The placeholder mapping moved into a separate "Substitution map" table the generator reads internally (not surfaced to the user). Same 14 items, no behavior change to the produced profile — only the interview UX.

### `react-agents` 0.3.3
- Templates trimmed for per-invocation token cost: removed the `## Worked example` section from all four agent templates (illustrative placeholders; the procedural body covers the flow) and dropped the redundant `(auto-loaded ... otherwise read explicitly)` parenthetical on MC-walk source-of-truth lines in `implement` + `polish`. ~60 lines / ~4KB shaved across the quartet. Pure trim — no behavior change; profile-generator skill unchanged (still 1.1.3).

### `react-agents` 0.3.2
- `profile-generator` 1.1.3 — generated README's install snippet now defaults to **copy** (`cp`) instead of symlink, pairing with the `/tmp` output default (a symlink into `/tmp` breaks when the OS clears it). Symlink is kept as the documented alternative for a persistent profile folder used as source of truth.

### `react-agents` 0.3.1
- `profile-generator` 1.1.2 — add a **grounding rule** (no fabrication): every written value must come from the scan, a user answer, or a documented default. Specifically guards `{{MC_WALK_INCIDENT_REF}}` against inventing a commit hash — cite one only if supplied or verifiable via `git log`, else describe the incident in prose. (A pps-web gen run produced a hallucinated `f7f05d6`.)

### `react-agents` 0.3.0
- Templates adopt `inspector`'s intent-alignment technique (not the skill — `dev-core` stays user-invoked):
  - `pre-commit` gains a scope-creep tripwire (Non-blocking) + a graceful handoff that *recommends* `/inspector` when the diff drifts from the stated task — never auto-invokes, degrades silently when `dev-core` isn't installed.
  - `polish` gains a "no more, no less" operating rule — apply exactly the picked rows; spotted-but-unpicked issues become new findings, never silent fixes.
- `profile-generator` default output is now `/tmp/<PROJECT_NAME>-profile` — a transient location never inside a repo (no commit risk); the common flow is gen → copy `agents/*.md` into the project's `.claude/agents/` → discard. Supersedes the `<PROJECT_ROOT>-profile` default from 0.2.1; the output-folder question still lets you type a persistent path.

### `react-agents` 0.2.1
- `profile-generator` 1.1.1 — output-folder default derives from `PROJECT_ROOT` (`<PROJECT_ROOT>-profile`) instead of a hardcoded `$HOME/Workspace/`, so it lands next to the project even in a nested monorepo.

### `react-agents` 0.2.0
- Decouple templates from pps-web assumptions: runtime convention-walk (drop `{{MC_MAX}}`), `{{API_CONTRACT_NAME}}` (default `Swagger`), portal-primitive generalization, page-maturity via `{{REFERENCE_PAGE_TERM}}` + `{{ANTI_REFERENCE_CLAUSE}}` + gated `{{POLISH_STATUS_REPORT_BLOCK}}`.
- Parameterize all four agents' invocation triggers (multi-language); lock git-bound output (commit title/body, PR) to English regardless of trigger/report language.
- `profile-generator` 1.1.0 — case 1/2/3 conventions-doc resolution + stack-aware `CONVENTIONS.md` seed when none exists; de-jargoned interview.
- `react-agents` README: mermaid agent→skill chart + per-agent examples.

### Kit-wide
- Tiered structure (cross-cutting `dev-core` above domain `react-core` / `react-agents`); documented in CLAUDE.md (§1 tier model, §7 naming rule, decision D6).
- Archive `pps-web-profile` as a worked example (out of the marketplace); remove `NOTICES.md` (no third-party attribution to track).
- Minimal root README (146 → 44 lines).
- Fix `validate-contract.sh --strict` unbound-variable when `_in-progress/` is empty.

### `react-core` 0.4.0
- **react-perf cleanroom rewrite** — all 40 rule files rewritten from scratch (no upstream consultation). Each rule now states the symptom, a realistic Incorrect → Correct contrast, and an explicit "When NOT to apply" section. `SKILL.md` bumped to v2.0.0; fork-only `README.md` deleted (skill is now standalone).
- Drop the `vercel-labs/agent-skills` attribution from `react-perf` — content is no longer derived. `NOTICES.md` simplified accordingly; root README and plugin README updated to drop "curated fork" framing.

### `react-core` 0.3.0
- Folder rename pass for clarity. `rules/client/` → `rules/runtime-io/`, `rules/rerender/` → `rules/prevent-rerender/`, `rules/rendering/` → `rules/render-output/`, `rules/js/` → `rules/js-micro/`. The old names were inherited from upstream and conflated distinct concerns (`rerender` vs `rendering` were near-homophones; `client` was over-generic in a CSR codebase).
- Rule file renames in `react-perf`: `async/parallel.md` → `async/parallel-promises.md`, `bundle/conditional.md` → `bundle/conditional-load.md`, `prevent-rerender/dependencies.md` → `prevent-rerender/narrow-effect-deps.md`, `prevent-rerender/memo.md` → `prevent-rerender/memo-component.md`. The old names were too generic to find by search.
- Rule file rename in `react-composition`: `react19/no-forwardref.md` → `react19/ref-and-context.md` (the rule covers both `ref` as a prop and `use(Context)` — the old name reflected only half).
- `SKILL.md`, `README.md` (where present), and `_sections.md` updated to match.

### `react-agents` 0.1.0
- New plugin shipping three agent templates (`implement` / `polish` / `pre-commit`) with `{{PLACEHOLDER}}` substitution points for project-specific content.
- New `profile-generator` skill (`/profile-generator`) — interactive 4-round AskUserQuestion flow that gathers project facts, substitutes placeholders, and writes a complete filled-in profile (agents + plugin.json + README + optional UI inventory stub) to a user-chosen folder.
- Ships `docs/PLACEHOLDER-REFERENCE.md` (all 22 placeholders documented with example values from `pps-web`) and `docs/FORK-GUIDE.md` (manual fork procedure).

### Marketplace
- Added `react-agents` to `marketplace.json`.
- Reframed `pps-web-profile` as a worked example rather than primary distribution.

## [0.1.0] — 2026-05-20

Initial extraction from the in-tree `Aware Payroll/claude-kit/` into a standalone plugin marketplace.

### `react-core` 0.1.0
- Added six skills: `react-perf`, `react-composition`, `react-audit`, `react-revamp`, `react-ux-review`, `react-dry`.
- De-coupled from `pps-web`: `react-audit` Phase E now references the user's project conventions doc (template at `docs/CONVENTIONS.template.md`) instead of `pps-web/CLAUDE.md`; `react-dry` example codebase path generalized.
- Provenance preserved: `react-perf` and `react-composition` retain `derived_from: vercel-labs/agent-skills` in frontmatter and full upstream mapping in their READMEs.

### `pps-web-profile` 0.1.0
- Added one skill (`pps-ui`) and three agents (`web-implement`, `web-polish`, `web-pre-commit`) verbatim from the in-tree kit.
- README explicitly marks this plugin as project-bound and points readers at the agents themselves as a forking template.
