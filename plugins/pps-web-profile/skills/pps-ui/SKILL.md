---
name: pps-ui
description: pps-web frontend UI primitive inventory + "don't roll your own" rules. Lists 65 primitives in `pps-web/src/components/ui/` across 8 categories with decision rules for Modal vs Drawer, Select vs Combobox, Toast vs Alert, etc. Use whenever writing, reviewing, or refactoring pps-web React code to pick the right primitive instead of rolling custom markup. Project-scoped to pps-web.
license: MIT
user-invocable: true
metadata:
  version: "1.0.0"
  scope: pps-web only (project-specific)
  component_root: pps-web/src/components/ui/
  category_source: pps-web/src/components/ui/index.ts (auto-grouped)
---

# pps-web UI Primitives

The single source of truth for **what's available** in `pps-web/src/components/ui/` and **when to reach for each**. Agents working on pps-web React code should consult this skill before writing new markup — the most common mistake is reimplementing a primitive that already exists.

> **Project scope:** This skill is pps-web-specific. The component list is hard-coded to what exists under `pps-web/src/components/ui/`. Use `react-perf` / `react-composition` / `react-audit` / `react-dry` / `react-revamp` for the framework-agnostic counterparts.

---

## Section A — Don't Roll Your Own (high-priority rules)

These are the patterns agents miss most often. Treat each row as a hard rule.

| ❌ Don't write | ✅ Use | Why / Notes |
|---|---|---|
| `<input type="number">` | `<NumberInput variant="integer\|decimal\|currency">` | Locale-aware format, iOS-zoom prevention, currency helpers. **Mandatory** per CLAUDE.md. |
| `<input type="date">` | `<DatePickerInput>` | TH/EN calendar (พ.ศ./ค.ศ.), auto id via `React.useId()`. Pass no `id` literal. |
| Month-only picker | `<MonthPickerInput>` | Same TH/EN treatment, month granularity. |
| Raw `<dialog>` / hand-rolled modal | `<Dialog>` (≤480px, decide) OR `<Sheet>` (480–540 default, edit/create) | "Modal vs Drawer" rule lives in CLAUDE.md; pick by intent, not by feel. |
| Confirm-and-destroy markup | `<DeleteConfirmDialog>` or `<AlertDialog>` | Destructive actions stay in centered modal, never in drawer. |
| Raw `<table>` markup | `<Table>` + wrap in `TABLE_STYLES.CONTAINER` | Single border source on `<tr>`, density tokens, no manual `text-label-md` on `<TableCell>`. |
| `<button>` element | `<Button variant=... size=...>` | Variants + focus ring + tokens. Use `asChild` for `<Link>`-like cases. |
| `useState` + spinner for async submit | `<LoadingButton isLoading loadingLabel>` | Pattern C — label stays, spinner appears, `aria-busy` set. Never roll your own. |
| Manual `<label>` + `<input>` + `htmlFor`/`id` | `<Field>` (auto-wires `id`/`htmlFor`/`aria-*` via `React.useId()`) | Avoids id collisions when the form renders multiple times. **Mandatory** per CLAUDE.md → Form `id`. |
| Manual text overflow + tooltip | `<TruncatedText>` | Auto tooltip only when actually overflowing. |
| Inline empty-state markup | `<EmptyState>` / `<EmptyStateNoData>` / `<EmptyStateNoResults>` / `<EmptyStateLoading>` / `<EmptyStateError>` | Consistent illustration + copy + CTA shape. |
| Inline error markup | `<ErrorState>` / `<ErrorStateNetwork>` / `<ErrorStateNotFound>` / `<ErrorStatePermission>` / `<ErrorStateLoading>` | Distinct from EmptyState — system error vs no data. |
| Colored `<div>` for banner | `<Alert overline="..." variant=...>` | Tokens + `role/aria-live`. `overline` is short uppercase category, i18n'd. Density via `className`: standalone `p-5`, dialog `p-4`, compact `p-3`. **Mandatory** per CLAUDE.md → Color tokens. |
| Hand-rolled stats card | `<StatsCard iconVariant=...>` + `<StatsGrid>` | Count-based rule: `count > 0 ? '{warning\|error\|success}' : 'neutral'`. Never `undefined` → paints brand-red on zero. |
| Hand-rolled toast logic | `<Toaster>` from `sonner` (global provider) + `toast` API | Single global instance in app root. |
| Raw `<select>` element | `<Select>` (≤7 fixed options) OR `<Combobox>` (searchable / async / many options) | Pick by data shape. See Section C decision rules. |
| Hand-rolled breadcrumbs | `<Breadcrumb>` (and `AppBreadcrumb` for route-driven crumbs) | UUID resolver via `useEntityNameResolver`; add `EntityType` when introducing a new entity detail route. |
| Raw text input + format hooks | `<FormattedIdInput>` | For citizen-id / phone / formatted-string inputs. |
| Bare `<a>` for in-app navigation | `<Link>` (project wrapper) | Project's routing-aware Link. |
| Manual sticky-tab styling | `<StickyTabs>` + `<TabBadge>` / `<TabErrorDot>` | Sticky pattern, tab indicators baked in. |
| Inline progress bar | `<Progress indeterminate />` or `<Progress value={pct} />` | File-upload progress patterns: drive states from a `phase` flag. |
| Inline avatar div | `<Avatar>` or `<CompanyAvatar>` | CompanyAvatar baked with company-tenant convention. |
| Custom multi-line breakdown | `<BreakdownColumn>` + `BreakdownItem` | For payroll/document-line breakdowns. |
| Hand-rolled multi-step UI | `<Stepper>` | See `docs/components/stepper.md` for variants. |
| Inline table-filter pills | `<TableFilter>` / `<TableFilterSearch>` / `<TableFilterStatus>` | Project's standard pill-filter pattern. |

