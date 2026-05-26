# Test plan

Living doc for validating claude-kit before Phase 3 GA. Goal: prove the templates → profile-generator → filled-in profile pipeline produces a correct, regression-free result on `pps-web-profile`, then on a second project, then graduate experimental skills.

The kit ships **two source-of-truth artifacts** today that we want to collapse to one:

- `plugins/pps-web-profile/agents/web-*.md` — hand-authored, currently the live reference profile
- `plugins/react-agents/templates/agents/*.template.md` — generic templates derived from the hand-authored ones

Until `profile-generator` is exercised end-to-end on `pps-web` and its output matches the hand-authored version, **we have not validated the kit's central architectural claim** ("templates produce profiles"). Layer B below is that test.

## Layers (A → H)

| Layer | What | Depends on |
|---|---|---|
| A | Static checks (validators + list-skills + CI) | — |
| B | **Generator validation** — regen `pps-web-profile` from templates, diff vs hand-authored, cut over | A |
| C | Install verify in a fresh Claude Code session | B (so install pulls the cut-over profile) |
| D | Per-skill smoke test | C |
| E | Per-agent smoke test | C, B |
| F | End-to-end real PR | E (opportunistic) |
| G | Portability — run generator on a second React project | B, F (Phase 3 GA gate) |
| H | Promote experimental skills (`react-debug`, `react-scrutinize`, `react-post-mortem`) | usage trigger |

## Layer A — Static checks

```bash
./scripts/validate-frontmatter.sh
./scripts/validate-contract.sh --strict
./scripts/list-skills.sh
```

CI runs all three on every push and PR. Pass criteria: 3/3 exit 0.

## Layer B — Generator validation (critical path)

The goal of this layer is to eliminate the 2-source-of-truth problem. After it passes, the hand-authored agent files in `plugins/pps-web-profile/agents/` are replaced by regenerated output, and templates become the single source.

### B0 — Tag baseline (rollback safety)

```bash
git tag v0.4.0-baseline -m "Pre-cutover baseline before regenerating pps-web-profile from templates"
git push origin v0.4.0-baseline
```

If Layer B's cutover introduces a regression, `git checkout v0.4.0-baseline -- plugins/pps-web-profile/agents/` restores the hand-authored files.

### B1 — Dry-run regen to scratch

In a Claude Code session with the kit installed:

```
/profile-generator
```

Answer the 28 questions with `pps-web` values (see "Answer crib sheet" below). Set the output folder to a scratch path that is **not** `plugins/pps-web-profile`:

```
~/Workspace/_scratch/pps-web-regen
```

Pass criteria: generator completes without error, writes 4 agents + plugin.json + README to the scratch path.

### B2 — Per-agent diff

```bash
for a in web-implement web-polish web-pre-commit web-test; do
  echo "=== $a ==="
  diff -u "plugins/pps-web-profile/agents/$a.md" \
          "$HOME/Workspace/_scratch/pps-web-regen/agents/$a.md" \
    | head -80
  echo
done
```

Record raw output in the run log (`docs/test-runs/<date>.md`).

### B3 — Triage matrix

Classify every diff hunk into one of five categories:

| Category | Definition | Action |
|---|---|---|
| `noise` | whitespace, frontmatter key order, blank-line count, trivial formatting | accept; if the same noise repeats, fix generator's output normalization |
| `template-bug` | a `{{PLACEHOLDER}}` wasn't substituted, or was substituted incorrectly | fix the template; re-run B1 |
| `generator-bug` | substitution logic in `profile-generator/SKILL.md` is wrong (missing case, wrong order) | fix the generator; re-run B1 |
| `inventory-gap` | the hand-authored file has content that the template doesn't cover at all (e.g. project-specific MC sections, anchor lists) | add a new placeholder to `PLACEHOLDER-REFERENCE.md`, add a value to the generator, edit the template; re-run B1 |
| `hand-authored-bug` | regenerated output is correct; hand-authored has a stale/inconsistent value (e.g. wrong MC count, leftover trigger keyword) | accept regen; the cutover fixes it |

Record one row per hunk in the run log.

### B4 — Iterate

Repeat B1 → B3 until the only remaining diffs are `noise` or `hand-authored-bug`. Each iteration is cheap once the generator is correctly configured — most of the cost is the 28-question dialog.

### B5 — Cut over

