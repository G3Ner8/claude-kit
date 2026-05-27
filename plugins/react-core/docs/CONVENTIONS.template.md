# Mandatory Conventions (template)

Copy this file to your repository root (typically as `CLAUDE.md` or `CONVENTIONS.md`), then fill each section with the rules your project actually enforces. The `react-audit` skill reads this file as its source of truth for Phase E.

Conventions are numbered `MC-N` (Mandatory Convention). Agents and audits cite the line number, not the rule text — keep numbering stable across edits to preserve refs.

---

## MC-1 — HTML & accessibility

Required structural and a11y rules — nested forms, label-control pairing, alert/banner placement, autofocus discipline, role/aria usage, semantic landmark coverage, focus-management for modal/drawer.

> Example: "No nested `<form>` elements. Every `<input>` is paired with `<label>` via `htmlFor`. Alerts use `role='alert'` only for live updates, otherwise prefer static text."

## MC-2 — Input primitives & variants

Required primitives for numeric input, formatted IDs, dates, currency, etc. — no native HTML inputs where the project ships a typed primitive. Document the variants (filled/outline/ghost), sizing tokens, and the default `variant` per context.

> Example: "Use `NumberInput` (not `<input type='number'>`). Use `DatePicker` (not `<input type='date'>`). Default variant is `outline` everywhere."

## MC-3 — Tables

Required table tokens (header style, cell padding, row hover, zebra), action-column rules ([+Add] button placement, row-action drawer/menu), empty-state component, pagination placement, sticky header rules.

> Example: "All tables import `TABLE_STYLES` tokens. Row-action menu uses `<DropdownMenu>` aligned end. Empty state uses `<EmptyState>` not custom markup."

## MC-4 — Modal vs Drawer

When to use Modal vs Drawer. Drawer template (size, header, footer). Submit-button icon consistency. Cancel-button discipline (`type='button'` always).

> Example: "Use Modal for confirmation / form ≤ 3 fields. Use Drawer for form > 3 fields or table preview. Submit button shows `<Save />` icon; Drawer footer is right-aligned."

## MC-5 — Forms & validation

Schema factory shape (`createSchema(t: TFunction)`), `FORM_GRID` tokens, payload builder location, dirty-tracking source of truth, validation timing (`onBlur` vs `onChange`), unsaved-guard hook coverage.

> Example: "All form schemas are factories taking `t: TFunction`. Forms use `FORM_GRID` Tailwind tokens for layout. Payload built in a dedicated `buildPayload()` helper, never inline."

## MC-6 — i18n & cross-feature concerns

Namespace per feature. Shared `common` namespace policy. en/th (or your locales) parity check. Cross-feature import rules (no reaching into a sibling feature's internals).

> Example: "Each feature owns its i18n namespace. Shared strings go to `common`. en + th must have identical key sets; missing keys fail CI."

## MC-7 — Logging & error handling

No raw `console.*` in `src/`. Use the project logger (`logger.info` / `logger.error`). All user-facing errors trigger `toast.error`. Persistent log meta uses `{ persist: false }` for transient events.

> Example: "Never `console.log` in src/. Use `logger.error(err, { feature: 'orders' })` + `toast.error(t('errors.failed'))`. Set `persist: false` for events not worth keeping past the session."

---

## Adapting

- Sections are not fixed at 7 — add `MC-8`, `MC-9` for project-specific rules (e.g. testing, performance budgets, security gates).
- Renaming or renumbering sections is fine — generated agents enumerate whatever rules this doc defines at runtime, so there is no baked `MC-N` reference in agent prompts to migrate. (Keep line numbers stable within a section, since audits cite rules by line.)
- Keep section titles short (≤ 5 words) — agents copy them verbatim into status lines.
