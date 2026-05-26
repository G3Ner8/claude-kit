---
title: Load Modules Only When Activated
impact: HIGH
impactDescription: keeps feature code out of the initial bundle until the user opens the feature — sometimes the difference between a 200 KB and a 1 MB first paint
tags: bundle, lazy-loading, code-splitting, dynamic-import
---

## Load Modules Only When Activated

If a feature lives behind a flag, a tab, a modal, or an admin-only screen, its code should not ship in the initial bundle. Move it behind a dynamic `import()` so the chunk loads only when the feature opens.

This is the same mechanism as [`dynamic-imports`](./dynamic-imports.md), but applied to data/utilities/heavy libraries — not just components. Anything large that's not on the critical path is a candidate.

**Incorrect — eager import of a heavy library used only behind a tab:**

```tsx
import { generatePdf } from 'pdf-lib';   // ~600 KB, evaluated on every page load

function ReportsTab() {
  const onExport = () => {
    const blob = generatePdf(rows);
    download(blob, 'report.pdf');
  };
  return <button onClick={onExport}>Export PDF</button>;
}
```

Every visitor pays the 600 KB cost — including the 95% who never click Export.

**Correct — dynamic import inside the handler:**

```tsx
function ReportsTab() {
  const onExport = async () => {
    const { generatePdf } = await import('pdf-lib');   // chunk loads on click
    const blob = generatePdf(rows);
    download(blob, 'report.pdf');
  };
  return <button onClick={onExport}>Export PDF</button>;
}
```

The PDF library is fetched only on the first click. After that, the browser caches the chunk; subsequent clicks resolve instantly.

## When the feature has its own component tree

For a whole subtree (a settings page, an admin panel), wrap with `React.lazy` instead — that handles loading state via Suspense automatically:

```tsx
const AdminPanel = lazy(() => import('./AdminPanel'));

function App() {
  return (
    <Routes>
      <Route path="/admin/*" element={
        <Suspense fallback={<Skeleton />}>
          <AdminPanel />
        </Suspense>
      } />
    </Routes>
  );
}
```

Use `import()` for one-off heavy utilities (PDF generators, chart libraries, image processors); use `React.lazy` for whole subtrees.

## Preloading at the right moment

If the user is *about to* trigger the feature (they hovered the button), prefetch the chunk without rendering it:

```tsx
function ExportButton() {
  const onMouseEnter = () => { import('pdf-lib'); };  // start fetching; ignore result
  const onClick = async () => {
    const { generatePdf } = await import('pdf-lib');   // already in cache
    // ...
  };
  return <button onMouseEnter={onMouseEnter} onClick={onClick}>Export</button>;
}
```

This is a real ~200-300 ms win on average clicks.

## When NOT to apply

- **Small libraries (< 20 KB)** — the cost of an extra network round-trip on click can exceed the savings on first paint. Inline them.
- **Critical-path features** — anything the user sees in the first 3 seconds of a session shouldn't be lazy-loaded. The loading state itself becomes the bottleneck.
- **SSR / build-time rendering** — if your app pre-renders at build (rare in SPAs), the dynamic boundary may not split correctly. Test the production bundle.

## Verify

Run the production bundle visualizer. A correctly split feature shows up as a **separate chunk** in the output, not as part of the main bundle.

## Related

- [`dynamic-imports`](./dynamic-imports.md) — same pattern, framed for whole components.
- [`preload`](./preload.md) — preload chunks the user is likely to need next.
