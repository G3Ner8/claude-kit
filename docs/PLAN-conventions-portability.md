# Plan — Conventions-doc portability (MC-walk decoupling)

> Working design doc. Goal: make the `react-agents` templates + `profile-generator`
> portable to any React 19 / Vite project, by removing the baked-in assumption that
> every project ships a `CLAUDE.md` numbered `MC-1..MC-N` under a "Mandatory
> Conventions" heading. Status: **Phases A + B + C + D implemented.** Templates + generator
decoupled from `{{MC_MAX}}` (runtime enumeration); case-1/2/3 conventions-doc resolution
+ stack-aware seed; generator wording de-jargoned; `Swagger` → `{{API_CONTRACT_NAME}}`;
`Radix` generalized to "portal-based primitives"; **page-maturity (Polished/Rough/Partial)
decoupled via `{{REFERENCE_PAGE_TERM}}` + `{{ANTI_REFERENCE_CLAUSE}}` + `{{POLISH_STATUS_REPORT_BLOCK}}`.**
No known pps-web-isms remain in the templates.

---

## 1. Problem

The MC-walk mechanism (agents read the project's conventions doc, walk each rule
against the diff, emit one status line per rule, and `pre-commit` blocks if the
walk is missing) is the highest-value quality feature of the generated agents.
But the current templates bake three pps-web assumptions:

1. A conventions doc exists at `<root>/CLAUDE.md`.
2. Its rules are numbered `MC-1..MC-N` (contiguous integers).
3. The count is frozen at gen time via `{{MC_MAX}}`.

Consequences for a non-pps-web project:

| Project state | Today's behavior |
|---|---|
| Has `CLAUDE.md` with `MC-N` | ✅ works |
| Has a rules doc in **another scheme** (named sections, `CONV-N`, bullets) | ❌ `grep MC-([0-9]+)` returns nothing → `MC_MAX` empty → agents render `walk MC-1..MC-` and `pre-commit` hard-blocks. **Silent breakage — worst case.** |
| Has **no** rules doc | ❌ `{{CONVENTIONS_DOC}}` path dangles; MC-walk references a file that isn't there |

Key realisation: citations in the templates are **line-based**
(`{{CONVENTIONS_DOC}}:<line>`), not label-based. The `MC-N` token is only a
status-line identifier. So the rule *scheme* is cosmetic and parameterizable —
what the mechanism actually needs is (a) a readable conventions doc and (b) a way
to enumerate its rules.

`react-core/skills/react-audit` **already** does this the portable way
(`SKILL.md:146,149,225`): "read the conventions doc… walk MC-1..MC-N… swap names
to match your project." It bakes no count. The 4 agent templates are the only
place that freezes `{{MC_MAX}}`. **This work converges the templates onto
react-audit's existing pattern — not a new invention.**

---

## 2. Locked design decisions

| # | Decision | Resolution |
|---|---|---|
| D-1 | Snapshot (bake count) vs runtime (read + count each session) | **Runtime.** Agents already read the doc once per session (`implement:163`, `polish:67`), so this adds ~0 token cost and removes a drift source. |
| D-2 | Hardcode the `MC` label? | **No.** Agents use whatever identifiers the doc defines (numbered `PREFIX-N` or named sections). Default seed stays `MC-1..MC-7`. |
| D-3 | No-rules case: propose a default? | **Yes — option B, stack-aware seed.** Generator writes a `CONVENTIONS.md` whose 7 sections are filled with the project's real stack (UI lib, form lib, i18n, logger, test stack), framed as a **draft for review**. Users have the basic knowledge to extend/edit. |
| D-4 | Auto-extract normative rules from code (option C)? | **Deferred / rejected for now.** Conventions are normative, not descriptive; extracting rules from usage risks codifying accidental patterns. If revisited, must derive from already-codified sources (ESLint/Prettier/tsconfig) and ship as an explicit draft. |
| D-5 | `react-audit` changes? | **None.** Already runtime/scheme-flexible. We move toward it. |
| D-6 | Where the seeded doc is written | **Project repo root** (`<root>/CONVENTIONS.md`). Conventions belong to the project, not the profile; react-audit also looks there. |
| D-7 | Seed framing | **Always "draft for review."** File header + generator final report both say so. |
| D-8 | `{{CONV_SECTION_NAME}}` — keep or generic? | **Keep as optional anchor.** Default = the seed's section name (`Mandatory Conventions`); generator auto-detects the heading for an existing doc; **empty = walk the whole file** (dedicated conventions files). Covers both embedded-in-big-doc and dedicated-file cases without forcing the param in the common case. |
| D-9 | Multi-file rules | **v1 supports a single doc only.** If the generator detects rules likely span multiple files (e.g. `CLAUDE.md` links to `docs/conventions/*.md`), warn + ask the user to point at one consolidated doc or accept single-doc scoping. True multi-file support deferred. |
| D-10 | Case-1 confirm UX | **Show detected identifiers in the Phase 1 confirm summary always; escalate to a dedicated `AskUserQuestion` only when enumeration is ambiguous (case 3).** Adds no new question in the common path; consistent with the generator's existing "Do NOT silently pick" rule. |

