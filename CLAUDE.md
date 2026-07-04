# claude-kit — Meta Guide

> A marketplace of Claude Code plugins for React 19 / Vite SPA work. This file
> is the **north star** — every other file in the repo follows the rules
> defined here.
>
> Treat this as a contract: contributors read this once, then write skills
> and agents that conform. If something here is unclear, the rule wins — open
> an issue to clarify rather than diverging.

**Status**: Phase 1 foundation locked 2026-05-26. D1-D5 resolved at
defaults (see Section 14). Phase 2 (decoupling) next.

---

## 1. Plugin map

claude-kit is a **tiered** personal kit. Skills/agents are organised by how widely they apply — the wider the scope, the higher the tier:

| Tier | Plugin | Role | Depends on | Status |
|---|---|---|---|---|
| **Cross-cutting** (stack-agnostic) | **`dev-core`** | Engineering disciplines usable on any codebase, any stack — persona skills: plan → agent work order (`drafter`), debug (`detective`), intent-validation review (`inspector`), incident post-mortem (`archivist`), project-status survey (`surveyor`) | — | experimental |
| **Domain** (React 19 / Vite) | **`react-core`** | Portable React knowledge — skills consumed by any React 19 / Vite project | — | stable |
| **Domain** (React 19 / Vite) | **`react-agents`** | Templates + a generator skill that scaffolds project-specific agent profiles | react-core (by reference) | stable |

**Tier rule:** a skill belongs to the highest tier whose scope it fully fits. If it works on any stack → `dev-core`. If it assumes React/Vite → `react-core`. Future tiers may break domains down further (per-task layers).

Dependency direction is **one-way**: a profile depends on `react-agents` → `react-core`; domain tiers may reference `dev-core` but never the reverse. A plugin never depends on something downstream of it.

A filled-in profile is **project-specific**, so it is not published to the marketplace — it lives in the consuming project's own repo (generate it with `/profile-generator`). Example placeholder values are documented in `react-agents/docs/PLACEHOLDER-REFERENCE.md` (the old `_archive/pps-web-profile/` worked example was removed — see D10). A second project's profile (e.g. `internal-dashboard-profile`) would be generated the same way and live in that project's repo.

---

## 2. Repository layout

```
claude-kit/
├── CLAUDE.md                    # ← this file (meta-rules)
├── README.md                    # public landing — install + use
├── INSTALL.md                   # marketplace install detail
├── CHANGELOG.md                 # kit-wide release notes
├── .claude-plugin/
│   └── marketplace.json         # plugin catalog
├── scripts/                     # validators + helpers (see Section 10)
└── plugins/
    └── <plugin>/                # dev-core · react-core · react-agents
        ├── .claude-plugin/plugin.json
        ├── README.md
        ├── skills/
        │   ├── <name>/
        │   │   ├── SKILL.md     # mandatory
        │   │   └── README.md    # optional — only when SKILL.md > 400 lines
        │   ├── _in-progress/    # drafts — underscore = excluded from default scan
        │   └── _deprecated/     # retired skills kept for archival
        ├── docs/                # react-agents only (PLACEHOLDER-REFERENCE.md, FORK-GUIDE.md)
        └── templates/agents/    # react-agents only (<role>.template.md)
```

The tree shows **shape, not inventory** — the authoritative skill list per
plugin is the Section 1 table plus each plugin's README (rule 1 of the
contract validator keeps those in sync with reality).

**`_in-progress/`** (underscore prefix) holds drafts. The validator and the
marketplace scan both skip underscore-prefixed folders. Drafts move out of
`_in-progress/` once they pass validation + 1 real-use test.

**`_deprecated/`** uses the same underscore rule for retired skills kept for
archival.

---

## 3. Skill anatomy

Every `SKILL.md` ships with **YAML frontmatter** followed by markdown body.

### 3.1 Frontmatter schema (required fields in **bold**)