If a hard rule above doesn't fit your use case, **say so explicitly** in the report — don't silently invent a workaround. The list is opinionated on purpose.

---

## Section B — Full Inventory

Categories follow `pps-web/src/components/ui/index.ts`. All imports are `@/components/ui/<name>` unless noted.

### Core inputs

| Component | Main exports | When to use |
|---|---|---|
| **Button** | `Button`, `ButtonProps` | All actions. Variants: `default`, `outline`, `ghost`, `destructive`, `link`. Sizes: `sm`, `default`, `lg`, `icon`. |
| **Input** | `Input` | Text input. Always wrap in `<Field>`. Uses `text-body-md` (prevents iOS zoom). |
| **NumberInput** | `NumberInput`, `NumberInputProps` | Numeric. Variants: `integer`, `decimal`, `currency`. Never `<input type="number">`. |
| **Textarea** | `Textarea` | Multiline text. |
| **Label** | `Label`, `LabelProps` | Only when not using `<Field>`. Prefer Field. |

### Selection inputs

| Component | Main exports | When to use |
|---|---|---|
| **Calendar** | `Calendar` | Inline calendar (rare standalone — usually via DatePicker). |
| **Checkbox** | `Checkbox`, `CheckboxField` | `CheckboxField` for label-paired form usage. |
| **Combobox** | `Combobox`, `ComboboxContent`, `ComboboxInput`, `ComboboxItem`, `ComboboxList`, `ComboboxEmpty` | Searchable / async / many-option select. Compound component. |
| **RadioGroup** | `RadioGroup`, `RadioField` | `RadioField` for label-paired form usage. |
| **Select** | `Select` (Radix) | ≤7 fixed options, no search needed. |
| **Slider** | `Slider` | Numeric range with thumb. |
| **Switch** | `Switch` | Binary toggle (on/off settings). |
| **Toggle** | `Toggle` | Single-toggle button. |
| **ToggleGroup** | `ToggleGroup` | Multi-toggle (segmented). |

### Display