---

## 3. Target behavior — the three cases

The generator must split **two** decisions that today collapse into one
("does `CLAUDE.md` exist?"): *is there a doc?* and *can its rules be enumerated?*

```
scan for conventions doc (CLAUDE.md ∪ CONVENTIONS.md ∪ user-pointed)
│
├── found, rules enumerable ──────────────► CASE 1: bind to its scheme
│     ├─ numbered PREFIX-N  → identifiers = the numbers found (not max)
│     └─ named sections     → identifiers = the section titles
│
├── found, but rules NOT cleanly enumerable ► CASE 3: surface + ask/enrich
│     "Found <doc> but couldn't identify discrete rules.
│      (a) point me at the rules section  (b) merge the 7-section starter
│      (c) use as-is (MC-walk degrades)"
│
└── not found ───────────────────────────► CASE 2: stack-aware seed (B)
      write <root>/CONVENTIONS.md from taxonomy, examples from detected stack,
      framed as draft; announce in final report
```

Runtime (D-1) means the **agents** don't care which case produced the doc — they
read it at session start and walk whatever rules it defines. The case logic lives
entirely in the generator + seeding.

---

## 4. Change list — file by file

### 4.1 The 4 agent templates (`plugins/react-agents/templates/agents/*.template.md`)

Core rewrite of every MC-walk block. Remove `{{MC_MAX}}` entirely.

| Current | New |
|---|---|
| `Read {{CONVENTIONS_DOC}} MC-1..MC-{{MC_MAX}} in full once per session` | `Read {{CONVENTIONS_DOC}} once per session; enumerate every rule it defines (numbered PREFIX-N or named sections under the conventions area) — those are what you walk` |
| `Report MUST contain {{MC_MAX}} status lines` | `one status line per rule defined in the doc` |
| status-line example `MC-<X>, MC-<Y>` | keep as illustration + add "use your doc's actual identifiers — swap names to match your project" (mirrors `react-audit:225`) |
| pre-commit gate `verify all {{MC_MAX}} MC sections accounted for` | `re-read the doc, enumerate its rules, verify each appears in exactly one status line of the upstream block; missing any → Blocking` |
| `{{CONVENTIONS_DOC}}:<line>` citation | **unchanged** |

Per D-8: keep `{{CONV_SECTION_NAME}}` as an optional anchor (default
`Mandatory Conventions`; empty = walk the whole file) so the agent scopes the
walk correctly in a mixed-content doc.

### 4.2 `profile-generator/SKILL.md`

Remove:
- `{{MC_MAX}}` scan derivation (line ~114).
- `{{MC_MAX}}` substitution row (line ~342) + its override question.
- "(N MC sections found)" from the auto-scan summary (line ~146).

Add (case logic):
- Case 1: detect scheme — regex `([A-Z]+)-(\d+)` for numbered, else heading scan;
  bind identifiers; confirm with the user.
- Case 2: **stack-aware seed** routine (scan deps/config → write `<root>/CONVENTIONS.md`).
- Case 3: "found but not enumerable" → AskUserQuestion (point/merge/use-as-is).

Update:
- Pre-conditions: no longer assume `CLAUDE.md`; instead guarantee a doc exists
  post-gen (seed if absent). Do not refuse on missing doc.
- Typical-question-count table + Phase-2 flow notes.

### 4.3 `react-agents/docs/PLACEHOLDER-REFERENCE.md`

- Remove the `{{MC_MAX}}` row.
- If §6 keeps it: add `{{CONV_SECTION_NAME}}`.

### 4.4 `react-core/docs/CONVENTIONS.template.md` (the seed)

