# react-composition — Maintenance & Provenance

A curated React 19 composition-patterns skill (renamed `composition-patterns` → `react-composition` for consistency with `react-perf`). Derived from [vercel-labs/agent-skills/skills/composition-patterns](https://github.com/vercel-labs/agent-skills/tree/main/skills/composition-patterns).

## Why a curated fork

The upstream is excellent but its code examples target **React Native** primitives (`TextInput`, `<Button onPress>`, `onChangeText`). That choice doesn't change the patterns — they apply to any React tree — but it forces every web-React reader to translate the examples in their head.

This skill keeps the patterns intact and rewrites the examples in **web React** idioms (`<input>`, `<button onClick>`, `onChange`) so they paste directly into a Vite/Next.js/CRA project. Where a pattern depends on a specific element (e.g., `<form>`), the example uses the standard web tag.

## Stack assumptions

- **React** ≥ 19.0 (`<Context value={...}>` short form, `use(Context)`, `ref` as a regular prop)
- **TypeScript** (examples are TS, but the patterns work in JS)
- No framework lock-in — works in Vite, Next.js, Remix, CRA, Astro Islands, anywhere React runs

## Rule inventory (8 rules)

| Section | Files | Status |
|---|---|---|
| `architecture/` | 2 | both rewritten for web React idioms |
| `state/` | 3 | all rewritten for web React idioms |
| `patterns/` | 2 | both rewritten for web React idioms |
| `react19/` | 1 | rewritten — was `TextInput` example, now `<input>` |

All 8 rules underwent **light-to-medium edits**: examples converted to web React, frontmatter normalized, subfolder paths adjusted, no Next.js-specific assumptions introduced.

## Upstream → this skill mapping

| Upstream | This skill | Change |
|---|---|---|
| `architecture-avoid-boolean-props.md` | `architecture/avoid-boolean-props.md` | RN → web example |
| `architecture-compound-components.md` | `architecture/compound-components.md` | RN → web example |
| `state-lift-state.md` | `state/lift-state.md` | RN → web example |
| `state-context-interface.md` | `state/context-interface.md` | RN → web example |
| `state-decouple-implementation.md` | `state/decouple-implementation.md` | RN → web example |
| `patterns-children-over-render-props.md` | `patterns/children-over-render-props.md` | RN → web example |
| `patterns-explicit-variants.md` | `patterns/explicit-variants.md` | RN → web example |
| `react19-no-forwardref.md` | `react19/no-forwardref.md` | RN `TextInput` → web `<input>` |

No upstream rules dropped — all 8 carry over.

## Refreshing from upstream

```bash
curl -sSL https://api.github.com/repos/vercel-labs/agent-skills/contents/skills/composition-patterns/rules \
  | grep '"name"' | sort > /tmp/upstream.txt
ls rules/*/*.md | xargs -n1 basename | sort > /tmp/local.txt
diff /tmp/upstream.txt /tmp/local.txt
```

For new upstream rules, copy under the matching subfolder and translate any React Native primitives to web equivalents.
