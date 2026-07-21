---
name: sitrep
description: Personal situation report — recap what you worked on, what it cost, and what is still open, assembled from local ground truth (Claude Code session logs, git history, MR/PR state). Periods - daily standup, weekly review (default), monthly rollup. Triggers - "/sitrep", "sitrep daily", "weekly sitrep", "what did I do this week", "what's still pending", "สรุปงานสัปดาห์นี้", "มีงานค้างอะไร".
license: MIT
user-invocable: true
metadata:
  version: "0.1.2"
  type: action
  status: experimental
  stack: any (needs ~/.claude/projects session logs + git; gh/glab optional for PR/MR state)
  scope: writes files — one briefing per run into ~/.sitrep/; reads repos and logs, never modifies them
---

# Sitrep — situation report on your own work

A sitrep answers the commander's question: what happened, what did it cost, what
is still open, what's next. Here the commander is the person who did the work —
memory fades over a weekend, and open loops (an unmerged MR, a half-finished
task, an unanswered question) are exactly what gets lost. This skill assembles
the report from ground truth on disk, never from recollection: session logs say
what was worked on, git says what shipped, MR/PR state says what is waiting.

Two-stage split, strictly enforced: a **deterministic collector** (`collect.py`,
zero model calls) compresses the raw signals into a small digest; the model then
**composes** the briefing from that digest alone. The model never reads raw
session logs — they are orders of magnitude too large, and the digest is the
anti-hallucination boundary: if it is not in the digest, it does not go in the
briefing.

## When to use

- Start of the day or week: "what was I doing, what's still open?"
- End of the month: material for a performance review or a manager update.
- Before a status conversation: refresh on your own recent work, with links.

Skip this skill for:
- Project status ("is feature X done?", "what's left in the backlog") — that is
  `surveyor`'s job (declared vs ground truth of a *project*). Sitrep reports on
  *your* work across projects.
- Anything requiring team members' activity — sitrep reads only this machine.

## Periods

| Period | Window | Emphasis | Length |
|---|---|---|---|
| `daily` | 1 day rolling | open loops + what's next; skip effort stats | ~1/3 page |
| `weekly` (default) | 7 days rolling | all four sections, balanced | 1 page |
| `monthly` | one **calendar month** | outcomes as arcs, effort trends per week (the digest's week × project table) | ≤2 pages |

Stats are window-clipped: a session that spans the window edge counts only its
in-window activity and is marked `(cont.)` in the digest. For `monthly`, pick
the month being reported: the previous month when run in the first days of a
month, otherwise the current month-to-date (say which in the briefing title).

## Pre-conditions (refuse if any missing)

- `~/.claude/projects/` exists and contains JSONL activity inside the window.
- `python3` is available.

If a pre-condition fails, state what is missing and stop. Never fabricate a
briefing from memory of the conversation.

## Apply

1. **Collect** — run the collector from this skill's base directory (announced
   when the skill loads):

   ```bash
   python3 "<skill-base-dir>/collect.py" --days <1|7>     # daily / weekly
   python3 "<skill-base-dir>/collect.py" --month YYYY-MM  # monthly
   ```

   The digest arrives on stdout. It is working data: consult it, quote facts
   from it, but never paste it into the briefing.

   **Meetings (optional but attempt it):** local logs cannot see work away from
   the keyboard. If a calendar connector is reachable (ToolSearch for
   "outlook calendar events" — e.g. the Microsoft 365 connector), pull the
   window's calendar events (title, start, duration) and treat them as work
   items alongside the digest. If no calendar tool is available, declare the
   blind spot in the footer — never reconstruct meetings from memory.

2. **Carry over** — read the most recent briefing in `~/.sitrep/` (any period).
   Unchecked open loops from it carry into the new briefing unless the digest
   shows them resolved; resolved ones are listed as done. This is the memory
   between reports — dropping it silently defeats the skill's purpose.

   An MR/PR carried as an open loop is resolved when the digest's Git section
   lists it under `✓ merged` — mark it done, do not re-carry it. A merge shows
   up as that positive line, never as mere absence from the open list.

