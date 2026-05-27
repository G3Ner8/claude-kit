---
title: React.lazy + Suspense for Heavy Components
impact: HIGH
impactDescription: route-level or modal-level code splitting can shrink the main bundle by 30-70% with no UX cost
tags: bundle, lazy, suspense, code-splitting, react
---

## `React.lazy` + Suspense for Heavy Components

When a component (or a whole subtree) isn't needed on first paint, wrap it in `React.lazy`. The bundler emits the subtree as a separate chunk; the chunk loads only when the component is about to render.

The pattern requires three pieces:

1. `lazy(() => import('./Component'))` — the dynamic boundary.
2. A `<Suspense fallback={...}>` somewhere above it — to show during the chunk fetch.
3. **Default export** in the lazy-loaded module — `React.lazy` only works on default exports.

The two best places to split: **routes** (every route is a separate chunk) and **modals/dialogs** (loaded on open, never on initial render).

**Incorrect — heavy admin panel imported eagerly:**

```tsx
import AdminPanel from './pages/AdminPanel';  // 200 KB, 99% of visitors never see it

function App() {
  return (
    <Routes>
      <Route path="/" element={<Home />} />
      <Route path="/admin/*" element={<AdminPanel />} />
    </Routes>
  );
}
```

Every visitor pays the 200 KB cost even on the home page.

**Correct — `React.lazy` per route:**

```tsx
import { lazy, Suspense } from 'react';

const Home       = lazy(() => import('./pages/Home'));
const AdminPanel = lazy(() => import('./pages/AdminPanel'));

function App() {
  return (
    <Suspense fallback={<PageSkeleton />}>
      <Routes>
        <Route path="/"        element={<Home />} />
        <Route path="/admin/*" element={<AdminPanel />} />
      </Routes>
    </Suspense>
  );
}
```

Visiting `/` loads only the Home chunk. Visiting `/admin` loads the admin chunk on demand.

## Modal-level splitting

Modals are usually heavy (forms, calendars, rich text) and almost never opened. Lazy-load them:

```tsx
const UserFormDialog = lazy(() => import('./UserFormDialog'));

function UserList() {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button onClick={() => setOpen(true)}>Add user</button>
      {open && (
        <Suspense fallback={<DialogSkeleton />}>
          <UserFormDialog onClose={() => setOpen(false)} />
        </Suspense>
      )}
    </>
  );
}
```

The dialog chunk doesn't even appear in the network tab until the user clicks Add.

## Naming chunks for analyzer clarity

Bundlers sometimes name lazy chunks generically (`chunk-1.js`, `chunk-2.js`). For a readable bundle analyzer output:

```ts
const AdminPanel = lazy(() =>
  import(/* webpackChunkName: "admin-panel" */ './pages/AdminPanel')
);
```

Vite respects the `webpackChunkName` magic comment; Rollup honors `manualChunks` config.

## When NOT to apply

- **Above-the-fold components** — putting your hero or initial layout behind `lazy` shows a skeleton for the first paint. That's worse, not better.
- **Tiny components** — splitting a 5 KB component creates an extra HTTP round-trip to save 5 KB. Net loss.
- **Components that always render together** — splitting `<HeaderLogo>` from `<HeaderNav>` makes the analyzer noisier without saving any bytes.

## Verify

Bundle analyzer: each `lazy()` boundary should produce its own chunk file. Network tab on a real navigation: the new route's chunk should arrive on click, not on initial load.

## Related

- [`conditional-load`](./conditional-load.md) — same pattern for non-component code (PDF generators, image processors).
- [`preload`](./preload.md) — when you can predict which lazy chunk the user will need next, preload it.
