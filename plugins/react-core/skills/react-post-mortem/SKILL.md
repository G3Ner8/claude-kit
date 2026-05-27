---
name: react-post-mortem
description: Standardized post-mortem template for production incidents, bug fixes worth recording, or recurring failure modes. Produces a markdown document with sections for impact, timeline, root cause, fix, prevention, and follow-ups. Use after the incident is resolved and the fix is merged — never during firefighting. Triggers - "post-mortem for X", "incident write-up X", "RCA for X", "lessons learned X".
license: MIT
user-invocable: true
metadata:
  version: "0.1.0"
  type: gate
  status: experimental
  stack: any
  scope: read-only — produces a markdown document for the user to save / share
---

# React Post-Mortem

A standardized template for capturing what happened in an incident, what the root cause was, what fixed it, and what changes to the system prevent the next one.

Post-mortems are most valuable when they're **read by people who weren't there**. That means the format is more important than the eloquence. A consistent shape lets a new engineer in 6 months skim the doc, find the section they need, and learn the lesson without reading from start to finish.

This skill enforces the shape.

## When to use

After the incident is **resolved** and the fix is merged. Specifically:

- Production outage or significant degradation (any blast radius beyond a single user).
- Bug that took > 2 hours to diagnose, even if not user-visible.
- Recurring failure mode worth naming (third time you've fixed the same shape).
- Near-miss where the system survived but the cause is worth recording.

Skip this skill for:

- Routine bug fixes (test failed, fixed it, moved on).
- One-off typos / dead imports / obvious oversights.
- Incidents still in progress — don't write the post-mortem while firefighting. The skill assumes the fire is out.
- Personal-development logs ("things I learned today") — those have a different audience.

## Step 1 — Gather inputs (MANDATORY before drafting)

Use `AskUserQuestion` to collect:

1. **What happened** (one sentence) — the headline. "Login failed for 12% of users for 47 minutes."
2. **When** — start and end timestamps (or "ongoing" if the impact tail extends).
3. **Detection** — how was it noticed (alert, customer report, internal user)? **Time-to-detect** if known.
4. **Resolution** — what stopped the bleeding? **Time-to-resolve** if known.
5. **Suspected root cause** — the user's best current understanding. The post-mortem will refine this.

If the user doesn't have one of these, ask before drafting. A post-mortem with placeholder values ("TBD") is worse than no post-mortem — it gets filed and forgotten.

## Step 2 — Build the timeline

A timeline is a flat list of events, in order, each tagged with a time and a one-line description:

```
| Time (UTC) | Event |
|---|---|
| 14:02 | Deploy v2.41.0 to prod (commit abc1234) |
| 14:08 | Datadog alert: error_rate(`POST /login`) > 5% |
| 14:11 | On-call paged, starts investigation |
| 14:23 | Identified: new validator rejects pre-existing accounts with empty `phone` field |
| 14:35 | Rollback to v2.40.3 deployed |
| 14:49 | Error rate normalized; alert auto-resolves |
| 15:30 | Forward-fix v2.41.1 deployed (validator default = "") |
```

Rules:

- **Detection event included** — the post-mortem starts from "system in trouble," not from "deploy."
- **Decisions included, not just events** — "decided to rollback at 14:30" is a useful row.
- **One row per meaningful moment** — don't pad with chat back-and-forth.

If the user can't reconstruct the timeline, ask whether to skip this section or stub it. The skill produces stubs marked `[reconstruct from logs]` so the user knows what's missing.

## Step 3 — Identify root cause

The root cause is the **first cause in the chain** where a different decision would have prevented the incident. Walk backwards from the symptom:

- "Users couldn't log in." Why?
- "Login API returned 422." Why?
- "Validator rejected the request." Why?
- "Pre-existing accounts had `phone: null` and the new validator required a string." Why?
- **"The validator was added without a migration plan for existing data."** ← root cause

Distinguish:

- **Root cause** — the single decision that, if reversed, prevents the incident.
- **Contributing factors** — other conditions that made the incident worse or easier to introduce (no staging coverage, no alarm on validator-error rate, slow rollback procedure).

A post-mortem has **one** root cause and **0-N** contributing factors. If you can't pick one root cause, you haven't walked back far enough.

## Step 4 — Capture fix + prevention

Two sections, distinct purposes:

- **Fix** — what changed in this incident to stop the bleeding. Usually a commit / PR link. Forward-fix or rollback.
- **Prevention** — what changes to the system / process keep this from recurring. May be a list (better alarms, integration test for migration, runbook update). Each prevention item should be a follow-up ticket with an owner and a deadline.

The fix is mandatory. Prevention may be empty if the root cause genuinely was a one-off (an external dependency had a one-day outage). More often, there's something the team can change.

## Step 5 — Produce the document

Render the full markdown post-mortem and present it to the user. They decide where it lives (internal wiki, repo `docs/post-mortems/`, Notion).

## Template

```markdown
# Post-mortem: <one-line incident headline>

**Date**: YYYY-MM-DD
**Status**: Resolved
**Owner**: <person responsible for follow-ups>
**Severity**: <Sev1 | Sev2 | Sev3>   (or your team's scale)

## Summary

<2-4 sentences. What broke, who was affected, how long, what fixed it. A reader who skims only this section should know the shape of the incident.>

## Impact

- **Users affected**: <count or %, e.g. "~12% of login attempts">
- **Duration**: <start time> – <end time> (<X minutes / hours>)
- **Blast radius**: <which features, regions, or user segments>
- **Data loss**: <none | description if any>
- **Financial**: <none | estimate if known>

## Timeline

<table from Step 2>

All times in UTC.

## Root cause

<2-4 sentences. The first cause in the chain. Specific and falsifiable — "the validator was added without a migration plan for existing accounts where `phone` was nullable" is good; "the deploy process is fragile" is too vague to act on.>

## Contributing factors

<bullet list, 0-N entries — each one a condition that made the incident worse or easier to introduce>

- No staging coverage for the migration path.
- Validator error rate alarm not configured.
- Rollback procedure required manual approval (added 8 min).

## Fix

- <commit/PR link> — <one-line description>
- <Rollback decision or forward-fix; include time-of-decision>

## Prevention follow-ups

<each item = an actionable ticket — owner, deadline, link>

| # | Action | Owner | Deadline | Ticket |
|---|---|---|---|---|
| 1 | Add integration test that exercises the migration path for nullable fields | @alice | 2026-06-15 | [TEAM-1234](...) |
| 2 | Add error-rate alarm per endpoint (currently global only) | @bob | 2026-06-30 | [TEAM-1235](...) |
| 3 | Document validator-change checklist in runbook | @alice | 2026-06-08 | [TEAM-1236](...) |

## What went well

<2-4 bullets. The on-call response, the rollback speed, the runbook accuracy. A post-mortem that only criticizes is incomplete; capture what to keep.>

- Datadog alert fired within 6 minutes of the deploy.
- Rollback was clean — no follow-on issues from the revert itself.
- Communication in the incident channel was clear and decision-by-decision.

## What didn't go well

<2-4 bullets. The detection delay, the unclear runbook, the 8-minute rollback approval. Avoid blaming individuals; name systems and processes.>

- Manual rollback approval added 8 minutes; should be automated for revert-deploys.
- The validator change passed CI because no test covered the migration path.
- On-call had to grep 4 dashboards to confirm the bleeding had stopped.

## Lessons learned

<1-3 bullets. The system-level insight a future engineer should carry. Resist platitudes ("we should have more tests"). Aim for a specific belief that changes future decisions.>

- Validator changes that tighten constraints need an explicit migration-path test, not just unit tests for the new rule.
- Per-endpoint alarms catch deploys-gone-wrong faster than global alarms — global was always going to trigger but already 5 minutes too late.
```

## Operating rules

- **Resolved-state assumption** — never produce a post-mortem for an ongoing incident. If the user invokes during firefighting, stop and tell them to come back after.
- **No blame, name systems** — phrasing matters. "The validator change passed CI without a migration test" is OK; "@alice didn't write the test" is not.
- **Root cause is singular** — if you can't pick one, walk back further until you can.
- **Every prevention item has an owner + deadline** — items without those decay into forgotten lists.
- **Capture what went well** — symmetric retrospective. A post-mortem that only criticizes burns out the team.

## You DON'T

- Open tickets / files automatically — the user pastes the document into their team's tools.
- Estimate financial impact unless the user provides it.
- Speculate on contributing factors the user didn't raise — surface gaps as "[needs reconstruction from logs]" instead.
- Run during an active incident — refuse.

## Edge cases

- **No clear timeline** — render the template with `[reconstruct from logs]` placeholders. The user knows what's missing.
- **External vendor outage as root cause** — still produce a post-mortem; prevention items become "circuit-breaker around vendor X" or "fall-back path for vendor outage."
- **Near-miss (no user impact)** — useful to post-mortem when the failure mode is novel. Mark `Status: Near-miss` and skip the Impact section's "users affected" row.
- **Bug fixed without a customer-facing incident** — usually doesn't warrant a post-mortem. Exception: if the bug was latent for months and required a non-trivial investigation, that learning is worth recording.