3. **Compose** the briefing per the contract below and write it to `~/.sitrep/`
   (create the directory if needed), named by period:
   `sitrep-YYYY-MM-DD.md` (daily) · `sitrep-YYYY-Wnn.md` (weekly) ·
   `sitrep-YYYY-MM.md` (monthly). A rerun of the same period overwrites its own
   file only.

4. **Show the full briefing in the reply** — the file is the archive, the reply
   is the delivery.

### Briefing contract

- Exactly four sections. Canonical names and default order below; render the
  headers in the conversation's language. **Order exception:** `daily` leads
  with Open loops (a standup answers "what's next" before "what happened");
  weekly and monthly keep the retrospective order as listed:
  1. **Accomplished** — outcomes grouped by project, heaviest first. Each
     project is a bold header line (project — ~hours — one-line theme)
     followed by one sub-bullet per distinct outcome (an issue closed, an MR
     merged/pending, a decision made) — never crammed into one paragraph
     joined by "·". Merged MRs, shipped features, decisions closed. Every
     MR/issue/PR mentioned is a markdown link to its URL.
  2. **Effort** — time and tokens, always paired with what they bought
     ("7.4h + 1.6M tokens → the R1/R2/R3 issue split"). Never bare totals.
     Omit this section in `daily`.
  3. **Open loops** — markdown checkboxes. Unmerged branches, open MRs,
     uncommitted files, sessions that ended mid-task, decisions left hanging,
     plus carry-overs from the previous briefing. Every carried loop states
     its age — "(since W28)" / "(3rd week open)" — so a loop that survives
     multiple briefings escalates visually instead of blending in.
     **MR/PR status comes only from the digest's Git section** (`⚠ open` /
     `✓ merged`) — never infer "waiting to merge" from a branch name or a
     session mentioning an MR. A pushed branch with no matching `⚠ open` line
     is at most "pushed, MR state unknown", not an open MR.
  4. **Next up** — a short ranked list derived from the open loops.
- **Timesheet draft appendix** (daily + weekly, after the four sections): a
  compact table `date | project or meeting | summary | ~hours` built from the
  digest's Daily log plus calendar events when available. Summaries are one
  line in plain business language (what was worked on, not which tools ran).
  Hours always carry the `~` prefix — they derive from activity windows and
  meeting durations, and the user adjusts them before submitting anywhere.
  Days the data cannot see show `(no local signal)` — never invent filler
  entries to make a day look full.
- Length per the period table. One page is a feature, not a limit to negotiate
  (the timesheet appendix sits outside the page budget).
- Every cap the collector applied is echoed ("+N smaller sessions, X tokens") —
  nothing is silently dropped.
- Footer, always: data provenance (sessions/repos scanned, digest size), the
  disclaimer that time is an activity-window estimate and not a timesheet, and
  any blind spots the digest declared (e.g. MR state unavailable).
- Facts come from the digest only. A thing the digest cannot see is reported as
  unknown, not guessed.

## Verification

- The briefing file exists at the expected `~/.sitrep/` path and contains all
  contract sections for its period.
- Totals quoted in the briefing match the digest's Totals line.
- Every open loop from the previous briefing is either carried or explicitly
  marked resolved — none vanished.

## Rollback

Briefings are additive files; to undo a run, delete the file it wrote. The
collector itself mutates nothing — repos and session logs are read-only to this
skill, so there is nothing else to roll back.

## Operating rules

- The collector never calls a model; the model never reads raw logs. Keep the
  boundary in both directions.
- Read-only toward every repo and log scanned. The only write is the briefing.
- Digest is working data — never reproduced verbatim in the briefing or reply.
- Time figures always carry the estimate disclaimer. Token figures always pair
  with an outcome. Blind spots are declared, not papered over.
- The briefing's language follows the conversation; technical identifiers
  (branch names, MR titles, commit subjects) stay verbatim.