```yaml
---
name: <kebab-case>                            # REQUIRED — must match folder name
description: <1-2 sentences>                  # REQUIRED — trigger conditions + core directive
license: MIT                                  # REQUIRED for public skills
user-invocable: true                          # REQUIRED — true = `/skill-name` works directly
metadata:
  version: "1.0.0"                            # REQUIRED — SemVer; bump on breaking changes
  type: gate | reference | action             # REQUIRED — see Section 4
  status: stable | experimental | deprecated  # REQUIRED — see Section 5
  stack: <target-codebase requirement>        # OPTIONAL — what the target repo must be: "any" for the dev-core tier; "React 19 + Vite" (+ skill-specific additions) for the react tier
  scope: <mutation contract + deliverable>    # OPTIONAL — gate: "read-only — produces <X>"; reference: "read-only — reference, consulted during work"; action: "writes files — <what/where>"
  derived_from: <upstream ref>                # OPTIONAL — ONLY a genuine external fork/adaptation; internal lineage belongs in CHANGELOG.md, not here
---
```

### 3.2 Body skeleton (gate + reference skills)

A **gate skill** (audit / review / revamp / dry / ux-review) follows this
exact section order. Names matter — agents grep by header.

```markdown
# <Skill display name>

<1-paragraph operating stance — what the skill is and is not>

## When to use

- <bullet trigger condition>
- ...

Skip this skill for:
- <bullet anti-trigger>

## Step 1 — Gather inputs (MANDATORY before any work)

Do not run `Glob` / `Grep` / `Read` until inputs collected via `AskUserQuestion`.

## Step 2 — Orient
## Step 3 — <Skill-specific phases>
## Step 4 — Report
## Step 5 — Stop conditions

This skill ends with the report. Apply happens elsewhere.

## Operating rules

Governance layer — what the skill MUST / MUST NOT do regardless of input:

- "Cite or it didn't happen" — every finding references `file:line`.
- Read-only — never edit. Apply is the agent's job, not this skill's.
- ...
```

A **reference skill** (perf / composition / test-patterns) has a flatter
structure — it's a manual, not a workflow:

```markdown
# <Skill display name>

<1-paragraph statement of what knowledge this codifies>

## When to use
## <Topic 1> — <heading by domain, not by step>
## <Topic 2>
## ...
## Anti-patterns
## Quick reference
```

Reference skills **don't have a Step N** because there is nothing to "run" —
they are consulted during other work. A **discipline-style reference** (e.g.
`detective`, `react-debug`) may use ordered moves instead of by-domain
headings — it is still a reference as long as it has no input-gathering step
and no stop/report gate; you consult it while working, you don't run it.

### 3.3 Body skeleton (action skill)

For skills that mutate files on their own (no agent in the loop). One exists
today — `profile-generator`. It predates this skeleton and ships
`## Pre-conditions` only; `## Verification` / `## Rollback` are owed at its
next structural touch. An action skill must include:

```markdown
## Pre-conditions (refuse if any missing)
## Apply
## Verification
## Rollback
```

---

## 4. Skill types (3) — `metadata.type`

| Type | What it does | Who calls it | Example |
|---|---|---|---|
| **gate** | Structured workflow — a multi-step flow that ends in a deliverable (findings / proposal / work order / document), then stops; no edits | Agent (Step 0) or user (`/audit`) | `react-audit`, `inspector`, `drafter`, `surveyor` |
| **reference** | Manual that's consulted during work — no workflow, no stop | Agent (during apply) or user (read inline) | `react-perf`, `react-composition`, `react-test-patterns` |
| **action** | Mutates files on its own (no agent needed) — refuses unless preconditions met | User (`/skill-name`) or another agent | `profile-generator` |

Why the distinction matters:
- **Agents invoke gate skills synchronously in Step 0**. If a skill is mistyped as `reference` but actually has a workflow, agents won't wait for its output.
- **Reference skills are linked, not invoked**. They contribute knowledge, not control flow.
- **Action skills are dangerous** — they edit code without the chunked-apply discipline of agents. They MUST refuse loudly when preconditions aren't met (see Section 3.3).

