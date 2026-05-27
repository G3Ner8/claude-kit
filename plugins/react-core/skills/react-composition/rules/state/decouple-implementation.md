---
title: Decouple Implementation from Interface
impact: MEDIUM
impactDescription: the provider is the only place that knows how state is sourced — swap useState for a server cache, store, or sync engine without touching consumers
tags: composition, state, abstraction, dependency-injection
---

## Decouple Implementation from Interface

Given a [stable context interface](./context-interface.md), the implementation that backs it should be the only thing that knows where state comes from. The UI binds to `{ state, actions, meta }` — never to `useState`, `useReducer`, `useQuery`, a Zustand store, or a WebSocket. Anything past the provider is implementation detail.

When the contract holds, you can:

- Replace `useState` with `useReducer` when the state machine grows
- Add a server cache (TanStack Query) without touching consumers
- Swap a local mock provider into tests
- Move state from local to remote (or vice versa) when the product evolves

When the contract leaks, every implementation change ripples to the consumers.

**Incorrect — provider that leaks its implementation:**

```tsx
function UsersProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient();                          // leaks: caller knows TanStack
  const { data, isLoading, refetch } = useQuery({ ... });        // leaks: caller knows useQuery
  const [selectedId, setSelectedId] = useState<string | null>(null); // leaks: caller knows useState

  return (
    <UsersContext value={{
      data,                  // raw `data` (may be undefined!) instead of a safe `users: []`
      isLoading,             // wired straight through; no derived meta
      refetch,               // exposes the TanStack-specific API name
      selectedId,
      setSelectedId,         // raw setter — caller can replace selection with garbage
      queryClient,           // gives consumers cache-mutation powers they should not have
    }}>
      {children}
    </UsersContext>
  );
}
```

Any caller can `setSelectedId('not-an-id')` or `queryClient.setQueryData(...)`. Moving off TanStack Query is a multi-file rewrite.

**Correct — provider hides its source, exposes only the stable contract:**

```tsx
function UsersProvider({ children }: { children: ReactNode }) {
  // Implementation: TanStack Query for data, useState for selection.
  // Nothing past this function knows.
  const query = useQuery({ queryKey: ['users'], queryFn: fetchUsers });
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const users = query.data ?? [];                       // safe default — never undefined
  const selectedUser = useMemo(
    () => users.find((e) => e.id === selectedId) ?? null,
    [users, selectedId],
  );

  const value = useMemo<UsersContextValue>(
    () => ({
      state:   { users, selectedUser },
      actions: {
        // Wrapped so the public name is the action verb, not the library noun.
        select:  setSelectedId,
        refresh: async () => { await query.refetch(); },
      },
      meta: {
        isLoading: query.isLoading,
        isError:   query.isError,
        isEmpty:   !query.isLoading && users.length === 0,
      },
    }),
    [users, selectedUser, query.isLoading, query.isError, query.refetch],
  );

  return <UsersContext value={value}>{children}</UsersContext>;
}
```

Now consider swapping TanStack Query for a Zustand store — the provider is the only file that changes:

```tsx
function UsersProvider({ children }: { children: ReactNode }) {
  const users      = useUsersStore((s) => s.users);
  const isLoading      = useUsersStore((s) => s.isLoading);
  const isError        = useUsersStore((s) => s.isError);
  const refresh        = useUsersStore((s) => s.refresh);
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const selectedUser = useMemo(
    () => users.find((e) => e.id === selectedId) ?? null,
    [users, selectedId],
  );

  const value = useMemo<UsersContextValue>(
    () => ({
      state:   { users, selectedUser },
      actions: { select: setSelectedId, refresh },
      meta:    { isLoading, isError, isEmpty: !isLoading && users.length === 0 },
    }),
    [users, selectedUser, isLoading, isError, refresh],
  );

  return <UsersContext value={value}>{children}</UsersContext>;
}
```

Zero consumer changes. The compiler doesn't even notice.

## Test seam for free

A decoupled provider also gives you a clean test seam. Wrap units in a deterministic provider:

```tsx
function TestUsersProvider({ users, children }: { users: User[]; children: ReactNode }) {
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const value: UsersContextValue = {
    state:   { users, selectedUser: users.find((e) => e.id === selectedId) ?? null },
    actions: { select: setSelectedId, refresh: async () => {} },
    meta:    { isLoading: false, isError: false, isEmpty: users.length === 0 },
  };
  return <UsersContext value={value}>{children}</UsersContext>;
}

// In tests:
render(
  <TestUsersProvider users={fixture.users}>
    <UsersList />
  </TestUsersProvider>,
);
```

No TanStack Query setup, no MSW intercept, no store reset — the contract is enough.

## Key conventions

- **Wrap library-specific action names** (`refetch`, `mutate`, `invalidate`) behind verbs from your domain (`refresh`, `save`, `archive`). The action name is part of the public contract.
- **Never expose raw setters** through the context value. If the caller needs to write, expose an action — `actions.select(id)` — that validates or massages input.
- **Default empty collections to `[]`, never `undefined`.** Consumers should not have to handle `query.data === undefined` separately from `query.data === []`.
- **Keep one provider per feature.** Stacking providers is fine; merging them into a "global" provider breaks the decoupling because every change to the global file ripples everywhere.

## When NOT to apply

- **Trivial state with no foreseeable swap.** A `useToggle()` hook backing `{ open, toggle }` doesn't need `{ state, actions, meta }` framing.
- **Library-provided contexts** (Router, QueryClient, Suspense boundary). These are already stable interfaces from a third-party — don't rewrap them just to mirror your own convention.
- **Components, not features.** The pattern targets feature-scope state (user list, order wizard, invoice calendar). Component-internal state (a dropdown's open/close) belongs in `useState` inside the component.

The trigger is **a feature whose data source might plausibly change** (local → server, mocked → real, useState → reducer, polling → streaming). At that point, the contract discipline pays its premium.
