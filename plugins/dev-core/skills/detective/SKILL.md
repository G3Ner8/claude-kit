---
name: detective
description: A debugging discipline for any stack — reproduce the failure, follow the fail path inward, falsify hypotheses, and name the cause BEFORE proposing a fix. Stops the "patch the symptom" reflex. Use when something is broken and the cause is not yet clear, while triaging — before touching code. Triggers - "investigate X", "track down the X bug", "why is X broken", "X isn't working", "what's breaking X", "get to the bottom of X".
license: MIT
user-invocable: true
metadata:
  version: "0.1.0"
  type: reference
  status: experimental
  stack: any (language- and framework-agnostic)
  scope: investigation discipline — narrows to a named root cause; the fix happens after
---

# Detective — debug discipline

You are a detective. A detective doesn't arrest the first suspect who looks guilty — they place the suspect at the scene with evidence, rule out the alternatives, and only then name the culprit. Debugging is the same job: the symptom is where the body was found, not where the crime happened.

The reflex this discipline exists to break: see a broken thing, edit the broken thing. The data is `undefined` → default it to `{}`. The function throws → wrap it in try/catch. Those are alibis for the symptom, not convictions of the cause — and they destroy the evidence that would have led you upstream.

This is a discipline, not a workflow with a stop gate. You consult it *while* debugging. The one rule that never bends: **name the broken layer before you write a fix.**

## When to use

- Something is broken / failing / returning nothing and the cause is **not yet obvious**.
- A test fails for a reason you can't immediately explain.
- An error or stack trace points at a line that "looks fine."
- Behaviour is intermittent, or "works on my machine."
- You're tempted to add a `try/catch`, a default value, or a retry to make a symptom go away.

Skip this discipline for:

- Trivial, self-evident fixes (a typo, a wrong import, a one-character off-by-one you can already see).
- Building a new feature — there's no failure to investigate yet.
- A failure whose cause you've already named with evidence — go straight to the fix.

For React "data isn't flowing" bugs (stuck `isLoading`, empty list, request not firing), use `react-debug` instead — it's this same discipline specialized to the backend↔frontend chain.

## The discipline — five moves

Do them in order. The order is the point: skipping ahead is how you end up convicting an innocent line of code.

### 1. Reproduce — secure the crime scene

You cannot debug what you cannot trigger. Before any theory:

- Find the **exact** steps, inputs, and environment that produce the failure. Write them down.
- Confirm you can make it fail **on demand**. A bug you can't reproduce is a bug you can't prove you fixed.
- Note what's stable: does it fail every time, or 1-in-N? Only with certain data? Only after another action? The pattern is your first clue.

If you can't reproduce it, that's the investigation — gather logs, timestamps, and the conditions from whoever saw it. Don't theorize into the void.

### 2. Locate — follow the fail path inward

The symptom is the **last** place the failure was visible, almost never where it started. Walk the path the data/control took, from the symptom backwards toward the source:

- What produced the wrong value? What fed *that*? Keep stepping toward the origin.
- At each layer, ask: **is the input to this layer already wrong, or does this layer break correct input?** That one question halves the search space every time — it's binary search on the call chain.
- Stop at the first layer where the input is correct but the output is wrong. The crime happened *there*.

### 3. Hypothesize & falsify — interrogate the suspects

For the suspect layer, state a specific, falsifiable hypothesis:

> "I believe X is broken because Y. If I'm right, then Z will be observable."

Then **try to disprove it**, not confirm it. A good detective looks for the evidence that would clear the suspect:

- Add one targeted probe (a log, a breakpoint, an assertion) that distinguishes "X is the cause" from "X is innocent." One probe per hypothesis — not thirty.
- If the evidence clears the suspect, you've still won: you eliminated a possibility. Move to the next.
- Resist "I changed something and it works now." If you don't know *why* it works, you haven't caught the culprit — you've moved it.

### 4. Keep a case ledger

Memory is a liar mid-investigation. Track it in the open:

```
Symptom:    <what's observably wrong>
Reproduce:  <exact steps / inputs>

Suspects (ruled out):
- <layer/cause> — cleared because <evidence>
- ...

Current hypothesis:
- <falsifiable statement> — probe: <what will confirm/deny>
```

The ledger stops you re-checking the same innocent layer twice and makes the eventual root cause obvious in hindsight. For a bug worth a write-up afterwards, this ledger is the raw material for `archivist`.

### 5. Name the root cause before you fix

The verdict. Before changing a single line, state it plainly:

> "The broken layer is **[layer]**. The root cause is **[specific, falsifiable cause]**. The fix is **[specific action]**."

A real root cause is the first point in the chain where a different decision would have prevented the failure — and it's specific enough to be wrong. "The validator rejected pre-existing rows because it was added without a backfill for the nullable column" is a conviction. "The data layer is fragile" is a hunch.

If you can't fill in that sentence cleanly, you haven't caught the culprit yet — go back to move 2. Only once the cause is named do you decide where the fix belongs (which may **not** be where the symptom showed up — see anti-patterns).

## Anti-patterns

- **Symptom patching** — defaulting `undefined` to `{}`, swallowing the throw, adding a retry. You've hidden the body, not solved the case. The signal is gone and the cause is still at large.
- **Suspect-confirmation** — looking only for evidence that fits your first theory. Falsify instead; the first suspect is usually innocent.
- **Probe explosion** — sprinkling 30 logs across the file. Strategic placement IS the discipline; spray-logging is its absence.
- **"It works now"** — a change made the symptom vanish but you can't say why. Unconvicted causes reoffend.
- **Fixing at the symptom** — the root cause is upstream (a contract, a caller, another system) but you patch the component where it surfaced, baking the upstream quirk in forever. Fix lives where the cause lives.

## When NOT to apply

- **Self-evident fixes** — you can already see the typo. Don't ceremonially "investigate" it.
- **Feature work** — nothing is failing; there's no scene.
- **Performance issues** — "slow" is a different hunt (profile first); this discipline is for "wrong / broken / missing."

## Related

- `react-debug` — this discipline specialized to React's backend↔frontend data-fetch chain (query keys, `enabled` gates, response transforms).
- `archivist` — after a non-trivial bug is fixed, turn the case ledger into a post-mortem so the next person inherits the lesson.

## Quick reference

```
1. Reproduce   — make it fail on demand; note the pattern
2. Locate      — walk symptom → source; "input wrong, or layer breaks good input?"
3. Falsify     — one probe per hypothesis; try to clear the suspect
4. Ledger      — record ruled-out suspects + current hypothesis
5. Name it     — "broken layer / root cause / fix" — before editing a line
```

The detective's rule: **name the culprit before the arrest.** No fix until the root cause is named with evidence.
