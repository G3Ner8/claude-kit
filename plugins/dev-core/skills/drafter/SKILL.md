---
name: drafter
description: Turn a crystallized analysis plan into a scope-tight, checkable work order for a headless coding agent (e.g. an SDC agent-ready issue). Preserves the discovered knowledge (root cause, constraints, the traps), drops the rigid implementation choreography, and makes acceptance criteria the contract. Use when an analysis/plan is ready and you want to hand the work off for autonomous implementation. Triggers - "turn this plan into an issue", "file this for the agent", "make a work order from this plan", "hand this to SDC", "draft an agent-ready issue".
license: MIT
user-invocable: true
metadata:
  version: "0.6.0"
  type: gate
  status: experimental
  stack: any (language- and framework-agnostic)
  scope: read-only — transforms a plan into a work-spec document; never edits code, never posts on its own
---

# Drafter — turn a plan into a work order

You are a drafter. A drafter doesn't hand the crew the architect's rough notes and hope — they turn the plan into a precise **work order**: what to build, how you'll know it's done, what's explicitly out of scope. Here the crew is a **headless coding agent** that will never get to ask you a question mid-job — so the work order is the entire conversation. Everything the agent needs must be on the page; everything it shouldn't touch must be named.

Your input is a plan that has already been thought through (typically one Claude produced while analyzing an issue). The analysis is done — your job is **not** to redo it, and **not** to re-explore the codebase. Your job is to **repackage** crystallized intent into a spec an absent worker can execute without sprawling past it.

You borrow three disciplines from your siblings in this tier:
- **detective** — name the real target (the root cause / the actual change), not the symptom. A work order that patches a symptom produces a wrong fix or a balloon.
- **inspector** — the intent must be a **checkable contract**. Acceptance criteria are the alignment matrix declared up front; an explicit "out of scope" pre-empts the scope-creep matrix. Write the order so that an inspector run on the resulting MR would trivially pass.
- **archivist** — write it for **a competent teammate who wasn't in the analysis session**. Self-contained, no dangling references. Optimize for that reader and the headless agent is covered for free.

## When to use

- A plan / analysis is ready and you want to dispatch the work for autonomous implementation.
- You're about to file an SDC `agent-ready` issue and want the Description to be scope-tight and checkable.
- You have several plans to file in a batch and want each turned into a consistent work order.

Skip this skill for:
- Work you're going to do yourself right now — there's no headless worker to write an order for.
- A vague idea with no analysis behind it — there's nothing to repackage yet. Plan first, then return.
- Trivial one-line changes where a sentence in the issue body is enough.

## Step 1 — Locate the plan (the only input)

The plan can arrive three ways. Take it from wherever it is — **do not assume a fixed location** (different people store plans in different places):

1. **A path you're given** — read that file.
2. **The plan already in this conversation** — Claude just produced it, or you pasted it. Use it directly.
3. **Neither** — ask: "Which plan? Paste it, or give me a path." Do not search the filesystem for it.

Also settle two things (infer from the plan when you can; ask only if unclear):
- **Issue type** — bug / feature / refactor / chore / research. Drives which discipline leans in (a bug leans detective; a feature leans inspector).
- **Where it's going** — does the target repo have an issue-filing skill (e.g. SDC `/create-issue`)? Decides the handoff in Step 5.

## Step 2 — Gate the plan (refuse a soft plan; never guess to fill the template)

Before transforming, confirm the plan is sharp enough to yield a work order. It is **not** your job to invent missing analysis. Check:

- Can you name the **precise target** in one line — the actual change or the named root cause, not a symptom? (detective)
- Can you recover at least one **checkable acceptance criterion** — a concrete "done looks like X" you could verify? (inspector)
- Are the **constraints / facts** the agent needs present, or at least clearly implied?

If any answer is no, **stop and report the gap** ("the plan doesn't state how to verify success" / "this describes a symptom, not the change"). Bounce it back for sharpening. A confident work order built on a soft plan is the worst output — the agent will implement the wrong thing, in scope, and pass CI.

## Step 2.5 — Confirm classification before transforming

After the gate passes, **before writing the work order**, scan the plan's major sections and surface your classification. Plans arrive from many sources (session output, agent hand-off, any path) and may express structural constraints as implementation steps — without an explicit "enforced by X" signal. Without a confirmation step, drafter guesses from framing alone and silently demotes what are actually hard constraints.

Present a compact table:

| Section / heading | Classification | Signal that drove the call |
|---|---|---|
| "§1 BE contract" | knowledge — keep verbatim | external system spec |
| "§4 folder tree" | **constraint or choreography?** | no enforcement signal found |
| "§10 build order" | choreography — demote | step-by-step, no automated gate |

Then ask: **"Correct any misclassification before I transform — a wrong call here produces a wrong work order."**

