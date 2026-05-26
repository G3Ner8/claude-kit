---
name: react-composition
description: React 19 composition patterns for building flexible, maintainable components. Use when refactoring boolean-prop bloat, designing component libraries, building compound components, lifting state into providers, or reviewing component APIs. Covers 8 rules across architecture, state management, implementation patterns, and React 19 API changes (`ref` as prop, `use()` over `useContext()`).
license: MIT
user-invocable: true
metadata:
  version: "1.0.0"
  type: reference
  status: stable
  stack: React 19, TypeScript
  scope: framework-agnostic (web React preferred examples)
---

# React Composition Patterns

8 patterns for building composable, scalable React 19 components. Optimized for AI agents to apply when designing component APIs, refactoring boolean-prop bloat, or building compound components.

## Why this exists

The most common cause of unmaintainable React code is **boolean prop proliferation** — components grow `isLoading`, `isThread`, `isEditing`, `isPrimary`, `isLarge` until the call sites are impossible to reason about and the implementation is a maze of conditionals. Each new boolean doubles the state space.

The fix is composition: smaller building blocks, explicit variants, lifted state, shared context. These patterns are what mature React codebases (Radix, shadcn/ui, Reach UI, Ariakit) settle on.

## When to use

Reference these patterns when:
- Refactoring a component with > 3 boolean props
- Designing a new reusable component library
- Building a compound component (Dialog, Menu, Tabs, Combobox)
- Deciding where state should live (component vs provider)
- Reviewing component architecture
- Writing React 19 code (don't use `forwardRef` or `useContext`)

Skip this skill for:
- Non-React code (server logic, build config)
- Performance tuning — use `react-perf`
- Testing patterns — use `react-test-patterns`

## Rule Categories by Priority

| Priority | Category | Folder | Impact |
|---|---|---|---|
| 1 | Component Architecture | `rules/architecture/` | HIGH |
| 2 | State Management | `rules/state/` | HIGH–MEDIUM |
| 3 | Implementation Patterns | `rules/patterns/` | MEDIUM |
| 4 | React 19 APIs | `rules/react19/` | MEDIUM |

## Quick Index

### 1. Component Architecture (`architecture/`)
- `avoid-boolean-props` — boolean props create exponential state space; use composition or explicit variants
- `compound-components` — share state via context, let consumers compose subcomponents

### 2. State Management (`state/`)
- `lift-state` — move state into a provider so siblings can read/write without prop drilling
- `context-interface` — define a generic `{ state, actions, meta }` context so the UI is dependency-injectable
- `decouple-implementation` — the provider is the only place that knows how state is sourced (useState? Zustand? server-synced?)

### 3. Implementation Patterns (`patterns/`)
- `children-over-render-props` — prefer `<Frame>{children}</Frame>` over `renderHeader`/`renderFooter` props
- `explicit-variants` — `<ThreadComposer />` + `<EditComposer />` beats `<Composer isThread isEditing />`

### 4. React 19 APIs (`react19/`)
- `ref-and-context` — `ref` is a regular prop now; `use(Context)` replaces `useContext(Context)`

## How to Use

Open the rule file you need:

```
rules/architecture/avoid-boolean-props.md
rules/state/context-interface.md
```

Each rule file follows the same shape:

1. **Rationale** — what breaks without the pattern, in 1-2 paragraphs
2. **Incorrect** — a realistic anti-pattern (not strawman) with explanation of why it grows pain over time
3. **Correct** — the recommended pattern with React 19-idiomatic code
4. **Key conventions** — the small rules that make the pattern work in practice
5. **When NOT to apply** — explicit boundaries so the rule doesn't get over-applied

## Core Principles

1. **Composition over configuration** — let consumers compose, don't add a prop for every variation
2. **Lift state, compose internals** — state lives in providers, subcomponents read context
3. **Explicit variants over boolean modes** — `ThreadComposer` not `Composer isThread`
4. **The interface is the contract** — define `{ state, actions, meta }` once, swap providers freely

