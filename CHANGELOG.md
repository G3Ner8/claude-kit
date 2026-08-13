# Changelog

All notable changes to this kit are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the kit uses [Semantic Versioning](https://semver.org/).

Plugins are versioned independently in their `plugin.json`. The headings below group changes by plugin.

## [Unreleased]

### `agent-profiles` 0.7.0
- **Templates no longer name any skill directly.** All 37 hardcoded `react-*`
  references across the four templates became slots resolved from what the
  *target repo* actually ships. This is what kept Angular and Vue out; a repo
  that ships none of these skills now gets a working profile instead of agents
  ordered to invoke things that do not exist.
- **Two kinds of slot, and the difference is the skill's own `metadata.type`,
  not a judgement call.** `gate` skills (audit, revamp, ux-review, dry,
  test-patterns) render in one of two forms and are **never empty** — unfilled
  means *run it yourself*, so the step survives and only the delegation is lost.
  `reference` skills (perf, composition, debug) collapse to empty, taking their
  table row or sentence with them, because the model already knows the stack's
  performance and composition idioms.
  - `implement` carries an explicit instruction that an unfilled gate cell is
    not permission to skip: produce the same findings table, cite `file:line`,
    and stop for approval exactly as if a skill had reported.
- `profile-generator` 1.5.0: new **Skill-wiring resolution** step scans the
  target repo's `.claude/skills/`, matches candidates to slots by name, and
  **proposes the mapping for the user to correct** rather than auto-wiring.
  Repos routinely keep skills there that have nothing to do with these four
  roles — issue filing, test-case generation — and wiring everything found would
  order an agent to file an issue mid-refactor. No repo `.claude/skills/` is a
  normal outcome, not an error.
- `profile-generator`: **verifies its own output for the first time.** Step 5 now
  greps the written agents for `{{` and refuses to report success while any
  unsubstituted placeholder remains. Nothing downstream catches that — the kit's
  validators read plugin sources, never generated profiles — and the slot count
  just grew by sixteen.

### `agent-profiles` 0.6.3
- **Scope decided: frontend, JS/TS** (D16). The `package.json` requirement was
  described one release ago as one of two fixable defects; it is now the declared
  boundary. Backend repos use `dev-core`, which is stack-agnostic and needs no
  profile — and the four roles do not transfer there anyway: on a service,
  `harden` and `verify` mean infrastructure-dependent integration tests and a
  contract/blast-radius check with no frontend analogue.
- That leaves **one** real defect rather than two: the 37 hardcoded `react-*`
  skill references, which are what still keep Angular and Vue out. README says so
  explicitly, separating the deliberate boundary from the thing still to fix.
- Removed from the roadmap: multi-manifest support (`pom.xml`, `go.mod`,
  `pyproject.toml`, `Cargo.toml`, `build.gradle`).

### `agent-profiles` 0.6.2
- README states the real scope limit. "React 19 / Vite projects only" gave the
  right advice for the wrong reason — it reads as a design boundary. Measured:
  the generator locates a project by `package.json` alone (no `pom.xml`,
  `go.mod`, `pyproject.toml`, `Cargo.toml`, `build.gradle` anywhere in it), so
  the *mechanism* is JS/TS-bound, not React-bound; what makes the *output*
  React-bound is the 37 hardcoded `react-*` skill names in the templates plus
  the test template's Vitest/RTL assumptions. Both are fixable defects, and the
  four roles themselves are stack-neutral. Saying so keeps a defect from
  hardening into a documented feature.

### `agent-profiles` 0.6.1
- README accuracy pass. The mermaid agent→skill chart still used `POL` / `PRE`
  as node ids after the role rename — labels read `harden` / `verify` while the
  ids and their seven edge references did not, so renaming only the declarations
  would have produced orphan nodes. All ids and edges are now `HRD` / `VRF`. The
  `dev-core` note listed three skills; that plugin has had six since `architect`,
  `drafter`, and `surveyor` shipped.

### `react-core` 0.5.4
- README: the "stack-agnostic disciplines live in dev-core" note listed three
  skills. dev-core has six — `architect`, `drafter`, and `surveyor` were missing.
  Docs-only; no skill content changed.

### `dev-core` 0.18.4
- README: "the `react-*` plugins sit at the domain layer below" stopped being
  true when `react-agents` became `agent-profiles`. Now names both domain plugins
  explicitly. Docs-only; no skill content changed.

### `dev-core` 0.18.3
- `inspector` 0.2.4: **stops naming agents by a convention it does not own.** Five
  references pointed at `*-verify`, `*-harden`, `*-implement` — a naming scheme
  `agent-profiles` defines, one tier *below* dev-core. Section 1's rule is
  explicit: "a plugin never depends on something downstream of it." The proof it
  was wrong: renaming a suffix in `agent-profiles` forced edits in dev-core, a
  plugin that has nothing to do with it. Coupling that generates work when an
  unrelated thing changes is coupling that should not exist.
  - The references now name the *function* instead: "the project's ship gate —
    whatever runs its build, lint, and tests", "whichever agent implements". Just
    as actionable, and true in a repo whose agents are called anything at all, or
    that has no agents.
  - `*-implement` predates this session's rename; the violation was not new, it
    was just never load-bearing enough to notice until a rename made dev-core
    move for no reason of its own.
  - `work-core` was checked and has no such binding.

### `dev-core` 0.18.2
- `drafter` 0.12.2: **the `## Phases` example no longer looks like real agent
  names.** `agent-type: harden-agent` reads as a name you can copy; the warning
  that it is illustrative sat *below* the code fence, where it is read after the
  block rather than before. Copy it into an issue for a repo whose agents are
  called something else and the daemon hard-blocks the issue pre-claim — before a
  line of code is written.
  - Every `agent-type:` in the example is now `<prefix>-<role>`, matching the
    angle-bracket placeholder style drafter already uses elsewhere and the
    `<prefix>-*` convention in `agent-profiles`.
  - The warning moved above the fence, states the consequence inline, and says
    explicitly that the role suffix is the target repo's, which may well be
    `-polish` and `-pre-commit` rather than `-harden` and `-verify`.
  - This risk predates the rename — the old example said `polish-agent` /
    `pre-commit-agent`, equally absent from any real repo. The rename only made a
    careless substitution land further from the truth, which is what surfaced it.
  - Structural, not advisory: Operating rule `:212` already required confirming
    names with the user. That rule stays; this makes the example uncopyable so the
    rule is not the only thing standing between a typo and a blocked issue.

### `dev-core` 0.18.1
- `inspector` 0.2.3, `drafter` 0.12.1: follow the role rename below. `inspector`
  now points at `*-verify` instead of `*-pre-commit` (description + two body
  references) and names `*-harden` as the agent that extracts scope creep;
  `drafter`'s `## Phases` example uses `harden-agent` / `verify-agent`. Reference
  updates only — no procedure change in either skill.

### `agent-profiles` 0.6.0
- **Renamed from `react-agents`.** Reinstall as `agent-profiles@claude-kit`; the
  old plugin name no longer resolves. The plugin is a generator plus four role
  templates, not a React asset — measured coupling is 2-4% for three of the four
  templates and 5% for the generator. The old name was blocking non-React use for
  no reason.
- **Role rename: `polish` → `harden`, `pre-commit` → `verify`** (template files,
  `name:` frontmatter, and the `<prefix>-*` filenames the generator writes).
  "polish" reads optional, which is how the post-exploratory cleanup step gets
  skipped; "pre-commit" names a git moment that does not exist in a headless
  phase chain, where the runner commits per phase. `implement` and `test` are
  unchanged.
- **Six placeholders reclassified, not just renamed.** `POLISH_AUDIT_*`,
  `POLISH_STATUS_*` and `POLISHED_PAGE_EXAMPLES` were never about the agent —
  they describe the *target project's* page-status vocabulary. They are now
  `PAGE_STATUS_AUDIT_CMD` / `_SOURCE` / `_SCRIPT_REF`, `PAGE_STATUS_CHECK_SECTION`
  / `_REPORT_BLOCK`, and `REFERENCE_PAGE_EXAMPLES` (which pairs with the existing
  `REFERENCE_PAGE_TERM`). Four genuinely role-scoped ones became `HARDEN_*` /
  `VERIFY_*`. A profile generated before this release keeps working; only
  regeneration is affected.
- `profile-generator` 1.4.0: placeholder + role vocabulary updated throughout, and
  **project-internal values removed** — nine places carried real values from a
  private repo (agent-prefix examples, a scratch output path, a feature-folder
  name, two maintainer notes, a troubleshooting line). All now use the fictional
  `shop-web` / `myapp` convention `PLACEHOLDER-REFERENCE.md` was already following.
  D10 deleted the archived worked example for exactly this reason but never swept
  the values embedded in the generator's prose.
- `harden` template: persona rewritten. The file still introduced itself as a
  "Cleanup & Consistency Specialist" — the same optional-sounding framing the
  rename exists to remove.
- Left deliberately untouched: the `scripts/*{polish,status}*audit*` glob, which
  is a **discovery contract with the target repo** — the project owns that
  filename, the generator only looks for it. Renaming it to match our vocabulary
  breaks discovery; a comment now says so.
- **Correction to the `react-agents` 0.5.3 entry below.** Its premise — "no
  consuming project with a `.claude/agents/` directory at all" — is false. A
  consuming project has had four generated agents in daily use since June, with
  maintenance commits. The census read 0 because agents cite skills as prose
  rather than through the Skill tool, and because the generator ran before the
  census window opened. The `stable` → `experimental` demotion still stands (the
  bar is 2+ real teams); only the stated reason was wrong.

### `react-agents` 0.5.3
- `profile-generator` 1.3.3: demoted `stable` → `experimental`. Section 11 rule 4
  requires a `stable` skill to be battle-tested and cited in agents; a usage
  census over 30 days of local session logs found 0 invocations and **no
  consuming project with a `.claude/agents/` directory at all** — the generator
  has never produced a profile in use. Not deprecated: the trigger for that is 30
  more days with nothing generated. See D14 in CLAUDE.md.

### `react-core` 0.5.3
- All 8 skills demoted `stable` → `experimental` (same census, same rule): 6 of
  the 8 saw 0 invocations in 30 days, and with no generated profile anywhere,
  nothing cites them. The skills themselves are unchanged — this is an honesty
  fix to the lifecycle claim, not a content change. See D14 in CLAUDE.md.

### `dev-core` 0.18.0
- `drafter` 0.12.0: **the pre-merge intent gate is now named, twice.** The census
  that prompted D14 found `inspector` at 0 invocations while `drafter` ran 20 and
  `architect` 16 — work flowed plan → order → implement → nothing. Cause: drafter
  had absorbed inspector's *lens* into its Step 6 self-check, which grades the
  work order, not the work. The downstream run against the agent's actual MR was
  never named anywhere, so it never happened.
  - Step 5: the Acceptance Criteria list now closes with the intent gate as a
    contract line — work beyond the order's scope, or AC left unmet, is a
    bounce-back rather than a follow-up.
  - Step 7: every handoff reply ends with the pending gate ("when the agent's MR
    lands, run `/dev-core:inspector` against this order before merge"). Drafter is
    the last moment the gate can be named while the user is still looking.
  - New operating rule making both mandatory, and stating that Step 6 does not
    discharge the downstream run.
- `architect` 0.2.0: **interfaces now have to declare their depth, not just their
  signature.** Step 4 asked for exact names, parameters, and return types — so a
  plan could lock in a dozen shallow modules, every signature correct, and pass
  Step 6 clean. Deep module / simple interface is the missing criterion.
  - Step 4 asks what each interface *hides*; one that leaks storage format, call
    ordering, or retry behavior to its caller hasn't hidden anything. Many small
    units became a claim to defend in `## Design` rather than a default.
  - The plan template's `**Interfaces:**` block gains a `Hides:` line — without
    it the criterion never reaches the document the executor reads.
  - Step 6 self-review gains an interface-depth check (now 5 items).
  - Framed as a cost, not a taste: the executor sees only their own task, so
    every neighbor interface they must understand is context they carry. Shallow
    decomposition inflates that reading surface for every task at once.
  - Deliberately **not** included: hexagonal / ports-and-adapters. Architect is
    stack-agnostic; a criterion ("what does this hide?") travels to a React hook,
    a Go package, or a SQL view, while an architecture template would have it
    prescribing adapters for CLI tools that don't want them.
- `surveyor` 0.3.0 (**breaking** — a step is gone): Step 5 "Next up" removed, and
  with it the ranked feasibility ordering. Two reasons, one of each kind.
  Overlap: ranked open work is `sitrep`'s job and `sitrep` does it better — it
  has carry-over memory, loop ages, and live re-verification, where surveyor
  re-derived an ordering from scratch each run. Risk: a survey that ends in a
  ranked list is one step from choosing the work, and that call has to stay with
  the human — pick wrong and the rework cascades downstream. What remains is the
  one job nothing else in the kit does: the drift audit (declared status vs
  merged history, real code, deployment) plus the sync offer.
  - Step 6 renumbered to 5; the report format's Next-up block dropped;
    description, When-to-use, and the dev-core README's row realigned to "is the
    status right", not "what next"; triggers lost `"what's next"`.
  - Operating rule `Recommend, don't decide` → `Measure, don't direct`, and a new
    `You DON'T` line forbidding a closing "start here" however it's justified.

### tooling
- `scripts/hooks/validate-on-edit.sh` (new) + `.claude/settings.json`: a
  `PostToolUse` hook runs `validate-frontmatter.sh` and `validate-contract.sh`
  whenever a `SKILL.md`, `plugin.json`, or `marketplace.json` is written, and
  blocks with the failure output attached. CLAUDE.md Section 10 previously asked
  contributors to remember four validators; the two that guard the contract no
  longer depend on that. Unrelated edits cost one `case` test.
- `scripts/validate-frontmatter.sh`: fixed an abort on its own failure path —
  under `set -u`, bash 3.2 (the macOS default) treats `"${warnings[@]}"` as
  unbound, so any file with errors but no warnings crashed the run instead of
  reporting. Latent since the failure path had never executed; found while
  pipe-testing the hook against a deliberately broken frontmatter.

### `work-core` 0.2.1
- `sitrep` 0.2.1: **a session is an interval, not a point in time.** The collector
  reduced each session to `start` + a total `active_min`, so every day/week
  rollup bucketed the whole session on the day it *opened*. A real session that
  ran 29→31 Jul reported as `29 Jul | 11.0h` — the true split was 2.2h / 5.2h /
  3.7h. The total was right; the attribution was off by two days, which is
  exactly the number the timesheet appendix copies. Found by auditing a briefing
  against its own logs after the day-by-day table failed to match memory.
  - Sessions now carry `per_day` (active minutes) and `tok_day` (output tokens),
    accumulated where the per-event timestamps still exist. Each inter-event gap
    is credited to the day it starts.
  - `active_days()` is the one place day/week rollups iterate. Daily log, the
    monthly week × project trend, and the project span all read it — the weekly
    trend was silently mis-bucketing sessions across week boundaries too.
  - Multi-day sessions print a `split:` line (`29 Jul 2.2h · 30 Jul 5.2h · …`)
    and a `29 Jul–31 Jul` span, so the model composing the timesheet can never
    infer a single-day claim from a multi-day session.
  - Token totals are conserved: weekly rows now sum to the digest's Totals line
    exactly, rather than double-counting a spanning session's tokens in both weeks.

### `work-core` 0.2.0
- `sitrep` 0.2.0: trust, safety and cost fixes, all found by auditing real
  briefings against the collector that produced them.
  - **Credentials are redacted before the digest leaves the collector.** Session
    gists are raw user prompt text, and a live bearer token was sitting in a real
    digest — API keys, passwords and connection strings get pasted into prompts
    routinely. From the digest a secret reaches the model's context and then a
    briefing file that gets pasted into chats and timesheets. `scrub()` now
    replaces credential-shaped runs (`Bearer …`, `sk_`/`ghp_`/`glpat_`/`awr_`/
    `xoxb_` prefixes, AWS `AKIA…`, JWTs, `password=`/`token=`/`api_key=`
    assignments, and credentials embedded in URLs) with `[redacted]`, keeping the
    label where the match was an assignment. It runs before truncation, so a
    secret cut mid-string cannot leak its prefix, and covers every path out of
    the collector: session gists, MR/PR titles, and commit subjects. Redaction
    belongs in the deterministic layer — the model is never handed a live
    credential and trusted to summarize around it. A matching operating rule
    forbids writing any secret into a briefing, from the digest or elsewhere.
  - **Loop re-verification is capped at 12 per run**, oldest first, with anything
    past the cap re-carried as `(unverified this run)` and named in the footer —
    each check is a network call, and the re-verify step shipped in this same
    release had no bound. `git fetch` is likewise scoped to the repo owning the
    loop rather than every repo scanned.
  - **Leaner in tokens.** The skill body cost more per invocation (3,441 tok) than
    the data it processes, so the prose was cut without dropping a rule
    (3,441 → 3,078). Digest side: `end:` gists halved to 80 chars (a session's
    last words are mostly mid-thought prose) and merged MR/PR titles capped at 5
    instead of 8 (they repeat far more than open ones) — a 7-day digest went
    2,732 → 2,420 tok. Runtime was measured at 2.2-2.8s and deliberately left
    alone. Net: ~6,200 → ~5,500 tok per run.
  - **Project labels were silently truncated.** The label came from the encoded
    project directory name, where `/` is stored as `-` — so a hyphen inside a
    real directory name was indistinguishable from a path separator and every
    hyphenated project lost its head: `claude-kit` → "kit", `pps-web` → "web",
    `spec-distiller` → "distiller". Worse, `~/Workspace` and `carsol-workspace`
    both reduced to "workspace" and the collision check missed them (they differ
    only by case). The composing model had been quietly repairing these names
    from conversation context — a guess presented as ground truth, against the
    skill's own digest-only rule. Labels now come from the session's real `cwd`,
    resolved to its git toplevel: exact, and it splits work that shared a parent
    directory. Collision widening now matches case-insensitively, and a session
    with no `cwd` on any event falls back to the old derivation marked `?`.
  - **Carried open loops are re-verified against live state.** Absence from the
    digest was treated as evidence a loop was still open, but the digest only
    sees merges inside the window, in repos that happened to be a session cwd —
    so work finished last month looked identical to work still pending. Two
    loops were reported as open for 3-4 weeks after they closed. Step 2 now
    requires a window-free `glab mr view` / `gh pr view` per carried id (and a
    `git fetch` + range check for loops with no id), records the verification
    date in the footer, and names "pushed with no MR opened" as the heavier
    state it is.
  - **Repo discovery is no longer limited to this window's session cwds.** The
    collector keeps a self-maintaining cache of every repo it has ever resolved
    (`~/.sitrep/repos.json`) and scans the union, so work that shipped in a repo
    you never opened locally this window — an agent's MR, a teammate's merge —
    still reaches Accomplished. A week where pps-web saw 4 merged MRs against
    0.3h of keyboard time was the motivating case. Entries whose path is gone
    are pruned each run; a corrupt or unwritable cache degrades to "this run's
    discoveries only" rather than failing. Scanning is capped at 20 repos, this
    run's own repos take contested slots first, and anything the cap drops is
    named in the Git header (the cache file itself keeps the full list).
  - **Commits and MRs/PRs are attributed, because the repo cache made that
    mandatory.** Found by running the skill end-to-end: a cached repo is by
    definition one no session opened this window, so its history is as likely to
    be a teammate's as yours — the first real run offered 173 of a colleague's
    commits and 10 of their merged MRs as raw material for a report headed "what
    I did this week". Commits are now split against the repo's own
    `git config user.email`: yours are listed, everyone else's collapse to one
    `ⓘ NOT yours: N commits by <author>` line, and every MR/PR carries `by
    <username>`. A plain `--author=me` filter was rejected — it would drop work an
    agent identity committed on your behalf, which is exactly what the cache
    exists to surface; naming the author lets the briefing judge instead. Side
    benefit: a repo with 108 of someone else's commits went from eight listed
    commit lines plus a "+100 more" to a single line, so the fix is leaner too.
  - **Effort closes with a delta against the previous same-period briefing.**
    Comparing "~8.8h this week vs ~30.1h last week" was being done by hand or
    not at all. The contract now requires it, restricted to like periods, and
    suppressed when a log horizon makes the earlier total a floor.
  - **The collector declares its own log horizon.** Claude Code prunes session
    logs after `cleanupPeriodDays` (default 30), so a window reaching further
    back reported the pruned span as zero activity rather than as missing data —
    `--month` on a past month was the worst case. The digest now emits a
    `⚠ Log horizon` line naming the uncovered span, and the briefing must treat
    those effort figures as a floor. Git and MR/PR data are unaffected.

### `work-core` 0.1.3
- `sitrep` 0.1.3: sharpen the calendar/meetings support (proven end-to-end
  against a real Microsoft 365 connector). The Meetings step is now
  connector-agnostic (M365/Outlook or Google Calendar), drops cancelled + OOO
  events, and spells out two traps found in real use — convert event times to
  the user's local timezone before placing them on a day, and flag meetings
  that overlap a concurrent session rather than assuming additive hours. The
  Effort section gains a summary line separating keyboard time from meeting
  time (never merged into one total). Blind-spot declarations the user can
  close now carry the fix (no calendar connector → "connect Microsoft 365 via
  /mcp"). Guidance-only; no collector code change.

### `work-core` 0.1.2
- `sitrep` 0.1.2: collector now fetches MRs/PRs **merged inside the window**
  (`glab mr list --merged` / `gh pr list --state merged`, filtered by
  merged_at/mergedAt) and emits them as `✓ merged` lines alongside the existing
  `⚠ open` ones. Fixes a correctness bug: the collector only ever queried *open*
  MRs, so a merged MR reached the digest only as absence — ambiguous — and the
  composer, seeing no signal, would infer "waiting to merge" from a branch name
  and carry it as a stale open loop forever. Contract tightened to match: MR/PR
  status comes only from the digest's Git section (never inferred from a
  branch), and a carried open loop is cleared when the digest shows it merged.

### `work-core` 0.1.1
- `sitrep` 0.1.1: Accomplished section contract now requires a bold project
  header (project — hours — one-line theme) followed by one sub-bullet per
  distinct outcome, instead of one dense paragraph joined by "·" — the closed
  work per project was hard to scan when multiple issues/MRs/decisions were
  crammed onto a single line.

### `work-core` 0.1.0
- New plugin (decision D13): the cross-role tier of claude-kit — personal work-awareness
  skills, independent of stack or role. Where dev-core disciplines work *on a codebase*,
  work-core reports on *your own work* across projects.
- New skill `sitrep` 0.1.0 (action, experimental): personal situation report — daily
  standup / weekly review (default) / monthly rollup, assembled from local ground truth:
  Claude Code session JSONLs, git history, open MR/PR state via glab/gh. A deterministic
  stdlib-only collector (`collect.py`, zero model calls) compresses raw logs into a small
  digest (prototyped on a real week: 69MB → 6.5KB, 1.2s); the session model composes a
  one-page briefing under a fixed four-section contract (Accomplished / Effort / Open
  loops / Next up) with open-loop carry-over between briefings. Window handling:
  `--days N` rolling or `--month YYYY-MM` calendar; stats are window-clipped (a session
  spanning the edge counts only in-window activity, marked `(cont.)`); long windows add a
  week × project effort table, short windows a day × project log feeding a timesheet-draft
  appendix (hours marked `~`, user-adjusted; meetings pulled from a calendar connector
  when reachable, declared a blind spot when not); repos are discovered from every
  distinct session cwd
  (quiet repos aggregated to one line). Demand gate per D13: stays experimental until a
  second real user asks.

### `dev-core` 0.17.0
- New skill `architect` 0.1.0 (decision D12): designs an implementation plan from a spec
  before any code is touched — explores the codebase, names the target and its traps,
  grills open design forks before designing, locks interfaces, decomposes into
  independently testable tasks with checkable acceptance criteria. Upstream of `drafter`
  in the worksite metaphor drafter already referenced ("the architect's rough notes");
  its plan format is knowledge-first so it clears drafter's own triage gate. Promoted out
  of `_in-progress/` after two full headless dry-runs validated the workflow end to end.
- `drafter` 0.11.4 — cross-references `architect` in the opening persona line and the
  skip-trigger, closing the loop now that both personas exist.

### `react-agents` 0.5.2
- `profile-generator` 1.3.2 — frontmatter normalize (decision D11): `stack` now states the
  target project it scans ("React 19 / Vite SPA") instead of "Claude Code plugin
  marketplace"; `scope` finally declares the mutation ("writes files — … auto-install
  copies agents into .claude/agents/") — the action skill's most load-bearing fact, which
  the old "Project profile scaffolding" never said; `derived_from: project-internal`
  dropped.

### `react-core` 0.5.2
- Frontmatter normalize across all eight skills (decision D11): `stack` = target-codebase
  requirement ("React 19 + Vite" + per-skill extras; the "framework-agnostic procedure"
  phrasing that argued with the tier is gone), `scope` = mutation contract + deliverable
  (react-composition/react-perf had stack info in the scope slot), four
  "project-internal" `derived_from` lineage notes deleted (CHANGELOG carries lineage),
  react-test-patterns' evidence-base note deleted from frontmatter (its body's
  "Canonical baseline" section already states it). `react-audit` 1.0.2, `react-dry`
  1.0.2, `react-revamp` 1.0.2, `react-ux-review` 1.0.2, `react-perf` 2.0.2,
  `react-composition` 1.0.1, `react-debug` 1.0.1, `react-test-patterns` 1.1.2.

### `dev-core` 0.16.2
- Frontmatter normalize (decision D11): `stack` collapses four spellings of "any" to
  `any` (surveyor keeps its real requirement: "any (needs git; glab/gh optional)");
  detective's scope moves to the uniform reference pattern. `drafter` 0.11.3,
  `detective` 0.1.2, `inspector` 0.2.2, `surveyor` 0.2.2; `archivist` already matched
  the convention — untouched.
- CLAUDE.md companion fixes: Section 3.1 comments now carry the stack/scope/derived_from
  convention; Section 4's gate definition reworded ("structured workflow → deliverable →
  stop" — "blocks workflow" never described drafter/archivist/surveyor); Sections 3.3 + 4
  stop claiming no action skill exists (profile-generator is one; owes
  Verification/Rollback at its next structural touch); Section 3.2 admits
  discipline-style references (detective, react-debug); Section 5's dead "description
  says experimental" rule dropped.

### `react-agents` 0.5.1
- `profile-generator` 1.3.1 — description diet (see dev-core 0.16.1 below). 585 → 383 chars.

### `react-core` 0.5.1
- Description diet across six skills (see dev-core 0.16.1 below): `react-audit` 1.0.1,
  `react-dry` 1.0.1, `react-revamp` 1.0.1, `react-ux-review` 1.0.1, `react-perf` 2.0.1,
  `react-test-patterns` 1.1.1. `react-debug` and `react-composition` were already lean —
  untouched.

### `dev-core` 0.16.1
- Description diet: frontmatter `description` fields are loaded into every session of
  every consumer, and the 14 skills totalled ~6.9KB (worst: surveyor at 638 chars).
  Trimmed 12 of 14 to ≤450 chars — merged duplicated "Use for"/"Triggers" lists, dropped
  near-duplicate trigger phrasings, kept every distinct trigger surface and core
  directive. Total 6,866 → 5,369 chars (-22%). No body changes. All five dev-core skills
  patch-bumped: `drafter` 0.11.2, `detective` 0.1.1, `inspector` 0.2.1, `archivist`
  0.3.1, `surveyor` 0.2.1.

### Kit-wide
- `scripts/bump-version.sh` (new) — one command for the version-bump ritual (CLAUDE.md
  Section 12 steps 2-4): bumps `plugin.json`, mirrors `marketplace.json`, inserts a
  CHANGELOG stub. The skill's own `metadata.version` stays manual. Verifies its own
  mirror with the same extraction rule 4 uses.
- `scripts/link-check.sh` (new) + CI job — every relative markdown link in tracked `.md`
  files must resolve; external URLs, anchors, and template placeholders are skipped.
  Motivated by the `_archive/` removal, where two dead README links were only caught by
  a manual grep.
- CLAUDE.md Section 2 tree: scripts folder shown as one line (see Section 10) instead of
  enumerating filenames that rot as helpers are added.

## [0.2.0] — 2026-07-03

Everything since extraction: the new stack-agnostic `dev-core` tier (five persona
skills, iterated to 0.16.0), react-agents template decoupling + profile-generator
auto-install, the react-perf cleanroom rewrite, and repo hygiene (validator rules,
`_archive/` removal, README refresh). Plugin versions at this release: `dev-core`
0.16.0 · `react-core` 0.5.0 · `react-agents` 0.5.0.

### Kit-wide
- Removed `_archive/pps-web-profile/` (decision D10). The worked example was generated from
  pre-1.x templates and had drifted from what `/profile-generator` produces today, and it
  carried project-internal detail in a public repo. `react-agents/docs/PLACEHOLDER-REFERENCE.md`
  example values are the reference instead. Files remain in git history; removal is from the
  current tree only.
- Root `README.md` refresh: per-plugin status in the table (dev-core experimental,
  react-core / react-agents stable), a one-line lifecycle pitch for the dev-core personas,
  and the profile-generator output flow updated to the current default
  (`/tmp/<project>-profile` → copy `agents/*.md` into `.claude/agents/`).
- `react-agents` README: "Working reference" now points to `docs/PLACEHOLDER-REFERENCE.md`
  (the two links into `_archive/` were removed with it).
- Root `README.md` install comments reframed by audience instead of optional/required:
  `dev-core` = any stack (the foundational tier), `react-*` = React 19 / Vite projects only.
  The old `# optional` tag on dev-core predated the tier model and read as a demotion.
- `validate-contract.sh` rule 4: marketplace.json version must equal each plugin's
  plugin.json version. The mirror step (CLAUDE.md Section 12) was documented but
  unenforced — a missed mirror means installed consumers silently keep the old cached
  copy. Verified with a negative test (deliberate mismatch fails, exit 1).
- CLAUDE.md Section 2 layout tree pruned to shape-only: it enumerated every skill folder
  (and had already rotted — it listed `_in-progress/react-draft-x`, which doesn't exist).
  The authoritative skill inventory is the Section 1 table + plugin READMEs, kept honest
  by contract rule 1.

### `dev-core` 0.16.0
- `inspector` 0.2.0, `archivist` 0.3.0 — Step 1 now takes inputs from the invocation first
  (the prompt, an issue / work-order body, a calling agent's handoff, a `detective` case
  ledger) and asks via `AskUserQuestion` only for what's still missing, instead of always
  stopping to ask. Removes a wasted round-trip when the inputs were pasted along with the
  invocation, and unblocks headless use — e.g. inspector as a phase in an SDC chain. In a
  headless run with a required input missing, both skills stop and report the gap rather
  than guessing: inspector never infers intent from the diff (circular), archivist never
  drafts around a missing input (a "TBD" post-mortem gets filed and forgotten).

### `dev-core` 0.15.0
- `archivist` 0.2.0 — added the language rule the tier already applied in `drafter` but the
  siblings never inherited: the post-mortem document is English only (it lands in a shared
  record — repo docs, wiki, tracker — same rule as any git-bound artifact), while interactive
  replies adapt to the user's conversation language, technical terms and code staying English.

### `dev-core` 0.14.1
- `drafter` 0.11.1 — date-stamped the empirical best-effort-gap claim (verified 2026-07) and added
  an observable tripwire: if a future SDC transcript shows a successful `Agent`/`Skill`-tool
  invocation of a project-defined target, the read-directly workaround is obsolete — re-run the
  canary and simplify the rule. The claim previously read as timeless; it's a snapshot of the
  harness and will rot silently when the harness fixes registration (failure mode is benign —
  redundant boilerplate, not wrong behavior — hence a tripwire, not a hard expiry).

### `dev-core` 0.14.0
- `drafter` 0.11.0 — structural consolidation, no change to the work order produced. (1) Merged
  the separate "worth it?" bail-out (old Step 1.5) and the sharpness gate (old Step 2) into one
  **Step 2 — Triage** that asks both questions in one analysis pass, cutting a user round-trip and
  removing a forward-reference. (2) Fixed old Step 2.5's inverted order — the knowledge/choreography
  classification rules now precede the "present table + confirm" instruction (previously the reader
  was told to confirm the table before being told how to classify), and corrected the phase-split
  note's temporal reference to a step that hadn't run yet. (3) Renumbered to integer steps
  (1 Locate → 2 Triage → 3 Classify → 4 Transform → 5 Write → 6 Self-check → 7 Handoff), removing
  the `.5` proliferation. (4) De-duplicated the best-effort-gap / read-directly rule, which was
  stated three times — the full rule + evidence now lives once in Operating rules; the Phases block
  and Agent Configuration bullets point to it instead of re-inlining it. (5) Compressed the
  empirical-canary provenance to one clause (the full story stays here in the changelog) and
  trimmed the Quick reference. Net: fewer tokens loaded per invocation, one less interactive stop,
  same output.

### `dev-core` 0.13.0
- `drafter` 0.10.0 — new Step 1.5, an explicit bail-out check run right after the plan is located:
  does it carry discovered knowledge (root cause / trap / constraint-with-why) a fresh grilling
  pass wouldn't recover, external references that need inlining, or orchestration intent that
  needs the read-directly pairing? If none apply, drafter now says so and recommends handing the
  plan straight to `create-issue` (or the target's issue-filing skill) instead of repackaging it —
  a thin, self-contained ask gets no value from the transformation and `create-issue`'s own
  grilling pre-pass produces the same result for less overhead. Distinct from Step 2's gate: Step
  2 asks if the plan is sharp enough, this asks if it's thick enough to be worth repackaging.

### `dev-core` 0.12.0
- `drafter` 0.9.0 — new Step 4.5, a self-check on drafter's own output before handoff: does every
  Acceptance Criterion read as checkable (not "works correctly"), does every Constraint carry its
  why, does every place the agent could otherwise guess appear as an Assumption with the
  park-and-ask instruction, and does Out of scope name the specific adjacent temptation rather
  than a generic disclaimer. Runs the same lens `inspector` would apply to the resulting MR, but
  against the work order itself, so a gap is a paragraph fix here instead of a wrong-but-passing
  MR later. Not a second pass at the source plan (Step 2 already gated that) — a gate on the
  transformation's own output.

### `dev-core` 0.11.0
- `drafter` 0.8.0 — Step 2.5 now scans the plan for sections with materially different
  difficulty (cheap setup vs. a hard core vs. a trivial tail) and, if found, proposes a
  `## Phases` split with a per-phase `model:` in the same confirmation message — folded into
  the existing classification question, no extra round-trip. Gated on difficulty variance, not
  plan length; a long but uniform-effort plan doesn't trigger it. Never a default — the user
  can decline and drafter proceeds as a single pass. Skipped when Step 3's orchestration-intent
  scan already found an explicit named sub-agent chain in the plan (that path is authoritative).

### `dev-core` 0.10.0
- `drafter` 0.7.0 — 0.9.0's `skills:` pairing ("invoke via the Skill tool") was based on the
  daemon's own docs describing `agent-type:`/`skills:` as best-effort; this release corrects it
  against **empirical evidence** from a diagnostic canary persona/skill run eight times under
  varying conditions in a real SDC-onboarded repo. Findings: (1) real `Agent`/`Skill`-tool
  invocation of *any* project-defined target fails outright every time ("not registered" /
  "Unknown skill"), confirmed via live trace capture, not inferred; (2) reading the target file
  directly and applying it inline works reliably every time it was tried — so `skills:` naming a
  **project** skill (bare name) now gets the same read-directly pairing `agent-type:` already
  had, replacing the invoke-via-Skill-tool instruction that doesn't work for that case; (3) a
  **plugin** skill (`<plugin>:<skill>`) has no resolvable path in the target repo, so it keeps the
  invoke-the-skill instruction — but that path is flagged as unverified now, not presented as
  equally solid; (4) the best-effort gap is **transitive** — if a named persona/skill's own
  instructions reference invoking a further skill/agent internally, that nested call hits the
  identical failure, confirmed empirically, and rewriting the shared persona file itself is the
  wrong fix (it also degrades real invocation in normal interactive sessions, which works
  correctly and shouldn't be touched) — drafter now scans each named persona/skill file for its
  own internal references and writes a matching override into the issue body for each one found,
  confirmed to reliably beat the persona file's own wording.

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