| Component | Main exports | When to use |
|---|---|---|
| **Avatar** | `Avatar` | User/entity avatar. |
| **CompanyAvatar** | `CompanyAvatar` | Tenant company avatar (specific styling). |
| **Badge** | `Badge`, `BadgeProps` | Small inline status / category tag. |
| **Card** | `Card` | Container with project shadow/border tokens. |
| **EmptyState** | `EmptyState`, `EmptyStateNoData`, `EmptyStateNoResults`, `EmptyStateLoading`, `EmptyStateError`, `ActionButton` | No-data states. Pick the variant matching the cause. |
| **ErrorState** | `ErrorState`, `ErrorStateNetwork`, `ErrorStateNotFound`, `ErrorStatePermission`, `ErrorStateLoading` | System errors (vs EmptyState = no data). |
| **Skeleton** | `Skeleton` | Loading shapes. Always with explicit width (`h-4 w-32`) — never auto-width. |
| **StatsCard** | `StatsCard`, `StatsCardProps`, `StatsGrid` | KPI tiles. `iconVariant` count rule above. |
| **Table** | `Table`, `TableRow`, `TableHead`, `TableCell`, `TableBody`, `TableHeader` | Tabular data. Wrap with `TABLE_STYLES.CONTAINER`. See CLAUDE.md → Tables. |
| **TruncatedText** | `TruncatedText`, `TruncatedTextProps` | Auto-tooltip on text overflow. |
| **BreakdownColumn** | `BreakdownColumn`, `BreakdownItem` | Payroll/document line breakdowns. |
| **NumberDisplay** | `NumberDisplay`, `NumberDisplayProps` | Read-only numeric display with format. |

### Feedback

| Component | Main exports | When to use |
|---|---|---|
| **Alert** | `Alert` + `overline` prop | Persistent banner. Variant by state. |
| **AlertDialog** | `AlertDialog` | Destructive / blocking confirmation. |
| **DeleteConfirmDialog** | `DeleteConfirmDialog`, `DeleteConfirmDialogProps` | Convenience wrapper for delete flows. |
| **CharacterCounter** | `CharacterCounter`, `CharacterCounterProps` | Char/length indicator under text inputs. |
| **LoadingOverlay** | `LoadingOverlay`, `LoadingOverlayProps` | Cover-the-content loading state. |
| **LoadingButton** | `LoadingButton`, `LoadingButtonProps` | Async submit button. Pattern C. |
| **Progress** | `Progress` | Determinate (`value={pct}`) or indeterminate (`indeterminate`). |
| **Spinner** | `Spinner`, `SpinnerProps` | Standalone spinner. Last resort — most loading should be skeleton/LoadingButton/Progress. |
| **Toaster (sonner)** | `Toaster`; `toast` from `sonner` | Global toast container. One instance in app root. |

### Navigation / Overlay

| Component | Main exports | When to use |
|---|---|---|
| **Accordion** | `Accordion` | Expand/collapse sections. |
| **Breadcrumb** | `Breadcrumb` | Manual breadcrumb (use `AppBreadcrumb` for auto). |
| **Command** | `Command` | Command palette / fuzzy-find input. |
| **ContextMenu** | `ContextMenu` | Right-click menu. |
| **Dialog** | `Dialog` (Radix) | Confirm/decide centered modal. ≤480px. |
| **DropdownMenu** | `DropdownMenu` | Action menu attached to a trigger. |
| **Pagination** | `Pagination` | Generic pagination. For tables prefer `<TablePagination>`. |
| **TablePagination** | `TablePagination` | Table-specific pagination with density tokens. |
| **Popover** | `Popover` | Floating panel attached to trigger. |
| **Tabs** | `Tabs` (Radix) | Plain tabs. For sticky pattern use `<StickyTabs>`. |
| **StickyTabs** | `StickyTabs` | Sticky-positioned tab bar. |
| **TabBadge / TabErrorDot** | `TabBadge`, `TabErrorDot` | Indicators on tab triggers. |
| **Tooltip** | `Tooltip` | Hover/focus reveal. Use `<TruncatedText>` for overflow-driven tooltips. |

### Layout

| Component | Main exports | When to use |
|---|---|---|
| **Drawer** | `Drawer` | Bottom-sheet drawer (mobile-style). Different from `<Sheet>`. |
| **Sheet** | `Sheet` | Side drawer (right edge). Use for Edit/Create entity flows with ≥5 fields. |
| **PageLayout** | `PageLayout`, `PageLayoutProps` | Wrapper for every page. `pt-6` if skeleton mirrors it. |
| **PageHeader** | `PageHeader`, `PageHeaderProps` | Page title/description/meta/back/actions/sticky. |
| **SectionHeader** | `SectionHeader`, `SectionHeaderProps` | In-page section divider with title. |
| **ScrollArea** | `ScrollArea` | Custom-scrollbar container. |
| **Separator** | `Separator` | Horizontal/vertical divider. |

### Form composition

