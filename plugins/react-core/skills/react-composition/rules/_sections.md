---
note: "Section metadata for react-composition. Order matches the priority list in SKILL.md."
---

# Sections

Four sections, ordered by typical impact on a refactor.

| # | Folder | Impact | What it covers |
|---|---|---|---|
| 1 | `architecture/` | HIGH | Component shape — how to avoid boolean-prop bloat and how to expose primitives. |
| 2 | `state/` | HIGH-MEDIUM | Where state lives — lifting, sharing via context, decoupling source from UI. |
| 3 | `patterns/` | MEDIUM | Day-to-day techniques — children over render props, explicit variants over flag-driven modes. |
| 4 | `react19/` | MEDIUM | React 19 API rewrites that obsolete pre-19 patterns (`forwardRef`, `useContext`). |

Read in order when refactoring; pick the section closest to your concern when answering a one-shot question.
