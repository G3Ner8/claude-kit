---
title: Stable Context Interface
impact: HIGH
impactDescription: defines a single, swap-friendly contract — `{ state, actions, meta }` — so the UI binds to behavior, not to a specific implementation
tags: composition, state, context, contract, dependency-injection
---

## Stable Context Interface

When a provider exposes state to descendants, the **shape of the context value is a public contract**. Descendants depend on it; you can't change it without rippling. Pick a stable shape on day one.

The shape that scales across feature domains is:

```ts
interface FeatureContext {
  state:   /* derived data the UI reads */;
  actions: /* functions the UI calls */;
  meta?:   /* derivable status — isLoading, isError, hasUnsavedChanges, etc. */;
}
```

Three properties, always present. Three reasons it works:

1. **The UI never reaches into provider internals.** It calls `actions.select(id)`, not `setSelectedId(id)`. The provider can rename, refactor, or swap implementations without touching consumers.
2. **`state` is read-only from the UI's perspective.** No `setX` setters leaking through — actions are the only mutation surface. This kills "consumer mutates state directly" bugs.
3. **`meta` carries derived flags** — `isLoading`, `isError`, `isReady`, `isDirty` — so consumers don't recompute them. Derive once, in the provider.

**Incorrect — exposing implementation details:**

```tsx
interface UsersContextValue {
  users: User[];
  setUsers: Dispatch<SetStateAction<User[]>>;  // consumer can replace the whole array
  selectedId: string | null;
  setSelectedId: Dispatch<SetStateAction<string | null>>;
  isLoading: boolean;
  setIsLoading: Dispatch<SetStateAction<boolean>>;
  searchTerm: string;
  setSearchTerm: Dispatch<SetStateAction<string>>;
}
```

Consumers can break invariants (`setIsLoading(true)` without actually loading). Refactoring `useState` → `useReducer` is a breaking change. The shape leaks every internal.

**Correct — stable `{ state, actions, meta }`:**

```tsx
interface UsersContextValue {
  state: {
    users: User[];
    selectedUser: User | null;
    searchTerm: string;
  };
  actions: {
    select: (id: string | null) => void;
    search: (term: string) => void;
    refresh: () => Promise<void>;
  };
  meta: {
    isLoading: boolean;
    isError: boolean;
    isEmpty: boolean;          // derived: !isLoading && users.length === 0
    isFiltered: boolean;       // derived: searchTerm.length > 0
  };
}

const UsersContext = createContext<UsersContextValue | null>(null);

function useUsers() {
  const ctx = use(UsersContext);
  if (!ctx) throw new Error('useUsers must be used inside <UsersProvider>');
  return ctx;
}

function UsersProvider({ children }: { children: ReactNode }) {
  const query = useQuery({ queryKey: ['users'], queryFn: fetchUsers });
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');

  const users = useMemo(
    () => filterBy(query.data ?? [], searchTerm),
    [query.data, searchTerm],
  );
  const selectedUser = useMemo(
    () => users.find((e) => e.id === selectedId) ?? null,
    [users, selectedId],
  );

  const value = useMemo<UsersContextValue>(
    () => ({
      state:   { users, selectedUser, searchTerm },
      actions: { select: setSelectedId, search: setSearchTerm, refresh: query.refetch },
      meta:    {
        isLoading:  query.isLoading,
        isError:    query.isError,
        isEmpty:    !query.isLoading && users.length === 0,
        isFiltered: searchTerm.length > 0,
      },
    }),
    [users, selectedUser, searchTerm, query.isLoading, query.isError, query.refetch],
  );

  return <UsersContext value={value}>{children}</UsersContext>;
}
```

A consumer:

```tsx
function UsersList() {
  const { state, actions, meta } = useUsers();
  if (meta.isLoading) return <Skeleton />;
  if (meta.isError)   return <ErrorState onRetry={actions.refresh} />;
  if (meta.isEmpty)   return <EmptyState filtered={meta.isFiltered} />;
  return (
    <ul>
      {state.users.map((e) => (
        <li key={e.id} onClick={() => actions.select(e.id)}>{e.name}</li>
      ))}
    </ul>
  );
}
```

The consumer has no idea whether the provider uses `useState`, `useReducer`, Zustand, Jotai, or a server-sync layer. Swapping any of those changes one file — the provider — not the consumers.

## Key conventions

- **Lock the shape early.** Once `{ state, actions, meta }` is published, additions are additive (new field in one of the three buckets); removals or renames are breaking.
- **Actions return `void` or `Promise<void>`.** Don't leak the underlying mutation result through the action signature. If the UI needs feedback ("save succeeded"), expose it through `meta` or via a separate signal.
- **Derive `meta`, don't store it.** `isEmpty` should be a computed value, not a separate piece of state that the action layer has to keep in sync.
- **Memoize the value object.** Without memoization, every parent render re-renders every consumer regardless of whether state changed.

## When NOT to apply

- **Trivial contexts** — a theme provider exposing `{ theme: 'light' | 'dark', toggle: () => void }` doesn't need three buckets. The pattern earns its overhead when there are 3+ state pieces, 3+ actions, or any meta-derivation logic.
- **Library boundaries** — TanStack Query's `useQuery()` return shape is already stable; don't wrap it in another `{ state, actions, meta }` just for symmetry.

The trigger is **a provider that exposes more than ~3 things and has consumers in more than one feature folder**. At that scope, the contract discipline pays back within the first refactor.