| Component | Main exports | When to use |
|---|---|---|
| **Field** | `Field`, `FieldLabelProps`; `Field.Control` skips native wrappers | Wraps every form input. Auto-wires `id`/`htmlFor`/`aria-*`. |
| **InputGroup** | `InputGroup`, `InputGroupAddonProps`, `InputGroupButtonProps` | Input with leading/trailing addon or button. |
| **InputOTP** | `InputOTP` | One-time passcode entry. |
| **DatePicker** | `DatePicker`, `DatePickerProps` | Inline date selection (rare — usually want DatePickerInput). |
| **DatePickerInput** | `DatePickerInput`, `DatePickerInputProps` | **Standard** date input. TH/EN handling. Auto id. |
| **MonthPickerInput** | `MonthPickerInput` | Month-granularity input. |
| **FormattedIdInput** | (folder import: `@/components/ui/formatted-id-input`) | Formatted text inputs (citizen-id, phone). |

### Specialized / Notables (not auto-exported via `index.ts`)

Import directly: `@/components/ui/<name>`.

| Component | Purpose |
|---|---|
| **Link** | Project's routing-aware Link wrapper. |
| **Stepper** | Multi-step UI. See `docs/components/stepper.md`. |
| **TableFilter / TableFilterSearch / TableFilterStatus** | Pill-style table filters. Folder import: `@/components/ui/table-filter`. |
| **Collapsible** | Radix collapsible (small wrapper). |

---

## Section C — Decision Rules (compound choices)

### Modal vs Drawer vs Page

Pick by **intent**, not by aesthetic. Full table in `pps-web/CLAUDE.md` → "Modal vs Drawer (predictability rule)".

| Intent | Use | Width |
|---|---|---|
| Edit/Create entity (≥5 fields or nested) | `<Sheet>` (right drawer) | 480–540 default, 640–720 wide |
| Confirm / Destroy / Decide / Approve | `<Dialog>` (centered) | ≤480px |
| Quick 1–2 field edit | `<Dialog>` | ≤480px |
| Multi-step wizard >3 steps OR data-heavy editor | Sub-route page | — |
| Picker / Display-only | `<Dialog>` | ≤600px |

**Anti-patterns:** Modal at `max-w-3xl+` with internal scroll (use Sheet/Page). "Edit X" as modal in one place and drawer elsewhere for the same entity. Destructive actions in a Drawer.

### Select vs Combobox

| Use Select when | Use Combobox when |
|---|---|
| ≤ 7 fixed options | > 7 options, OR search needed, OR async-loaded options |
| Options known at compile time | Options come from API |
| No icons/avatars in options | Rich item rendering |

### Toast vs Alert

