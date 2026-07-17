# work-core

Cross-role personal work-awareness skills — the role-neutral tier of claude-kit.
Where `dev-core` disciplines how you work *on a codebase*, `work-core` reports on
*your own work* across everything you touch.

**Status: experimental.** One skill, in real-use trial (see the demand gate in
CLAUDE.md decision D13).

## Skills

| Skill | What it does |
|---|---|
| [`sitrep`](skills/sitrep/SKILL.md) | Personal situation report — daily standup / weekly review / monthly rollup assembled from local ground truth: Claude Code session logs, git history, MR/PR state. A deterministic collector compresses raw logs into a small digest (zero model calls); the session model composes a one-page briefing under a fixed four-section contract: Accomplished / Effort / Open loops / Next up. |

## Usage

```
/sitrep            → weekly review (default)
/sitrep daily      → this morning's standup
/sitrep monthly    → month rollup (performance-review material)
```

Briefings land in `~/.sitrep/`, one file per period. Open loops carry over
between briefings until resolved (with their age) — that's the "don't forget"
half of the job. Daily/weekly briefings end with a timesheet-draft appendix
(hours marked `~`, adjust before submitting); calendar meetings join it when
a calendar connector (e.g. Microsoft 365) is connected.

## Requirements

- Claude Code session logs at `~/.claude/projects/` (present on any machine
  that runs Claude Code)
- `python3` on PATH (collector is stdlib-only)
- Optional: `gh` (GitHub) / `glab` (GitLab) for open-PR/MR state — without
  them the briefing declares the blind spot instead of guessing