Wait for the user's response (even "looks right, go ahead") before proceeding to Step 3.

**Classify as knowledge / constraint (keep verbatim + extract why):**
- Anything referenced by an automated enforcement mechanism — linter, CI gate, pre-commit hook, test suite, type-checker — regardless of how it's phrased in the plan
- Wire schemas or field lists derived from an external system (API spec, BE DTO, DB schema)
- Business rules with code-level evidence (line numbers, exception class names, `@Annotation` references)
- Decisions explicitly locked or user-approved in the plan

**Classify as choreography (demote to recommended approach):**
- Explicit step sequences ("then do X", "after Y, do Z") with no automated enforcement signal
- Build order or chunk sequences — the agent sequences its own work
- **Human-gate coordination** — "human reviews", manual `git commit`, "wait for approval" arrows between steps. SDC is autonomous and one-shot; these gates cannot exist, so drop them.

**Not choreography — named agent-phase chains are load-bearing workflow:**
A plan that sequences distinct named sub-agents in order (e.g. `implement → polish → pre-commit`) — especially when stages need different models — is **not** droppable choreography. It maps to a first-class `## Phases` section in the work order (Step 4). Drop only the human-confirm gates wrapped around the chain; keep the chain itself.

## Step 3 — Transform: lossless on knowledge, lossy on choreography

The plan is **authoritative**. **Do not re-explore the codebase** — the plan's discovered facts (table names, symbols, the constraints, the traps) are the analysis you're paid to preserve, not to re-derive. Re-grepping to "verify" burns tokens for nothing. Only flag a fact that is internally contradictory.

Two moves at once:
- **Lossless on discovered knowledge** — the root cause, the "trap" a naive implementation falls into, and the confirmed facts (paths, schemas, hard limits) are the gold. They are exactly what a fresh headless agent **cannot** rediscover and what stops it from repeating the mistake the plan already caught. Carry them over whole.
- **Lossy on rigid choreography** — the literal step-by-step ("edit file A, then add function B, then…") is the human's implementation path. Demote it to a **recommended approach**, not a mandate; the agent designs in-session. Keep an approach only when it encodes a *constraint* (a pattern that must be mirrored, a pitfall to avoid) — and then keep its **why**, which is what makes it load-bearing.

**Scan for agent orchestration intent.** Before filing into sections, identify in the plan:
- Specific skills the agent should invoke (e.g. "run react-audit", "use the inspector") → candidate for `skills:` in Agent Configuration
- A specific sub-agent to delegate to (e.g. "hand to an implement agent", "run through the test agent") → candidate for `agent-type:` in Agent Configuration
- A multi-phase agent sequence with distinct sub-agents (e.g. `implement → polish → pre-commit`) → a first-class **`## Phases`** section (Step 4) — see there for the format. Confirm per-phase names with the user (see Operating rules).

**Path-scope check (mandatory before filing into sections):** scan the plan for every file path reference. For each path, ask: can the SDC agent resolve this from inside the target repo's working directory? Drafter runs locally where all repos are accessible — this is the only window to resolve external references before the work order leaves.

Classify each path as **external** or **in-repo**:

- **External (invisible to SDC agent)** — flag any of:
  - Starts with `../` or is an absolute path outside the project root
  - Session-local locations: `session-working-space/`, `~/.claude/`, `/Users/…`, `/tmp/…`
  - Belongs to a sibling repo by content signal: Java source paths (`src/main/java/`, `.java` extension), Python packages, Go modules, or any structure incompatible with the target repo's stack. A `.java` path is unresolvable in a TypeScript/React repo regardless of whether it has a `../` prefix.
- **In-repo (safe to carry)** — paths that resolve under the target repo root and match its stack: `src/`, `docs/`, `scripts/`, and relative paths consistent with the target repo's technology.

**Action for external paths — inline while local, never carry the path:**

1. **Plan cites specific lines** (e.g. `Controller.java:87-91`, `impl L207-213`): use `Read` to open that file and read **only those lines**. Inline verbatim with a provenance note:
   > *(inlined from `<path>:<lines>` — not accessible to SDC agent)*
2. **Plan cites a whole file with no line range** (e.g. `session-working-space/plans/foo.md`): `Read` only the sections the plan's own text references. Do not read beyond what the plan cited — that is re-exploration and violates the "trust the plan" rule.
3. **Read fails** (file moved, wrong path): summarize the facts the plan itself states about that file. Note the source is unresolvable. Never guess content.

**Boundary — re-exploration vs. reference resolution:** reading an external file to inline the section the plan already pointed to is resolution, not re-exploration. Reading beyond the cited section to find new facts is re-exploration. Rule: read only what the plan pointed to, inline it, stop.

