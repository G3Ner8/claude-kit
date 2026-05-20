# pps-ui — Maintenance & Provenance

A **project-specific** skill that inventories pps-web's UI primitive library (`pps-web/src/components/ui/`) and lists the most common "don't roll your own" anti-patterns. Used by every agent that touches pps-web React code.

## Why this skill exists

`pps-web/CLAUDE.md` already says "prefer `src/components/ui/*` over custom" — but agents routinely miss it because:

- The CLAUDE.md mention is a single line, not a recall list.
- Without an inventory, agents don't know which primitives exist.
- Without anti-pattern examples, agents don't recognize when they're about to roll their own.

This skill fixes that. It's a **reference document + audit procedure** that activates whenever agents work in `pps-web/src/`.

## Project-only scope

Unlike the other skills in this kit (`react-perf`, `react-composition`, `react-audit`, `react-revamp`, `react-dry`) which are framework-agnostic, **this skill is pps-web-specific**. The inventory in Section B is hard-coded to what exists at `pps-web/src/components/ui/`.

If you fork this kit into another project, you'll need to either:

- Replace the inventory with the new project's primitives (see Section "Adapting for Other Projects" in `SKILL.md`)
- Or drop this skill entirely and rely on the framework-agnostic ones

## Inventory source

Categories follow `pps-web/src/components/ui/index.ts`:

- Core inputs (5) · Selection inputs (9) · Display (12) · Feedback (9)
- Navigation/Overlay (13) · Layout (7) · Form composition (7)
- Specialized / Notables not in index.ts (4)

**65 total primitives.**

Notables not in `index.ts` (auto-export gap):

- `breakdown-column`, `company-avatar`, `delete-confirm-dialog`, `error-state`, `formatted-id-input/`, `link`, `loading-button`, `month-picker-input`, `sonner` (Toaster), `stepper`, `sticky-tabs`, `tab-indicators`, `truncated-text`, `table-filter/`, `collapsible`

These are imported via direct paths (`@/components/ui/<name>`). The skill flags this gap so it can be addressed (or accepted as intentional).

## When agents invoke this skill

Description triggers on:

- Writing or refactoring code under `pps-web/src/`
- "Check pps-web primitives", "audit component usage", "design-system compliance"
- As a step inside `web-implement` agent (before writing code), `web-polish` agent (during cleanup), `web-pre-commit` agent (during diff scan)

## Output (when used in audit mode)

Findings in `file:line — issue → primitive to use (reason)` format. Report ends with `Status: pps-ui audit complete. <N> findings.`

## Maintenance

When the primitive library changes (new component added to `pps-web/src/components/ui/`, existing one renamed/removed):

1. Re-scan: `ls pps-web/src/components/ui/`
2. Update Section B's inventory rows.
3. If a new primitive replaces a hand-rolled pattern → add an entry to Section A.
4. Bump `metadata.version` in frontmatter.
5. Add a 1-line changelog at the bottom of `SKILL.md` (or a top-level changelog if the repo has one).

## Refresh script (optional)

```bash
# Quick sanity check — current primitive count
ls pps-web/src/components/ui/*.tsx pps-web/src/components/ui/*/index.* 2>/dev/null | wc -l

# Diff against the skill's inventory
ls pps-web/src/components/ui/ | sort > /tmp/disk.txt
grep -oE '`[A-Z][A-Za-z]+`' SKILL.md | tr -d '`' | sort -u > /tmp/skill.txt
diff /tmp/disk.txt /tmp/skill.txt
```

## Related skills in this kit

- `react-dry` — cross-component CSS standardization. Use when divergence isn't about primitive choice but about styling variance.
- `react-audit` — feature-level audit. Use for cross-feature consistency.
- `react-composition` — architecture patterns. Use when the audit surfaces boolean-prop bloat or compound-component questions on the primitives.
- `react-perf` — performance rules. Use when scanning for re-render anti-patterns near these primitives.