| Use Toast (`toast` from sonner) when | Use Alert when |
|---|---|
| Transient — fade after 3–5s | Persistent banner |
| Result of an action (saved, deleted, error returned) | Stateful page-level context (warning, info, error that doesn't auto-dismiss) |
| User can ignore it | User should read it |

### EmptyState vs ErrorState

| Use EmptyState variants when | Use ErrorState variants when |
|---|---|
| Query returned 0 results | Query failed (network/permission/server) |
| User hasn't created any X yet | The system can't show data right now |
| `EmptyStateNoResults` for filtered-out, `EmptyStateNoData` for never-had-data | Map to network / not-found / permission / generic error |

### Dialog vs AlertDialog vs DeleteConfirmDialog

| Use | When |
|---|---|
| `<Dialog>` | General modal: pick an option, view detail, edit ≤2 fields |
| `<AlertDialog>` | Confirm a destructive or irreversible decision (custom copy) |
| `<DeleteConfirmDialog>` | Specifically a "delete X?" — shortest path, baked in |

### Skeleton vs Spinner vs LoadingOverlay vs Progress

| Use | When |
|---|---|
| `<Skeleton>` | Initial fetch on list/detail page. Mirror real layout. |
| `<LoadingButton>` | Async submit inside a button. |
| `<Progress indeterminate />` | Active operation (file upload, multi-step process). |
| `<Progress value={pct} />` | Determinate progress (upload %). |
| `<LoadingOverlay>` | Block interaction with already-rendered content during mutation. |
| `<Spinner>` | Last resort. Most loading should be one of the above. |

---

## Section D — Audit Procedure

When asked to "check pps-web component usage" or invoked as part of an audit:

### Inputs (collect via `AskUserQuestion` if not given)

1. **Target file(s) or feature** to audit.
2. **Output language** — English or Thai. Ask if expected output > 5 findings.

### Walkthrough

For each target file, scan for the following patterns. Report `file:line` for every hit.

1. **Native HTML over primitive**
   - Grep for `<button`, `<input`, `<select`, `<table`, `<dialog`, `<label`, `<a href=` → for each, decide if it should be the corresponding primitive (cross-check against Section A).
2. **Hand-rolled patterns**
   - `useState` for `isLoading` near a `<Button>` → flag for `<LoadingButton>`.
   - `useState` + `setOpen` for modal/drawer → confirm Dialog/Sheet is being used (not raw markup).
   - Manual `htmlFor`/`id` on label-input pairs → flag for `<Field>`.
   - `.truncate` with conditional tooltip → flag for `<TruncatedText>`.
3. **Token bypass / magic numbers** (cross-reference `react-dry` if appropriate)
   - `text-[Xpx]`, `mt-[Ypx]`, `w-[Zpx]`, `text-#hex` → flag, suggest the nearest token.
4. **Numeric input compliance**
   - Any `<input type="number">` → flag, must be `<NumberInput>`.
5. **Date input compliance**
   - Any `<input type="date">` → flag, must be `<DatePickerInput>`.
6. **Empty/Error state usage**
   - `data.length === 0 ? <div>...` patterns → flag for `<EmptyState*>` variant.
   - Try/catch error UI built from divs → flag for `<ErrorState*>` variant.
7. **Modal intent**
   - Detect destructive actions in `<Sheet>` (should be `<AlertDialog>` or `<DeleteConfirmDialog>`).
   - Detect form edits in `<Dialog>` with `max-w-3xl+` (should be `<Sheet>`).

### Output

Report findings as:

```
file:line — issue → primitive to use (reason)
```

Example:
```
src/features/leave/pages/LeaveListPage/index.tsx:42 — <button> for action → <Button variant="default"> (a11y + tokens)
src/features/leave/pages/LeaveListPage/index.tsx:58 — <input type="number"> → <NumberInput variant="integer"> (iOS zoom + locale)
src/features/leave/components/forms/LeaveDrawer.tsx:91 — useState for isSubmitting + spinner → <LoadingButton isLoading> (Pattern C)
```

End the turn with:

```
Status: pps-ui audit complete. <N> findings. Waiting for "apply" before any edit.
```

---

## Stop Conditions (READ-ONLY discipline)

This skill is **reference + read-only audit**. After producing findings:

- Do not run `Edit`, `Write`, `NotebookEdit`.
- Do not stage / commit / push.
- The invoking agent (or the user) decides what to apply.

---

## When to Reference Other Skills

This skill is the **pps-web primitive layer**. Pair it with the framework-agnostic skills in the kit when the work goes beyond primitive choice:

- **CSS / style variance across multiple usages of a primitive** → recommend `react-dry`. Example: Button is used everywhere but with 4 different className clusters → primitive choice is fine, but variance needs DRY.
- **Feature-wide consistency issues** (multiple features handle navigation, tables, dialogs differently) → recommend `react-audit` (multi-mode). Example: leave / attendance / timesheet each render PageHeader differently.
- **Page-level UX redesign** → recommend `react-revamp`. Example: the audit shows a page is using 5 wrong primitives because the underlying flow is broken — fix the flow first, primitive choices follow.
- **Performance anti-patterns** found near the primitives (inline component definitions, missing memo, sequential awaits) → recommend `react-perf`.
- **Boolean-prop bloat / inline components / `forwardRef` in React 19** found on the audited primitives → recommend `react-composition`.

Surface these as **inline notes** in the audit findings, not as additional audit work. The user decides whether to invoke them.

---

## Adapting for Other Projects

This skill's inventory is **hard-coded** to pps-web's `src/components/ui/`. To reuse the pattern in another project:

1. Copy this `SKILL.md` to the new project's `claude-kit/skills/<project>-ui/SKILL.md` (or wherever).
2. Replace Section B's inventory with the new project's primitives.
3. Update Section A's "Don't roll your own" list with the project's specific must-use rules.
4. Update Section C's decision rules for the new project's design system.
5. Section D's audit procedure stays mostly the same — only the primitive names change.

The procedure is universal; the inventory is the project-specific part.
