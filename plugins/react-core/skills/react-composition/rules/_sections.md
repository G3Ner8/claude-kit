# Sections

This file defines the four sections used by `react-composition`, their priority ordering, impact levels, and folder mapping.

---

## 1. Component Architecture (`architecture/`)

**Impact:** HIGH
**Description:** Fundamental patterns for structuring components. Avoid boolean prop proliferation, use compound components, expose primitives that consumers compose into variants.

## 2. State Management (`state/`)

**Impact:** HIGH–MEDIUM
**Description:** Patterns for placing state in providers, sharing context across composed subcomponents, and decoupling state implementation from UI.

## 3. Implementation Patterns (`patterns/`)

**Impact:** MEDIUM
**Description:** Specific techniques: prefer children over render props, prefer explicit variant components over boolean modes.

## 4. React 19 APIs (`react19/`)

**Impact:** MEDIUM
**Description:** React 19+ only. `ref` is now a regular prop — `forwardRef` is deprecated. `use(Context)` replaces `useContext(Context)` and can be called conditionally.
