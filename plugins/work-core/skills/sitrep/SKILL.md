---
name: sitrep
description: Personal situation report — recap what you worked on, what it cost, and what is still open, assembled from local ground truth (Claude Code session logs, git history, MR/PR state). Periods - daily standup, weekly review (default), monthly rollup. Triggers - "/sitrep", "sitrep daily", "weekly sitrep", "what did I do this week", "what's still pending", "สรุปงานสัปดาห์นี้", "มีงานค้างอะไร".
license: MIT
user-invocable: true
metadata:
  version: "0.2.1"
  type: action
  status: experimental
  stack: any (needs ~/.claude/projects session logs + git; gh/glab optional for PR/MR state)
  scope: writes files — one briefing per run into ~/.sitrep/, plus the collector's repo cache ~/.sitrep/repos.json; reads repos and logs (only side effect is `git fetch` updating remote-tracking refs during loop re-verification)
---

# Sitrep — situation report on your own work

A sitrep answers the commander's question — what happened, what did it cost,
what is still open, what's next — where the commander is the person who did the
work. Memory fades over a weekend, and open loops (an unmerged MR, a half-done
task, an unanswered question) are exactly what gets lost. So the report comes
from ground truth on disk, never recollection: session logs say what was worked
on, git says what shipped, MR/PR state says what is waiting.

Two-stage split, strictly enforced: a **deterministic collector** (`collect.py`,
zero model calls) compresses the raw signals into a small digest; the model
**composes** from that digest alone. Raw session logs are orders of magnitude too
large to read, and the digest is the anti-hallucination boundary — if it is not
in the digest, it does not go in the briefing.

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

   Signals in it that change what you may claim:
   - **`⚠ Log horizon`** — the window opens before the oldest session log on disk
     (Claude Code prunes them after `cleanupPeriodDays`, default 30). Effort is a
     floor, not a total; the missing span is unmeasured, not quiet. Git and MR/PR
     data are unaffected.
   - **label ending `?`** — no session event carried a `cwd`, so the label came
     from the lossy directory name. Keep the `?`; do not guess the real name.
   - **a `split:` line under a session** — that session ran across several days
     (its header shows a `29 Jul–31 Jul` span). The split is the per-day truth;
     the Daily log already reflects it. Never attribute a spanning session's
     hours to one day, and never date its work by the day it opened.
   - **`[redacted]`** — the collector removed a credential-shaped string. Leave
     it redacted and never reconstruct it from conversation memory.
   - **Git header counts** — repos from session cwds vs from the cross-run cache
     (`~/.sitrep/repos.json`); cached repos are as real as the rest. Repos the
     cap left unscanned are a footer blind spot.

   **Meetings (optional but attempt it):** work away from the keyboard is the
   single biggest blind spot. If a calendar connector is reachable (ToolSearch
   "calendar events" — Microsoft 365 / Outlook, or Google Calendar), pull the
   window's events (title, start, duration), drop cancelled and all-day OOO
   items, and treat the rest as work items alongside the digest. Two traps:
   - **Convert to the user's local timezone** first — connectors return UTC
     (`{dateTime, timeZone}`), and a raw UTC time lands on the wrong day.
   - A meeting may **overlap** a concurrent session — flag it in the timesheet
     (`~` hours, user adjusts) rather than assuming it is additive.

   No connector reachable → declare the blind spot in the footer *with* the fix
   ("connect Microsoft 365 via `/mcp`"); never reconstruct meetings from memory.

