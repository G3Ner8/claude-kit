---
title: Lift State to a Provider
impact: HIGH
impactDescription: lets sibling components read and update shared state without prop drilling or callback gymnastics
tags: composition, state, context, provider, architecture
---

## Lift State to a Provider

When two or more sibling components need to read or update the same state, the cheapest fix is to move that state into a parent and pass it down via props. The moment the prop chain crosses 2-3 component layers, that becomes prop drilling — every intermediate component carries props it doesn't use, and refactors ripple through the tree.

The next move is to lift the state **into a provider**: a parent component that owns the state in `useState` (or `useReducer`), exposes it through Context, and renders children that read it via `use(Context)`. Siblings can then share state without the intermediate components knowing it exists.

This pattern underpins the [compound-component](../architecture/compound-components.md) approach — the provider is the parent that holds `open`/`setOpen`; subcomponents read what they need.

**Incorrect — prop drilling through layers that don't care:**

```tsx
// Page knows about selectedId only to forward it to <Toolbar> and <List>.
function UsersPage() {
  const [selectedId, setSelectedId] = useState<string | null>(null);
  return (
    <PageLayout selectedId={selectedId} onSelect={setSelectedId}>
      <PageHeader selectedId={selectedId} onSelect={setSelectedId} />
      <PageBody selectedId={selectedId} onSelect={setSelectedId} />
    </PageLayout>
  );
}

function PageLayout({ children, selectedId, onSelect }: PageLayoutProps) {
  // Doesn't use selectedId — just forwards it.
  return <div className="layout">{children}</div>;
}

function PageBody({ selectedId, onSelect }: PageBodyProps) {
  return (
    <>
      <Toolbar selectedId={selectedId} onSelect={onSelect} />
      <List selectedId={selectedId} onSelect={onSelect} />
    </>
  );
}
```

Three components carry `selectedId`/`onSelect` props they don't read. Refactoring (renaming the prop, changing the type, adding a third sibling) is a multi-file diff.

**Correct — provider owns the state; descendants read it where needed:**

```tsx
interface SelectionContextValue {
  selectedId: string | null;
  select: (id: string | null) => void;
}

const SelectionContext = createContext<SelectionContextValue | null>(null);

function useSelection() {
  const ctx = use(SelectionContext);
  if (!ctx) throw new Error('useSelection must be used inside <SelectionProvider>');
  return ctx;
}

function SelectionProvider({ children }: { children: ReactNode }) {
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const value = useMemo<SelectionContextValue>(
    () => ({ selectedId, select: setSelectedId }),
    [selectedId],
  );
  return <SelectionContext value={value}>{children}</SelectionContext>;
}

function UsersPage() {
  return (
    <SelectionProvider>
      <PageLayout>
        <PageHeader />
        <PageBody />
      </PageLayout>
    </SelectionProvider>
  );
}

function PageBody() {
  return (
    <>
      <Toolbar />
      <List />
    </>
  );
}

function Toolbar() {
  const { selectedId, select } = useSelection();
  if (selectedId === null) return null;
  return <button onClick={() => select(null)}>Clear selection</button>;
}

function List() {
  const { selectedId, select } = useSelection();
  return (
    <ul>
      {users.map((e) => (
        <li key={e.id} aria-selected={e.id === selectedId} onClick={() => select(e.id)}>
          {e.name}
        </li>
      ))}
    </ul>
  );
}
```

`PageLayout`, `PageBody`, `PageHeader` no longer carry selection props. Adding a third sibling (`<Stats />`) that needs selection costs nothing structurally.

## Key conventions

- **Memoize the context `value`** to avoid re-rendering all consumers on every parent render. `useMemo` keyed on the actual state values is the standard fix.
- **Split read-heavy and write-only context** when callers polarize. Keeping selection state and selection actions in one provider is fine; bundling 12 unrelated pieces of state into one context will re-render every consumer when any one changes — split into focused providers.
- **Use `use(Context)`** (React 19), not `useContext(Context)`. `use()` can be called conditionally, narrows types more cleanly, and is the forward-looking API.
- **Throw in the access hook** when context is missing. Silent defaults hide bugs.

## When NOT to apply

- **Two siblings, one shared piece of state, single parent in between** — just lift to the parent and pass props. Context is overkill for one hop.
- **Form state inside a single form** — React Hook Form, Formik, or TanStack Form already provide a form-scoped context. Don't reinvent it.
- **Server-derived data** — TanStack Query / SWR provide their own cache + invalidation, accessible from anywhere via the query key. Pulling server data into your own context layer just duplicates the cache.
- **Tree-wide constants** (theme, locale, current user) — these belong in a top-level provider, but they're not "lifted state" — they're config. Treat them like environment, not application state.

The trigger is **prop drilling through 2+ uninterested layers, or two siblings that share state**. Below that threshold, props are cheaper.
