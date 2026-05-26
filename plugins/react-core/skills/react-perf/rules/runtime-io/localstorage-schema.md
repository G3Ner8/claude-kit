---
title: Version Your localStorage Shapes
impact: MEDIUM
impactDescription: prevents the day a shipped change deserializes old payloads into broken state, crashing returning users
tags: runtime, localstorage, storage, schema, versioning
---

## Version Your localStorage Shapes

`localStorage` persists across sessions and across app versions. The user's browser may carry data from a build six months old. If your code reads it assuming today's shape, you'll get runtime errors on returning users — often without crash reporting picking them up (the parse failure can corrupt state silently).

The fix has two parts:

1. **Include a `version` field** in every JSON payload you write.
2. **Validate on read** — match the version, migrate or discard.

A schema validator like Zod makes step 2 mechanical.

**Incorrect — naive read/write:**

```ts
// On save
localStorage.setItem('filters', JSON.stringify(state));

// On read — assumes today's shape forever
const stored = localStorage.getItem('filters');
const filters = stored ? JSON.parse(stored) : defaultFilters;
// filters.searchTerm.trim() may throw if the old shape didn't have searchTerm
```

Three months from now you'll add `searchTerm`. Returning users will hit the `undefined.trim()` crash.

**Correct — versioned envelope + Zod validation:**

```ts
import { z } from 'zod';

const FiltersV1 = z.object({
  status: z.enum(['all', 'active', 'archived']),
  sortBy: z.enum(['name', 'created_at']),
});

const FiltersV2 = z.object({
  status:     z.enum(['all', 'active', 'archived']),
  sortBy:     z.enum(['name', 'created_at']),
  searchTerm: z.string(),
});

const Envelope = z.discriminatedUnion('version', [
  z.object({ version: z.literal(1), data: FiltersV1 }),
  z.object({ version: z.literal(2), data: FiltersV2 }),
]);

const CURRENT_VERSION = 2;
type Filters = z.infer<typeof FiltersV2>;
const DEFAULT_FILTERS: Filters = { status: 'all', sortBy: 'name', searchTerm: '' };

export function loadFilters(): Filters {
  const raw = localStorage.getItem('filters');
  if (!raw) return DEFAULT_FILTERS;

  try {
    const parsed = Envelope.parse(JSON.parse(raw));
    if (parsed.version === 2) return parsed.data;
    // Migrate v1 -> v2 by adding the new field with a default.
    return { ...parsed.data, searchTerm: '' };
  } catch {
    // Unrecognized shape — discard and start fresh.
    localStorage.removeItem('filters');
    return DEFAULT_FILTERS;
  }
}

export function saveFilters(filters: Filters) {
  localStorage.setItem(
    'filters',
    JSON.stringify({ version: CURRENT_VERSION, data: filters }),
  );
}
```

Three guarantees: known-old shapes are migrated; unknown shapes are discarded; current-shape reads are typed.

## When to bump the version

Bump on **any breaking change** to the schema:

- Removing a field
- Renaming a field
- Changing a type (`string` → `number`)
- Tightening validation (`z.string()` → `z.string().email()`)

Adding an *optional* field at the end is technically non-breaking — the migration is a no-op — but bumping anyway makes the data trail self-documenting.

## When NOT to apply

- **Truly ephemeral state** — UI scroll positions, single-session preferences. If you'd be happy clearing it on every visit, skip the envelope.
- **Server-synced state** — if the source of truth is the backend and localStorage is a cache, just `removeItem` and refetch when the shape changes. Don't migrate; sync.

## Related

- **`sessionStorage`** has the same issue but a smaller blast radius (single tab). Apply the same pattern when the data outlives a single navigation.
- **`IndexedDB`** is best wrapped with a library (Dexie, idb-keyval) that already enforces versioning. Don't roll your own.