2. **Carry over, then re-verify (MANDATORY)** — read the most recent briefing in
   `~/.sitrep/` (any period). Its unchecked loops carry into the new briefing;
   resolved ones are listed as done. This is the memory between reports.

   **The digest can close a loop but never confirm one is still open.** A
   `✓ merged` line is proof of resolution — mark it done. Absence is not: the
   digest only sees merges inside the window, so work closed last month reads
   identically to work still pending. Re-query every carried loop the digest did
   not close, window-free:

   ```bash
   glab mr view <iid> -R <group>/<repo>      # GitLab MR / issue
   gh pr view <n> -R <owner>/<repo>          # GitHub PR / issue
   ```

   `merged` / `closed` → done, with the merge date and a note if it had been
   carried wrongly. Still open → re-carry and increment its age. A loop with no
   id (unpushed branch, dirty tree, hanging decision) is checked against the
   thing itself: `git fetch` **only in that loop's own repo**, then
   `git log --oneline origin/<base>..<branch>` or `git status --porcelain`.
   Pushed + commits missing from base + no `⚠ open` line means **"no MR opened
   yet"** — a heavier loop than "waiting for review", not a lighter one.

   **Cap: 12 loops per run**, oldest first — verification is one network call
   each. Anything past the cap is re-carried as `(unverified this run)` and named
   in the footer. Never let the cap silently pass as a clean check.

   The footer records that loops were verified against live state, and the date.

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
  1. **Accomplished** — outcomes grouped by project, heaviest first. One bold
     header line per project (project — ~hours — one-line theme), then one
     sub-bullet per distinct outcome (issue closed, MR merged, decision made) —
     never one paragraph joined by "·". Every MR/issue/PR is a markdown link.
  2. **Effort** — time and tokens always paired with what they bought
     ("7.4h + 1.6M tokens → the R1/R2/R3 issue split"), never bare totals. With
     calendar data, one line keeps the two kinds of time distinct ("~30h keyboard
     + ~10h meetings") — measured from activity windows and meeting durations
     respectively, never merged. Close with a delta against the previous briefing
     of the **same** period: "~8.8h vs W30's ~30.1h — 4 of 7 days had no local
     signal". No same-period predecessor, or a log horizon in the digest → say
     the comparison is unavailable rather than compare against a floor. Omit this
     section in `daily`.
  3. **Open loops** — checkboxes. Unmerged branches, open MRs, uncommitted files,
     sessions that ended mid-task, hanging decisions, plus carry-overs. Every
     carried loop states its age ("since W28" / "3rd week open") so a survivor
     escalates visually. **MR/PR status comes only from the digest's Git section
     or a live re-query** (Step 2), and the loop says which confirmed it — never
     infer "waiting to merge" from a branch name or a session mentioning an MR.
  4. **Next up** — a short ranked list derived from the open loops.
- **Timesheet draft appendix** (daily + weekly): a table `date | project or
  meeting | summary | ~hours` from the digest's Daily log plus calendar events.
  Summaries are one line of plain business language (what was worked on, not
  which tools ran). Hours always carry `~` — the user adjusts before submitting
  anywhere. Days with nothing show `(no local signal)`; never invent filler.
- Length per the period table (the timesheet appendix sits outside that budget).
- Every cap the collector applied is echoed ("+N smaller sessions, X tokens").
- Footer, always: provenance (sessions/repos scanned, digest size), the date
  loops were verified live, the estimate disclaimer, and every blind spot the
  digest declared (MR state unavailable, log horizon, repos past the cap). A
  blind spot the user can close carries the fix — no calendar connector →
  "connect Microsoft 365 via `/mcp` to include meetings".
- Facts come from the digest only. What it cannot see is reported unknown.

## Verification

- The briefing file exists at the expected `~/.sitrep/` path and contains all
  contract sections for its period.
- Totals quoted in the briefing match the digest's Totals line.
- Every open loop from the previous briefing is either carried or explicitly
  marked resolved — none vanished.
- Every carried loop was closed by a digest `✓ merged` line or by a live
  re-query — none was re-carried purely because the digest did not mention it.

## Rollback

Briefings are additive files; to undo a run, delete the file it wrote. Repos and
session logs are read-only to this skill, so there is nothing else to roll back.
The collector's `~/.sitrep/repos.json` is a rebuildable cache — deleting it costs
nothing but the memory of repos not opened recently.

## Operating rules

- The collector never calls a model; the model never reads raw logs. Keep the
  boundary in both directions.
- Read-only toward working trees, branches, and logs. The only files written are
  the briefing and the collector's own repo cache, both under `~/.sitrep/`.
  Step 2's `git fetch` updates remote-tracking refs — the single side effect
  outside that directory, and it touches no working tree, branch, or commit.
- Project labels come from the digest verbatim, including a trailing `?` — the
  label derives from the session's real `cwd`, so "repairing" one from
  conversation memory replaces ground truth with a guess.
- A credential never leaves the collector. `[redacted]` stays redacted, and no
  secret seen elsewhere in the conversation is written into a briefing — the file
  persists and gets pasted into chats and timesheets. If work involved a
  credential, name the fact ("rotate the plaintext API key"), never the value.
- Digest is working data — never reproduced verbatim in the briefing or reply.
- Time figures always carry the estimate disclaimer. Token figures always pair
  with an outcome. Blind spots are declared, not papered over.
- The briefing's language follows the conversation; technical identifiers
  (branch names, MR titles, commit subjects) stay verbatim.