- Relax the line-56 warning ("renumber requires a migration pass on every `MC-N`
  reference in agent prompts") — agents no longer hardcode `MC-N`, so renumbering
  only needs care for stable line-citations.
- This file becomes the taxonomy source for the case-2 stack-aware seed.

### 4.5 `react-core/skills/react-audit/SKILL.md`

- **No change.** Already runtime. Listed so reviewers confirm alignment.

### 4.6 Archived `_archive/pps-web-profile/agents/*`

- Skip. Baked `MC_MAX=7` but archived and not published.

---

## 5. Stack-aware seed (case 2, option B) — detail

Source facts (derive only from already-normative / detectable signals, never from
guessing intent):

| Section (from CONVENTIONS.template.md) | Filled from |
|---|---|
| HTML & a11y | ESLint a11y plugin presence; default generic rules |
| Input primitives & variants | UI lib in `package.json` (Radix / MUI / Chakra / Mantine / shadcn) |
| Tables | UI lib table primitive if any; else generic |
| Modal vs Drawer | UI lib dialog/drawer primitives |
| Forms & validation | form lib (RHF / Formik) + schema lib (zod / yup) |
| i18n & cross-feature | i18n lib (i18next / react-intl) + detected locales |
| Logging & error handling | logger dep if any; toast lib; ESLint `no-console` rule |

Output: `<root>/CONVENTIONS.md` with each section's **examples** grounded in the
real stack, **rules phrased as candidates** ("Use `<detected primitive>` not
native `<input>` — confirm"). Header states: *starter draft — agents walk these
before every report; edit to match your team.*

If deps/config scan yields nothing → fall back to static template copy (option A).

---

## 6. Follow-on decisions — resolved (see D-8..D-10)

All three open items are now resolved in the §2 table:

1. **`{{CONV_SECTION_NAME}}`** → D-8: keep as optional anchor, auto-detect,
   empty = whole file.
2. **Multi-file rules** → D-9: single-doc in v1; detect + warn/ask on multi-file;
   true support deferred.
3. **Case-1 confirm UX** → D-10: show in Phase 1 confirm summary always;
   dedicated question only when ambiguous.

---

## 7. Deferred (separate work items)

- **Page-maturity model** (`Polished / Rough / Partial`) — same class of problem
  (project may not have the concept) but react-core never generalized it. Needs
  its own optional/strip design. Not in this plan.
- **Option C** convention-drafter skill (`react-conventions`) — only if D-4 is
  revisited.
- **Generator question-wording pass** — plain-language Round 5 menu, expand `MC`
  / `BP` acronyms (the earlier "too-technical" review). Cosmetic; bundle later.

---

## 8. Suggested phasing

1. **Phase A — runtime decoupling** (D-1, D-2): rewrite the 4 templates +
   strip `{{MC_MAX}}` from generator + PLACEHOLDER-REFERENCE. Self-contained;
   makes case 1 (any scheme) work. Validate by generating a profile against a
   project using named sections. **✅ DONE** — `{{MC_MAX}}` removed from all
   templates, generator, PLACEHOLDER-REFERENCE, FORK-GUIDE; `{{CONV_SECTION_REF}}`
   added; CONVENTIONS.template.md renumber warning relaxed; validators pass.
2. **Phase B — seeding** (D-3, D-6, D-7): add the case-2 stack-aware seed + case-3
   ask. Depends on A (so seeded docs are walked by runtime agents). **✅ DONE** —
   "Conventions-doc resolution" (case 1/2/3 + D-9 multi-file + D-10 summary) and
   "Stack-aware conventions seed" sections added to the generator; Pre-conditions,
   Write, and Report steps updated; missing-doc no longer refuses.
3. **Phase C — polish**: resolve §6 open items, then the deferred wording pass.
   **✅ DONE** — §6 resolved as D-8..D-10; Round 5 menu de-jargoned (MC/BP legend
   added, "Section 17 backlog" / "forcing function" / pps-web scope examples
   genericized); Q7 plain-languaged; stale "UI inventory" refs removed. Page-maturity
   decoupling stays out of scope (separate work item).

---

## 9. Validation

- Generate a profile against three fixtures: (1) `MC-N` doc, (2) named-section
  doc, (3) no doc. Confirm: agents render no `{{MC_MAX}}` leftovers; pre-commit
  gate wording is enumerate-and-verify; case 2 writes a stack-grounded
  `CONVENTIONS.md`.
- `./scripts/validate-frontmatter.sh` + `validate-contract.sh` still pass.
- Diff a generated `implement.md` against the archived pps-web `web-implement.md`
  to confirm only the MC-walk wording changed.

---

## 10. Risk

- Completeness gate shifts from "compare to a gen-time constant" to "agent
  enumerates + self-checks" — a slightly softer forcing function. Mitigation:
  reliability comes from doc structure (numbered or clear headings), which loops
  back to case-3 handling. Acceptable given react-audit has run this way already.

---

## 11. Phase D — page-maturity decoupling (mini-plan)

> The last pps-web-ism. `Polished / Rough / Partial` page-maturity vocabulary is
> woven through implement (8), polish (4), and pre-commit (~12) unconditionally.
> Status: **✅ IMPLEMENTED.** Used **3** placeholders (not 2): the flip/regression
> report block ("Rough → Polished") can't be term-swapped, so it became its own
> gated `{{POLISH_STATUS_REPORT_BLOCK}}` (stripped with the polish-audit gate).
> pps-web regen diff = MC-walk + one consolidated page-maturity bullet; functionally
> equivalent (still anchors on Polished, warns Rough/Partial, walks MC-1..7).

### Portable core vs pps-web overlay

- **Portable core (keep, always):** "anchor on a known-good reference page, read
  it in full, cite it — don't anchor on a half-built page or from memory." Every
  project benefits from this.
- **pps-web overlay (make optional):** the specific labels `Polished/Rough/Partial`,
  a progress doc that *tracks maturity*, the flip-candidate / status-flip machinery,
  and "workflow regression on Polished pages." The flip/audit machinery is **already
  gated** via `{{POLISH_STATUS_CHECK_SECTION}}` / `{{WORKFLOW_PATTERNS_TABLE}}` /
  `{{POLISH_AUDIT_*}}` (strip when no audit script). The **prose vocabulary is the
  ungated leak.**

### Design (mirrors the MC treatment)

Two-tier, two new placeholders + reuse of existing gated ones:

| Placeholder | Default (pps-web) | Generic fallback (no maturity model) |
|---|---|---|
| `{{REFERENCE_PAGE_TERM}}` | `Polished` | `reference` (→ "reference baseline page") |
| `{{ANTI_REFERENCE_CLAUSE}}` | ` — never anchor on Rough/Partial pages` | `` (empty) |

- Tier 1 (always): replace the adjective "Polished" in "Polished baseline/page"
  with `{{REFERENCE_PAGE_TERM}}`. The anchor-on-a-good-reference discipline stays.
- Tier 2 (optional): the `{{ANTI_REFERENCE_CLAUSE}}` warnings + flip/status sections
  fill for maturity-model projects, empty/stripped otherwise.
- `{{PROGRESS_DOC}}` + `{{POLISHED_PAGE_EXAMPLES}}` already exist and already fall
  back; reused as the "where reference pages are listed" source.

### Generator detection (case logic, like conventions-doc resolution)

After Scan B/C: does the project track page maturity?
- **Yes** — a progress/status doc with maturity labels detected (or user says so) →
  `{{REFERENCE_PAGE_TERM}}` = the project's "good" label, `{{ANTI_REFERENCE_CLAUSE}}`
  filled, flip/audit sections kept (if an audit script exists).
- **No** — `{{REFERENCE_PAGE_TERM}}` = `reference`, `{{ANTI_REFERENCE_CLAUSE}}` empty,
  flip/audit sections stripped (already happens when no audit script). The user still
  names reference pages → `{{POLISHED_PAGE_EXAMPLES}}` (rename concept to "reference
  pages" in the question wording).

### Change list

- **implement.template.md** (8): lines for "Polished baseline page named" (required
  inputs), recon reads, canonical anchors ("Polished pages … never anchor on Rough
  or Partial"), audit-table baseline refs.
- **polish.template.md** (4): required inputs, recon, conventions line ("pick a
  winner from Polished … never anchor on Rough/Partial"), You-DON'T line.
- **pre-commit.template.md**: "Workflow regression check (Polished pages only)" →
  `{{REFERENCE_PAGE_TERM}}`; flip-candidate lines stay inside the already-gated
  status section.
- **profile-generator/SKILL.md**: add the maturity-model detection + the two new
  placeholders (scan + substitution); reword the `{{POLISHED_PAGE_EXAMPLES}}`
  curated-list question to "reference pages."
- **PLACEHOLDER-REFERENCE.md**: add the two rows.

### Open decisions

1. Keep the placeholder/question name `{{POLISHED_PAGE_EXAMPLES}}` (legacy, internal)
   or rename to `{{REFERENCE_PAGES}}`? Lean: keep the internal name, reword only the
   user-facing question (minimize churn; same call we made for `{{SWAGGER_URL}}`).
2. Auto-detect "good" label from the progress doc, or always ask? Lean: detect when a
   status doc is found, show in summary (consistent with D-10).

### Validation

- Regen pps-web: `{{REFERENCE_PAGE_TERM}}`=`Polished`, clause filled → diff vs archived
  `web-*.md` shows **only** the page-maturity wording swapped to placeholders that
  render back to the same text (i.e. **byte-identical** for pps-web).
- Generate against a no-maturity fixture: confirm no "Polished/Rough/Partial" leaks;
  agents say "reference page."
- Validators pass.

### Risk

- The maturity vocabulary is grammatical prose (not a clean token like `MC-N`), so a
  single term placeholder must slot into several phrasings. Mitigation: choose an
  adjective-form term (`Polished` / `reference`) that reads correctly in "X baseline
  page" / "X pages" / "a X page" — verified against each occurrence during edit.