```bash
cp $HOME/Workspace/_scratch/pps-web-regen/agents/*.md plugins/pps-web-profile/agents/
git diff plugins/pps-web-profile/agents/   # final review
git commit -m "chore(pps-web-profile): regenerate agents from templates"
```

Pass criteria: agents now generated, not hand-edited. Future template changes regenerate everywhere via one path.

### B6 — Regen verification CI (Phase 3 hardening, optional)

Add a CI job that runs the generator headlessly (preset answers) and diffs against committed `pps-web-profile/agents/`. Fail if drift. This makes template-vs-profile divergence impossible to ship.

### Answer crib sheet (B1)

For the interactive `/profile-generator`, use these values for `pps-web`:

| # | Question | Answer |
|---|---|---|
| 1 | Project name | `pps-web` |
| 2 | Agent prefix | `web` |
| 3 | Stack | `React 19 / TS / Vite / Tailwind / Radix` |
| 4 | Output language | `Thai` |
| 5 | Conventions doc | `pps-web/CLAUDE.md` |
| 6 | MC sections count | `7` |
| 7 | Structure doc | `pps-web/docs/architecture/feature-structure.md` |
| 8 | Progress doc | `pps-web/docs/progress.md` |
| 9 | Features root | `src/features` |
| 10 | Polished page examples | `PayrollListPage, PayrollDetailPage, DepartmentListPage, EmployeeListPage, EmployeeDetailPage, PaymentDocumentDetailPage` |
| 11 | Docs root | `pps-web/docs` |
| 12 | Build cmd | `cd pps-web && npm run build` |
| 13 | Dev cmd | `cd pps-web && npm run dev` |
| 14 | Test cmd | `npm run test` (note: pps-web's package.json has only `scripts.test`, not `scripts.test:unit`) |
| 15 | Lint:structure cmd | `npm run lint:structure` |
| 16 | Lint:structure strict | `npm run lint:structure:strict` |
| 17 | Polish audit script | `pps-web/scripts/page-polish-audit.mjs` |
| 18 | Swagger URL | `https://payroll-dev-api.aware.co.th/swagger-ui/index.html` |
| 19 | BE-scope triggers | `Thai: เช็ค BE, เช็ค swagger, sync api; English: check BE, verify BE, sync api types` |
| 20 | API services paths | `pps-web/src/services/api.ts, pps-web/src/services/http.ts, pps-web/src/services/case-transform.ts` |
| 21 | Test coverage cmd | `cd pps-web && npm run test:cov` |
| 22 | Test infra root | `pps-web/src/test` |
| 23 | Test canonical baseline | `pps-web/src/features/holiday/` |
| 24 | Test canonical files | (multi-line list — see `PLACEHOLDER-REFERENCE.md`) |
| 25 | Apply keyword | `เริ่ม` |
| 26 | UI inventory skill | `pps-ui` |
| 27 | Output folder | `~/Workspace/_scratch/pps-web-regen` |
| 28 | Profile description | `Aware pps-web project profile: implement/polish/pre-commit/test subagents wired to MC-1..MC-7, plus pps-ui primitive inventory` |

## Layer C — Install verify

In a fresh Claude Code session opened on `~/Workspace/Aware Payroll`:

```
/plugin marketplace update
/plugin install react-core@claude-kit
/plugin install react-agents@claude-kit
/plugin install pps-web-profile@claude-kit
/agents
```

Pass criteria: 3/3 plugins install; `/agents` shows `web-implement`, `web-polish`, `web-pre-commit`, `web-test`.

## Layer D — Per-skill smoke

| Skill | Test prompt | Expected output shape |
|---|---|---|
| `/react-perf` | (invoke) | Quick Index + 7 sections + 40 rules listed |
| `/react-composition` | (invoke) | 8 rules across 4 categories + Quick Index |
| `/react-audit` | "audit Button usages" | gate Step 1-5 + finding table |
| `/react-revamp` | "revamp LeaveListPage" | gate Step 1-5 |
| `/react-ux-review` | "review UX of EmployeeListPage" | 9-dimension critique |
| `/react-dry` | "audit Card padding across pages" | findings table |
| `/react-test-patterns` | (invoke) | reference content + patterns by layer |
| `/pps-ui` | (invoke) | primitive inventory table |
| `/react-debug` | (invoke) | 5-step protocol + when NOT to apply |
| `/react-scrutinize` | (invoke + diff + intent) | alignment + scope-creep matrices + verdict |
| `/react-post-mortem` | (invoke + incident details) | filled markdown template |

Pass criteria: each skill loads and matches the shape documented in its `SKILL.md`.

## Layer E — Per-agent smoke

Choose tasks that do **not** touch production code.

| Agent | Test prompt | Verify |
|---|---|---|
| `web-implement` | "เพิ่ม comment 1 บรรทัด ใน schemas/holiday.schema.ts" | Step 0 → STOP → Thai report → MC-1..MC-7 status lines all present |
| `web-polish` | "polish my diff" (with a trivial uncommitted change) | TABLE-FIRST → STOP for row pick |
| `web-pre-commit` | "review my changes" (trivial staged diff) | 3-mode gate + Pre-flight (secrets/WIP/lockfile) + commit draft in English |
| `web-test` | "เขียน test ให้ src/features/categories" | retrofit mode auto-detected → 5-layer audit → STOP for `เริ่ม` |

Pass criteria: 4/4 agents Step 0 → STOP → confirm flow works; no agent commits; output language matches.

## Layer F — End-to-end real PR

Trigger: next real feature task on `pps-web`. Use the full trio:

```
web-implement → web-polish (optional) → web-pre-commit → git commit
```

Pass criteria: 1 PR ships without regression vs the pre-cutover version. MC self-check passes; Swagger drift gate fires when API surface changes.

## Layer G — Portability

The real Phase 3 GA test. Run on a project that is **not** `pps-web`.

Candidate projects in `~/Workspace`:

- `guru-web` / `guru-web-admin` — confirm React 19 / Vite stack first
- New Vite app created from `npm create vite@latest`

Steps:

```
cd ~/Workspace/<other-project>
/plugin install react-agents@claude-kit
/profile-generator   # answer for <other-project>
```

Pass criteria:

- 28 questions complete; profile written to chosen output folder.
- Generated agents contain **zero** strings from `pps-web` (grep for `pps-web`, `payroll-dev-api`, `holiday/` baseline references — any match is an unmasked hardcode).
- A `<prefix>-implement` smoke task works on that project.

## Layer H — Promote experimental skills

Three skills currently in `plugins/react-core/skills/_in-progress/`:

| Skill | Promotion trigger |
|---|---|
| `react-debug` | invoke during a real debug session; the 5-step walk leads to the bug |
| `react-scrutinize` | invoke on a real PR; the alignment/creep matrices catch something the reviewer would have missed (or confirm clean alignment) |
| `react-post-mortem` | use to draft a post-mortem for a real incident or near-miss |

Promotion procedure per skill:

1. `git mv plugins/react-core/skills/_in-progress/<skill> plugins/react-core/skills/<skill>`
2. Edit frontmatter: `status: experimental` → `status: stable`
3. Bump `metadata.version` to `1.0.0`
4. Add skill name to `plugins/react-core/README.md` skills table and to `plugins/react-core/.claude-plugin/plugin.json` description
5. Bump `react-core` plugin version (minor bump per stable skill added)
6. Re-run `./scripts/validate-contract.sh --strict` — must show 0 warn, 0 fail (rule 2 now requires the skill to appear in a public surface)
7. Commit + CHANGELOG entry

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Generator output diverges from hand-authored in meaningful detail | high | Layer B triage; iterate B1 until clean |
| Big-bang diff is overwhelming | medium | Diff per agent (4 small reviews) instead of all-at-once |
| Updated plugin in pps-web changes agent behavior | low | Layers C+D before any real task; rollback via `v0.4.0-baseline` tag |
| Generator is buggy → fails on second project too | high (untested) | Layer B catches before Layer G |
| Subtle MC / convention mismatch from template generic-ization | medium | Layer E's MC self-check catches; iterate inventory-gap category |

## Artifacts

| File | Purpose |
|---|---|
| `docs/TEST-PLAN.md` | This plan |
| `docs/test-runs/<YYYY-MM-DD>.md` | Per-session log: which layers ran, diff results, issues found |
| git tag `v0.4.0-baseline` | Rollback safety before Layer B cutover |

Each test run appends a row to a "Recent runs" table at the bottom of this file:

| Date | Layers run | Outcome | Run log |
|---|---|---|---|
| _(none yet — first run pending)_ | | | |