---

## 5. Lifecycle — `metadata.status`

| Status | Meaning | Where it lives |
|---|---|---|
| **stable** | Battle-tested on 2+ real features; SKILL.md complete + cited in agents | `plugins/<plugin>/skills/<name>/` |
| **experimental** | Written + tested once; may still drift (the `status` field carries the flag — don't restate it in `description`) | `plugins/<plugin>/skills/<name>/` (with `status: experimental` in frontmatter) |
| **deprecated** | Retired; kept for archival | `plugins/<plugin>/skills/_deprecated/<name>/` (folder move) |

Draft work that isn't ready for any of the above lives in
`plugins/<plugin>/skills/_in-progress/<name>/` (folder move + status field
isn't required until promotion).

### Promotion path

```
_in-progress/  →  status: experimental  →  status: stable  →  _deprecated/
   (drafts)        (real-use trial)         (locked-in)        (archived)
```

Promotion criteria:

| To | Criteria |
|---|---|
| `experimental` | Frontmatter validates + SKILL.md follows Section 3.2 skeleton |
| `stable` | Cited by ≥1 agent OR used in 2+ real sessions + supervisor sign-off |
| `_deprecated` | Replaced by a successor (link in `description`) OR consensus that the skill is no longer useful |

---

## 6. Agent vs skill — pick the right primitive

| Use a **skill** when… | Use an **agent** when… |
|---|---|
| Knowledge that doesn't change with project state | Behavior that needs to read files + plan + edit |
| Read-only output (findings, table, plan) | Has to enforce a multi-step workflow + chunked apply |
| Called from many agents | Calls multiple skills in sequence |
| Plain `.md` is enough | Needs `tools` (Bash, Edit, Write, Skill, AskUserQuestion) |

Agents live in `plugins/<profile>/agents/<name>.md`. Skills live in
`plugins/<plugin>/skills/<name>/SKILL.md`. **Never** put behavioral
orchestration in a skill — that's an agent.

**Agent continuation (experimental, opt-in).** By default an agent runs
one-shot — the caller spawns it, it works, it reports, its context is gone;
a follow-up means re-spawning with the context rebuilt by hand. If the host
sets `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (off by default), the caller can
instead resume a spawned agent by the id it returns (`SendMessage`), context
intact. This is a **host capability** — agent files need no change to benefit
and MUST NOT depend on it while it's experimental (they must still work
one-shot).

---

## 7. Naming conventions

| Asset | Pattern | Example |
|---|---|---|
| Cross-cutting skill (dev-core) | `<persona>` (bare — no domain prefix; a role noun, not a verb) | `drafter`, `detective`, `inspector`, `archivist`, `surveyor` |
| Domain skill (react-core) | `<domain>-<concern>` | `react-audit`, `react-perf` |
| Project-specific skill (profile) | `<scope>-<concern>` | `dash-ui` (hypothetical) |
| Generator/meta skill | `<noun>-generator` | `profile-generator` |
| Agent (profile-bound) | `<scope>-<role>` | `web-implement`, `web-test` |
| Template file | `<role>.template.md` | `implement.template.md` |
| Plugin folder | `<noun>-<modifier>` | `react-core`, `pps-web-profile` |

**Anti-patterns** (do not):
- `react_audit` (underscore) — kebab-case only
- `audit-react` (concern first) — start with scope
- `do-the-thing` (verb-only) — must name the noun
- `web-test-writer` (extra suffix) — match existing role suffix (`-implement`, `-polish`, `-pre-commit`, `-test`)

---

## 8. Trigger language — English-primary

Agents and skills are **public artifacts** — their `description` fields are
matched against user prompts. To support international users:

- **English trigger phrases are the primary contract.** Every mode + trigger
  appears in the description with an English form.
- **Thai (or other locales) ride along as aliases.** They live in the same
  description, comma-separated, never standalone.
- **Apply approval** uses these triggers universally: `start`, `apply`,
  `go ahead`, `fix it`, plus locale forms (`เริ่ม` for Thai).
- **Reports** can be Thai or English per profile config. The agent's body
  text instructs the output language; the kit doesn't enforce one.
- **Git-bound output is always English.** Triggers and reports may be
  localized, but anything that lands in version control or a remote — commit
  title + body, PR text, push/merge artifacts, in-repo docs the agent syncs —
  is **English only**, regardless of trigger or report language. `pre-commit`
  (the only commit-drafting agent) has a fixed English output for this reason.

**Example** (web-test description):
```
... Triggers - "write tests for X", "test for X", "เขียน test ให้ X",
"expand coverage X", "เพิ่ม coverage X", ...
```

Tooling note: trigger Thai keywords in agent file contribute tokens every
invocation. Prune to 1-2 most-natural Thai variants per English trigger.

---

## 9. Where to put new things

```
I want to add…
│
├── Knowledge / pattern reference (no workflow)
│   └── → plugins/react-core/skills/_in-progress/react-<concern>/SKILL.md
│       (status: experimental on creation)
│
├── Audit / review / proposal workflow (read-only)
│   └── → plugins/react-core/skills/_in-progress/react-<concern>/SKILL.md
│       (type: gate; follows Section 3.2 gate skeleton)
│
├── Project-specific behavior (mutates code, orchestrates skills)
│   └── → plugins/<profile>/agents/<scope>-<role>.md
│       (regenerated from react-agents templates if possible)
│
├── New project profile
│   └── → plugins/<new>-profile/
│       (generated by react-agents/skills/profile-generator)
│
└── Generic template (used by profile-generator)
    └── → plugins/react-agents/templates/agents/<role>.template.md
        (uses {{PLACEHOLDERS}} from PLACEHOLDER-REFERENCE.md)
```

**Decision rule when in doubt**: if it makes sense for any other React
project to consume it, it belongs in `react-core` or `react-agents`. If it
references a specific project's paths/conventions, it belongs in a profile.

---

## 10. Validation

Before committing, run:

```bash
./scripts/validate-frontmatter.sh    # per-file: every SKILL.md has required fields
./scripts/validate-contract.sh       # cross-file: public/hidden contract alignment
./scripts/list-skills.sh             # sanity check the marketplace catalog
./scripts/link-check.sh              # relative markdown links resolve
```

### Per-file rules (`validate-frontmatter.sh`)

1. **Required fields present**: `name`, `description`, `license`, `user-invocable`, `metadata.version`, `metadata.type`, `metadata.status`
2. **`name` matches folder name** exactly
3. **`metadata.type` ∈ {gate, reference, action}**
4. **`metadata.status` ∈ {stable, experimental, deprecated}**
5. **`metadata.version` follows SemVer**
6. **Body has a `## When to use` section** (gate + reference) OR `## Pre-conditions` (action)
7. **Skill in `_in-progress/`** has `status: experimental` or no status (warn, don't fail)

### Cross-file contract rules (`validate-contract.sh`)

1. **Public skills discoverable** — every skill with `status: stable` or `experimental` MUST be referenced from a public surface (root `README.md`, plugin `README.md`, or plugin `plugin.json`). Phase 2: warn. Phase 3 GA: fail (run with `--strict`).
2. **Hidden skills not advertised** — anything under `_in-progress/` or `_deprecated/` MUST NOT appear in any README (always fails).
3. **Marketplace integrity** — every `source` in `.claude-plugin/marketplace.json` points to an existing plugin folder.
4. **Version mirror** — every plugin's `marketplace.json` version equals its `plugin.json` version. The marketplace version is the consumers' cache key (Section 12 step 3); a missed mirror means installed consumers silently keep the old cached copy (always fails).

CI integration (future): run both validators on PR — block merge on failure.

---

## 11. Public-release principles

1. **No hard-coded project paths in templates.** Templates reference
   placeholders; profiles fill them in. The agent files inside a profile MAY
   contain filled-in paths (they're project artifacts), but the templates
   MUST stay generic.
2. **Skill references go through aliases** when used inside templates.
   Templates say `{{AUDIT_SKILL}}`, not `react-audit` — so a project can
   swap their own audit skill in.
3. **Every skill ships English-primary triggers.** Locale aliases are
   supplemental.
4. **Lifecycle is honest.** A skill marked `stable` survives the last 2
   contributors trying it on their own project. Demote to `experimental` if
   doubt creeps in — better than shipping noise.
5. **One skill = one concern.** When a skill grows past ~600 lines or fans
   out to >3 unrelated topics, split it.

---

## 12. Quick reference for contributors

**To add a new portable skill**:
1. Create `plugins/react-core/skills/_in-progress/react-<concern>/SKILL.md`
2. Fill frontmatter per Section 3.1 (status: experimental)
3. Write body per Section 3.2 (gate or reference)
4. Run `./scripts/validate-frontmatter.sh`
5. Use it in a real session — if it survives, move out of `_in-progress/`
   and bump `status: stable`

**To update an existing skill** (behavior or content change):
1. Edit the `SKILL.md` and bump `metadata.version` (SemVer)
2. **Bump the plugin's `plugin.json` version** (minor bump for new behavior,
   patch for fixes) — this is the cache key; skipping it means installed
   consumers keep the old cached copy
3. **Mirror the bump in `.claude-plugin/marketplace.json`** — the version
   there must match `plugin.json`
4. Add an entry to `CHANGELOG.md` under `## [Unreleased]`

Steps 2-4's bookkeeping is one command: `./scripts/bump-version.sh <plugin>
<patch|minor|major>` — it bumps `plugin.json`, mirrors `marketplace.json`, and
inserts the CHANGELOG stub (fill in the TODO). Step 1 stays manual.

**To create a new project profile**:
1. Invoke `react-agents/skills/profile-generator` interactively
2. Answer the interview (see PLACEHOLDER-REFERENCE.md)
3. Generator writes `plugins/<new>-profile/` from templates
4. Run profile's `web-pre-commit` against a real PR to verify

**To deprecate a skill**:
1. Move folder to `plugins/<plugin>/skills/_deprecated/<name>/`
2. Update `description` to point to the successor
3. Search for references in other skills/agents — replace or note as
   "deprecated; see <successor>"
4. Bump `metadata.version` (deprecation is a breaking change)

---

## 13. What's NOT covered here

- **Individual skill mechanics** — read each `SKILL.md`
- **Profile-specific conventions** (e.g. a project's MC-1..MC-7-style
  mandatory-convention rules) — read the profile's own root CLAUDE.md or
  referenced docs
- **Marketplace publication mechanics** — see `INSTALL.md`
- **Skill versioning semantics** — SemVer; major bump = breaking change to
  frontmatter or core procedure

---

## 14. Decision history

Foundational decisions resolved during the Phase 1 foundation pass.

| ID | Decision | Resolution | Locked |
|---|---|---|---|
| D1 | `_in-progress/` (hidden) vs `in-progress/` (visible) | hidden underscore | ✅ 2026-05-26 |
| D2 | Skill types: 2 (gate, reference) vs 3 (+ action) | 3 types | ✅ 2026-05-26 |
| D3 | Agent output language default: English vs Thai | English-primary, Thai alias | ✅ 2026-05-26 |
| D4 | Phase 2 decoupling: wholesale vs duplicate | wholesale templates | ✅ 2026-05-26 |
| D5 | Public timeline: Phase 1 only vs full Phase 3 | Phase 1 internal → Phase 2 beta → Phase 3 GA | ✅ 2026-05-26 |
| D6 | Stack-agnostic skills (`scrutinize`, `post-mortem`): keep in `react-core` vs separate tier | new `dev-core` tier (cross-cutting); bare names, no `react-` prefix (see Section 7) | ✅ 2026-05-27 |
| D7 | dev-core skill names: functional (`scrutinize`/`post-mortem`) vs persona | persona names — `detective` (debug), `inspector` (review, was `scrutinize`), `archivist` (post-mortem). Distinctive + map to lifecycle moments (find → gate → preserve); persona = the opening voice of each SKILL.md. Adds `detective` as the framework-agnostic debug discipline (`react-debug` stays its React-specialized cousin in `react-core`). Supersedes D6 naming. | ✅ 2026-05-27 |
| D8 | Name for the project-status-survey skill | `surveyor` — persona that reads as its job (walks the ground, measures real status vs the declared map). Selection rule extends D7: **legibility first** — the name must telegraph the function (loanword-transparent, like `detective`/`inspector`) over period-flavor; rejected `scrutineer`/`scrivener` as too opaque. | ✅ 2026-06-17 |
| D9 | `foreman` is the industrial-era outlier in the otherwise older-craft persona set — rename? | renamed `foreman` → `drafter`. Same job (turns a crystallized plan into a precise work order for a headless agent), but the name reads as its function (drafts the order) and fits the set's register. Applies the D8 legibility rule; extends D7. Shipped in the same change as `surveyor` (dev-core 0.3.0). | ✅ 2026-06-17 |
| D10 | Keep `_archive/pps-web-profile/` as the worked example vs delete | deleted. The example was generated from pre-1.x templates and had drifted — it misrepresented current `/profile-generator` output — and it carried project-internal detail in a public repo. `react-agents/docs/PLACEHOLDER-REFERENCE.md` example values are the reference instead. Supersedes the worked-example note this file carried in Section 1 (the archiving itself was a CHANGELOG-level move, not a numbered decision). Git history still contains the files; removal is from the current tree only. | ✅ 2026-07-03 |
| D11 | Frontmatter `stack`/`scope`/`derived_from` had drifted into three dialects — normalize or leave? | normalized (Section 3.1 comments now carry the convention): `stack` = target-codebase requirement ("any" for dev-core; "React 19 + Vite" + extras for the react tier); `scope` = mutation contract + deliverable, patterned by type (gate "read-only — produces <X>" / reference "read-only — reference, consulted during work" / action "writes files — <what/where>"); `derived_from` reserved for genuine external forks — all six "project-internal" lineage notes deleted (CHANGELOG carries lineage). Companion doc fixes: gate's Section 4 definition reworded from "blocks workflow" to "structured workflow → deliverable → stop" (matches drafter/archivist/surveyor); Section 3.3/4 stop claiming no action skill exists (`profile-generator` is one; owes Verification/Rollback sections at its next touch); Section 3.2 admits discipline-style references (ordered moves, no stop gate); Section 5's dead "description says experimental" rule dropped (status field carries it). | ✅ 2026-07-03 |
| D12 | New plan-writing skill for dev-core — name + primitive, and merge-into-drafter considered | `architect` — a gate skill (spec → implementation plan), upstream of `drafter` (plan → work order); completes the worksite metaphor drafter already references ("the architect's rough notes"). Runner-up `strategist` (legible, but altitude reads higher than an implementation plan); `planner`/`engineer`/`designer` rejected (dev job titles with the wrong meaning), `cartographer`/`tactician` rejected (opaque per D8), `playwright`/`navigator`/`choreographer` rejected (collide with a test framework / pairing role / drafter's own pejorative). Merge into drafter rejected: the two have contradictory operating rules (architect must explore the codebase; drafter must not re-explore) and merging would collapse drafter's independent Step 2 triage into self-certification of its own plan. Plan format is knowledge-first (target, traps, constraints+why, interfaces, AC; code blocks only where they encode a constraint; TDD loop stated once as execution discipline) so a plan passes drafter triage losslessly. Extends D7/D8. | ✅ 2026-07-04 |

Future decisions append to this table; never edit a resolved row in place —
add a new row referencing the prior decision instead.