Re-file the plan into the work-order sections (Step 4). The same self-contained rule that serves the agent makes it readable to the absent teammate — strip every session-local reference and inline what it pointed to.

## Step 4 — Write the work order (English only)

The work-order document is **English only** — its reader is a coding agent and a code-reviewing team; this matches the docs/issues-in-English convention. Produce these sections (this is the generic shape; it maps cleanly onto an SDC `agent-task` template):

- **Summary** *(non-negotiable)* — 1–3 plain sentences: what this is, why it exists, what "done" looks like. A reviewer skimming the issue page understands it in five seconds. If you can't write a crisp summary, the plan wasn't sharp enough — go back to Step 2.
- **Design** — the target / root cause and the **recommended** approach, in readable prose. Carry the "trap" here so the agent doesn't fall into it.
- **Constraints** — discovered ground truth the agent must honor, **each with its why** (e.g. "no Flyway in the project → use a runtime native query, not a migration"). The why is the guardrail; without it the agent does the wrong thing.
- **Assumptions** — pinned defaults the agent may rely on. State that if one proves false at runtime, the agent should **park and ask, not guess**.
- **Acceptance Criteria** — the **hard contract**: checkable, verifiable items. This is what the MR is measured against.
- **Test Cases** — Given / When / Then. At least one.
- **Out of scope / Non-goals** — explicit. Pre-empts scope creep; names adjacent work that is deliberately *not* in this order.
- **Phases** *(emit only when the plan carries a named multi-stage agent chain AND the target supports first-class phases, e.g. SDC)* — one `### Phase N: <title>` sub-block per stage, each carrying its own `agent-type:` / optional `model:` / `skills:` line (same format as Agent Configuration) plus that stage's instructions. Format:
  ```
  ## Phases

  ### Phase 1: Implement
  agent-type: implement-agent
  Read the target repo's `.claude/agents/implement-agent.md` and follow it directly — don't rely
  on `agent-type:` alone. Build the feature against the plan. Do not commit (the runner commits
  per phase).

  ### Phase 2: Polish
  agent-type: polish-agent
  Read the target repo's `.claude/agents/polish-agent.md` and follow it directly. One pass over
  the accumulated working-tree diff: DRY, consistency, cleanup.

  ### Phase 3: Pre-commit gate
  agent-type: pre-commit-agent
  Read the target repo's `.claude/agents/pre-commit-agent.md` and follow it directly. Run the
  project's gates (type-check, lint, tests, structure checks) over the full diff.
  ```
  *Phase titles and `agent-type:` values above are illustrative — substitute the target repo's actual `.claude/agents/` names (confirm with the user; see Operating rules).*
  **Every declaration in Agent Configuration is best-effort — pair it with a body instruction
  that forces use** (see the Agent Configuration bullets below for the full principle). Here:
  each phase whose `agent-type:` names a repo-defined agent opens with the read-the-persona line
  above; a phase targeting a Claude Code built-in (`general-purpose`, `Explore`, `Plan`) has no
  persona file and skips the line; a phase declaring `skills:` instead adds "invoke the `<name>`
  skill (Skill tool) at the relevant step."
  A runner with first-class phases (e.g. SDC's daemon) runs phases in order, one committed run each on the same branch, one MR after the last phase. Omit a phase's `model:` to cascade to the issue-level default (then `sonnet`). **Drop human-confirm gates** — deterministic per-phase execution replaces them. A bare `## Phases` heading with no `### Phase` sub-blocks is NOT valid — always emit ≥1 sub-block.
- **Agent Configuration** *(include when the plan specifies any of these; omit the section entirely otherwise)*:
  - `model:` — infer from task complexity: `opus` for heavy/architectural work, `haiku` for trivial/mechanical, `sonnet` otherwise. Acts as the cascade default for any `## Phases` sub-block that omits its own `model:`.
  - `skills:` — when the plan names skills to invoke. Bare name = project skill (`.claude/skills/<name>/SKILL.md` in the target repo); `<plugin>:<skill>` = plugin skill installed on the agent. Comma-separated, case-sensitive kebab-case. Daemon-validated pre-claim (see Operating rules) — and pair each with an invoke-the-skill instruction in the body (see Operating rules).
  - `agent-type:` — when the plan delegates to a specific sub-agent type. Valid names are the repo's `.claude/agents/` entries and Claude Code built-ins (`general-purpose`, `Explore`, `Plan`). Daemon-validated pre-claim, same rule as `skills:`. Best-effort at runtime — pair a repo-defined name with a read-the-persona instruction in the body (see Operating rules; built-ins are exempt).
  - Multi-phase agent chains → use the **`## Phases`** section (above), not issue-level `agent-type:`. Issue-level `agent-type:`/`model:` then act as the cascade default for any phase that omits its own. (Targets without first-class phases: fall back to a prose chain in `## Design` and name the sub-agents — best-effort, non-deterministic.)
- **Dependencies** — ordering / `Depends-on:` when the plan implies it (e.g. a BE change that must land before its FE counterpart).

If the plan surfaced adjacent problems, **split them into their own work orders** — do not bundle them into this one (archivist's rule: each follow-up is its own ticket).

### Priority when they pull apart

Weight **the quality of the work the agent will do** first — precision over prose:
- Spend the budget on testable AC, preserved constraints/traps, explicit non-goals, an unambiguous done-state.
- Let the technical sections run dense / jargon-heavy if that serves the agent (it will grep the symbols).
- Don't polish narrative for its own sake.
- Readability target is **review-grade**: enough that a teammate can judge whether the resulting MR matches scope — not enough to re-derive the work. "Good enough to understand" is acceptable. The Summary and each constraint's *why* are the exception — keep them, because they're agent-quality wearing a readability coat.

## Step 5 — Stop / handoff

Drafter produces the work order and stops. It **never posts the issue or edits code itself.**

- If the target repo has an issue-filing skill (SDC `/create-issue`): offer to hand the drafted Description to it — that skill grounds against the repo and posts. Don't duplicate its job; don't re-grill what it will grill.
- Otherwise: output the work order for the user to file manually.

## Operating rules

Governance — what drafter MUST / MUST NOT do regardless of input:

- **Trust the plan; do not re-explore the codebase.** The plan is the analysis. Re-deriving it is wasted tokens and risks contradicting the source. Flag only internal contradictions.
- **Never guess to fill the template.** A missing AC or an unnamed target is a *bounce-back* (Step 2), not a blank you invent past.
- **Lossless on discovered knowledge, lossy on choreography.** Preserve the traps and facts; demote step-by-step to recommendation.
- **Acceptance criteria are checkable or they don't count.** "Works correctly" is not an AC; "sort=name returns Thai dictionary order, เ-word before ฮ-word" is.
- **The work order is English only.** The artifact's readers are an agent and a reviewing team.
- **Interactive replies adapt to the user.** Talk to the user in the language they're using in the conversation; honor their CLAUDE.md / language-preference memory if present; default to matching the conversation. Keep technical terms, identifiers, and all code in English regardless. (This skill ships in a shared kit — never hardcode a single human language.)
- **Self-contained.** No reference the absent reader can't resolve. Inline what a session-local note pointed to. **Specifically: never carry a path the agent cannot open from inside the target repo** — paths starting with `../`, absolute paths outside the project root, or session-local locations (`session-working-space/`, `~/.claude/`, `/Users/…`) must be inlined or their key facts summarized; carrying the path is always wrong.
- **Never guess skill or agent-type names.** If the plan implies a specific skill (`skills:`) or sub-agent (`agent-type:`), confirm the exact name with the user — the daemon hard-blocks the issue pre-claim if any declared name is unknown. A typo parks the issue `agent-blocked` before a single line of code is written. This applies to **per-phase** `agent-type:`/`skills:` in a `## Phases` section equally — the daemon union-validates every phase's declarations pre-claim; one unknown name in any phase hard-blocks the whole issue.
- **Every Agent Configuration declaration is best-effort at runtime — pair it with a body instruction that forces use.** Pre-claim validation only checks the name exists; it never guarantees the agent actually delegates or invokes it mid-run. So: a repo-defined `agent-type:` (issue-level or per-phase) gets a "read the target repo's `.claude/agents/<name>.md` and follow it directly" line in that phase/issue body (Claude Code built-ins — `general-purpose`, `Explore`, `Plan` — have no persona file; skip the line for them). A `skills:` entry gets an "invoke the `<name>` skill via the Skill tool at the relevant step" line — invocation, not a read instruction, since a plugin skill has no path inside the target repo.
- **Read-only.** Produce a document. Posting and code edits belong to other tools.

## Quick reference

```
1. Locate plan      — path / in-context / ask. Never assume a fixed location.
2. Gate             — precise target? recoverable AC? constraints present? — else bounce back
2.5 Classify        — table of [knowledge/constraint] vs [choreography] per section → wait for correction
3. Transform        — TRUST the plan (no re-explore); keep knowledge, drop choreography
4. Write order      — English; Summary + Design + Constraints(+why) + Assumptions + AC + Tests + Non-goals + Phases (named agent-phase chain → ## Phases with ### Phase N: sub-blocks, per-phase agent-type/model, each agent-type/skills paired w/ read-the-persona / invoke-the-skill line) + Agent Config (issue-level model/skills/agent-type; cascade default for phases) + Deps
5. Stop/handoff     — to /create-issue if present, else output; never post or edit code
```

The drafter's rule: **the work order is the whole conversation** — the crew can't ask you anything once the job starts. Put it all on the page; name what not to touch.
