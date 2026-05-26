---
name: react-test-patterns
description: Reusable test patterns for React 19 SPAs running Vitest + React Testing Library + MSW (Mock Service Worker). Covers the 5-layer test pyramid (schema → API client → hook → component → integration), how to wire each layer's wrapper / mock / assertions, coverage targets per layer, TypeScript narrowing pitfalls inside MSW closures, i18n test-namespace conventions, and common anti-patterns. Use this skill before writing or reviewing vitest tests for any React feature so layer boundaries, fixtures, and confidence targets stay consistent across features.
license: MIT
user-invocable: true
metadata:
  version: "1.0.0"
  stack: React 19 + Vitest 4 + @testing-library/react 16 + @testing-library/user-event 14 + MSW 2 + jsdom
  scope: Read-mostly knowledge; consumed by test-writer agents and human reviewers
  derived_from: Proven on `pps-web/src/features/holiday/**/*.test.*` (54 tests, 8 files, 4 layers — see "Canonical baseline" below)
---

# React Test Patterns

A consolidated reference for **how to test a React feature folder** with Vitest + RTL + MSW. The pyramid is 5 layers; this doc gives you the right pattern per layer plus the gotchas that bite under jsdom.

This skill **does not write tests** — it explains the moves. Test-writing agents (e.g. `web-test`) invoke this skill, then apply.

---

## When to use

- Writing tests for a feature folder for the first time
- Reviewing a vitest test PR — check layer boundaries, fixture reuse, coverage realism
- Refactoring `src/test/` utilities (renderer, factories, MSW server)
- Deciding "should this assertion live in a component test or an integration test?"
- Onboarding a new dev to the project's test conventions

Skip this skill for:
- Non-React test setups (Node CLI, Jest, Playwright E2E)
- Pure type-system tests (those live in `*.test-d.ts` with `expectTypeOf`)

---

## The 5-layer test pyramid (in priority order)

```
       ╱ E2E ╲             out-of-scope here — covered by manual or Playwright
      ╱───────╲
     ╱  Integ. ╲           Page-level: router + MSW + full submit-to-invalidate flow
    ╱───────────╲          (opt-in, separate trigger)
   ╱  Component  ╲         UI smoke: render + interaction + error states
  ╱───────────────╲        (default: smoke; depth = caller decides)
 ╱   Hook + API   ╲        renderHook + QueryClient + MSW + module mocks
╱─────────────────╲
       Schema             zod parse / errors / transforms — pure, no DOM
       Static             tsc + ESLint — free, already wired
```

**Cost vs confidence** rises with depth. Schema tests are 50ms each, integration tests cost 1-3s — write the lowest layer that catches the bug class you care about.

---

## Stack assumptions

A feature is "testable with this skill" if the project ships with:

| Tool | Version | Purpose |
|---|---|---|
| Vitest | 4.x (jsdom env) | runner |
| @testing-library/react | 16.x | render + queries |
| @testing-library/user-event | 14.x | interactions (NOT `fireEvent`) |
| @testing-library/jest-dom | 6.x | matchers (`toBeInTheDocument` etc) |
| MSW | 2.x (`msw/node`) | network mock via `setupServer` |
| @vitest/coverage-v8 | 4.x | coverage reports |

Plus, in `src/test/`:
- `setup.ts` — registers jest-dom + MSW lifecycle (listen / resetHandlers / close) + matchMedia + ResizeObserver stubs
- `test-utils.tsx` — custom `render()` that wraps in `<I18nextProvider>` + `<QueryClientProvider>` + (optional) `<MemoryRouter>`; re-exports `@testing-library/react`
- `server.ts` — `setupServer(...rootHandlers)` for node
- `handlers/index.ts` — `rootHandlers` aggregator
- `factories/` — fixture builders (`buildXxx(overrides)`)

If any are missing, write them once for the project — the rest of this skill assumes they exist.

---

## Canonical baseline

Read these files **in full** before writing tests for a new feature in pps-web — they prove every pattern in this skill end-to-end:

| Layer | File |
|---|---|
| Schema | `pps-web/src/features/holiday/schemas/holiday.schema.test.ts` |
| Schema (with optional / transform) | `pps-web/src/features/holiday/schemas/holidayCalendar.schema.test.ts` |
| API client + case-transform round-trip | `pps-web/src/features/holiday/api/index.test.ts` |
| Query hook (single fetch + disabled gates) | `pps-web/src/features/holiday/hooks/useHolidayCalendar.test.tsx` |
| Query hook (list with params) | `pps-web/src/features/holiday/hooks/useHolidayCalendars.test.tsx` |
| System query (no companyId scope) | `pps-web/src/features/holiday/hooks/useSystemHolidayCalendars.test.tsx` |
| Mutation hooks (invalidation patterns) | `pps-web/src/features/holiday/hooks/useHolidayMutations.test.tsx` |
| Component smoke (drawer + RHF + Radix) | `pps-web/src/features/holiday/components/sections/HolidayDrawer.test.tsx` |

If you're using this skill outside pps-web, replace these paths with the equivalent canonical files in your project.

---

## Layer 1 — Schema tests (zod factories)

**File**: `<feature>/schemas/<entity>.schema.test.ts`
**Tools**: vitest only — no DOM, no MSW, no providers.

Schemas in this project are **factory functions** that take an `i18next` `TFunction`:

```ts
export const createFooSchema = (t: TFunction) => z.object({ ... })
```

In tests, pass an identity stub so error messages are i18n **keys** you can assert against:

```ts
import type { TFunction } from 'i18next'
import { describe, expect, it } from 'vitest'
import { createFooSchema } from './foo.schema'

const t = ((key: string) => key) as unknown as TFunction
const schema = createFooSchema(t)

it('rejects empty required field', () => {
  const result = schema.safeParse({ ...validInput, name: '' })
  expect(result.success).toBe(false)
  if (!result.success) {
    expect(result.error.issues[0]?.message).toBe('foo.form.name.required')
  }
})
```

**What to test**:
- ✅ required field empty / whitespace-only (trim policy)
- ✅ max length exactly at boundary AND just over
- ✅ enum members (`it.each(VALID_VALUES)`) + one rejected non-member
- ✅ optional fields absent / empty string transform
- ✅ type coercion edge cases (string-as-number, decimal as int, etc.)

**Coverage target**: **100% lines, 100% branches**. Schemas are pure and small — there's no excuse.

**Anti-patterns**:
- ❌ Snapshot-testing the schema object — opaque, brittle
- ❌ Re-using one giant `valid` object across all tests — masks field-specific bugs

---

## Layer 2 — API client tests (MSW intercept)

**File**: `<feature>/api/index.test.ts`
**Tools**: vitest + MSW (NOT mocked axios).

Mock the **network**, not the module. Axios interceptors (auth header, case-transform, token refresh) MUST run end-to-end — mocking `@/services/api` bypasses them and you'll ship broken contract handling.

```ts
import { server } from '@/test/server'
import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { fooApi } from './index'

describe('fooApi (MSW + case-transform)', () => {
  it('GETs /pps/v1/foo and unwraps data envelope', async () => {
    server.use(
      http.get('*/pps/v1/foo', () =>
        HttpResponse.json({ data: { foo_id: 'f1', display_name: 'A' } })
      )
    )

    const result = await fooApi.get()

    // Wire was snake_case; FE sees camelCase via interceptor.
    expect(result).toMatchObject({ fooId: 'f1', displayName: 'A' })
  })
})
```

**What to test**:
- ✅ Each method (list / get / create / update / delete / custom)
- ✅ Path + method + query-string forwarding (snake_case on wire)
- ✅ Request body conversion (FE camelCase → wire snake_case) — capture body in handler
- ✅ Response unwrap (`response.data.data`) + case conversion both directions
- ✅ Status codes that the client handles specially (204, 201 vs 200)

**Coverage target**: **90%+ lines**. Skip only error branches the client doesn't handle (`response.data.errors` mapping etc.) — those usually live in a separate util.

**TypeScript pitfall — MSW closure narrowing**: TS 5.x doesn't track `let foo: T | null = null` assignments inside MSW handler callbacks → reads after `await` get narrowed to `never`. Use a **holder object** instead:

```ts
// ❌ TS narrows captured.search to `never` after the await
let capturedSearch: URLSearchParams | null = null
server.use(
  http.get('*/pps/v1/foo', ({ request }) => {
    capturedSearch = new URL(request.url).searchParams
    return HttpResponse.json({ data: {} })
  })
)
await fooApi.list({ year: 2026 })
expect(capturedSearch?.get('year')).toBe('2026')   // TS error

// ✅ Holder object preserves the union type across closure
const captured: { search: URLSearchParams | null } = { search: null }
server.use(
  http.get('*/pps/v1/foo', ({ request }) => {
    captured.search = new URL(request.url).searchParams
    return HttpResponse.json({ data: {} })
  })
)
await fooApi.list({ year: 2026 })
expect(captured.search?.get('year')).toBe('2026')   // ✓
```

**Anti-patterns**:
- ❌ `vi.mock('@/services/api', () => ({ ... }))` — bypasses real interceptor pipeline
- ❌ Asserting on `axios.get` call args — too coupled, doesn't survive a fetch swap
- ❌ Forgetting `onUnhandledRequest: 'error'` in `server.listen()` — typos in URLs go silent

---

## Layer 3 — Hook tests (renderHook + QueryClient + MSW)

**File**: `<feature>/hooks/use<Thing>.test.tsx` (tsx because of `<QueryClientProvider>` wrapper)
**Tools**: vitest + `renderHook` from RTL + MSW + module mock for `useCurrentCompanyId` (or equivalent tenant accessor)

Hooks have two failure modes that integration tests catch poorly:
1. **Enable-gate** — query never fires when prerequisite is missing
2. **Cache invalidation** — mutation succeeds but list/detail don't refetch

Both are testable in isolation with `renderHook`:

```tsx
import { server } from '@/test/server'
import { createTestQueryClient } from '@/test/test-utils'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { renderHook, waitFor } from '@testing-library/react'
import { HttpResponse, http } from 'msw'
import type { ReactNode } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('@/hooks/useCurrentCompanyId', () => ({
  useCurrentCompanyId: vi.fn(() => 'company-1'),
}))

import { useCurrentCompanyId } from '@/hooks/useCurrentCompanyId'
import { useFoo } from './useFoo'

function wrapperFactory(client: QueryClient) {
  return function Wrapper({ children }: { children: ReactNode }) {
    return <QueryClientProvider client={client}>{children}</QueryClientProvider>
  }
}

let client: QueryClient
beforeEach(() => {
  vi.mocked(useCurrentCompanyId).mockReturnValue('company-1')
  client = createTestQueryClient()
})
afterEach(() => client.clear())

it('is disabled when companyId is missing', () => {
  vi.mocked(useCurrentCompanyId).mockReturnValue(undefined)
  let hit = false
  server.use(http.get('*/pps/v1/foo', () => { hit = true; return HttpResponse.json({}) }))

  const { result } = renderHook(() => useFoo(), { wrapper: wrapperFactory(client) })

  expect(result.current.fetchStatus).toBe('idle')
  expect(hit).toBe(false)
})

it('fetches and camelCases response when companyId is set', async () => {
  server.use(
    http.get('*/pps/v1/foo', () =>
      HttpResponse.json({ data: { foo_id: 'f1' } })
    )
  )

  const { result } = renderHook(() => useFoo(), { wrapper: wrapperFactory(client) })

  await waitFor(() => expect(result.current.isSuccess).toBe(true))
  expect(result.current.data).toMatchObject({ fooId: 'f1' })
})
```

For **mutations**, spy on `client.invalidateQueries` to verify the right keys are touched on success — and **not** touched on error / when companyId is missing:

```tsx
it('invalidates list on create success', async () => {
  server.use(http.post('*/pps/v1/foo', () => HttpResponse.json({ data: {} }, { status: 201 })))
  const spy = vi.spyOn(client, 'invalidateQueries')

  const { result } = renderHook(() => useCreateFoo(), { wrapper: wrapperFactory(client) })
  result.current.mutate({ name: 'X' })
  await waitFor(() => expect(result.current.isSuccess).toBe(true))

  expect(spy).toHaveBeenCalledWith({ queryKey: fooKeys.lists('company-1') })
})

it('does NOT invalidate on server error', async () => {
  server.use(http.post('*/pps/v1/foo', () => HttpResponse.json({}, { status: 500 })))
  const spy = vi.spyOn(client, 'invalidateQueries')

  const { result } = renderHook(() => useCreateFoo(), { wrapper: wrapperFactory(client) })
  result.current.mutate({ name: 'X' })
  await waitFor(() => expect(result.current.isError).toBe(true))

  expect(spy).not.toHaveBeenCalled()
})
```

**What to test**:
- ✅ Enable-gate(s) — `companyId`, `id` param, `enabled` flag explicit false
- ✅ Successful fetch + camelCase shape
- ✅ Param forwarding (capture URL.searchParams via MSW)
- ✅ For mutations: invalidate-correct-keys on success
- ✅ For mutations: do-not-invalidate on error / missing prerequisite
- ✅ `removeQueries` for delete mutations (detail cache eviction)

**Coverage target**: **80%+ lines**. Mutations carry the highest cache-invalidation risk → prioritize.

**Anti-patterns**:
- ❌ Asserting on `result.current.data` synchronously — use `waitFor(isSuccess)`
- ❌ Sharing one QueryClient across tests — leaked cache → flaky tests
- ❌ Mocking `useQuery` itself — defeats the cache logic you're trying to verify

---

## Layer 4 — Component tests (smoke)

**File**: `<feature>/components/<group>/<Name>.test.tsx`
**Tools**: vitest + custom `render` (i18n + QueryClient + optional router) + `userEvent` + MSW where applicable

Default scope = **smoke**: the component renders its title, gates submit on validation, prefills in edit mode, disables Cancel while saving. **Don't** chase Radix portal interactions (DatePicker, Select, Combobox) in component-level jsdom — they're flaky and the assertions don't transfer to Cypress/Playwright.

```tsx
import { render, screen, waitFor } from '@/test/test-utils'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { FooDrawer } from './FooDrawer'

const baseProps = { open: true, isSaving: false, onClose: vi.fn(), onSubmit: vi.fn() }

describe('FooDrawer — create mode', () => {
  it('renders the create title', () => {
    render(<FooDrawer {...baseProps} />)
    expect(screen.getByRole('heading', { name: 'Add foo' })).toBeInTheDocument()
  })

  it('does NOT call onSubmit when validation fails', async () => {
    const onSubmit = vi.fn()
    const user = userEvent.setup()
    render(<FooDrawer {...baseProps} onSubmit={onSubmit} />)

    await user.click(screen.getByRole('button', { name: /Save/i }))

    expect(onSubmit).not.toHaveBeenCalled()
    await waitFor(() => {
      expect(screen.getAllByText(/required/i).length).toBeGreaterThan(0)
    })
  })

  it('calls onClose when Cancel is clicked', async () => {
    const onClose = vi.fn()
    const user = userEvent.setup()
    render(<FooDrawer {...baseProps} onClose={onClose} />)

    await user.click(screen.getByRole('button', { name: 'Cancel' }))
    expect(onClose).toHaveBeenCalledTimes(1)
  })
})
```

**What to test (smoke set)**:
- ✅ Mode-appropriate title renders (create vs edit)
- ✅ Edit mode prefills text inputs
- ✅ Submit button gated on validation (does NOT call submit on empty)
- ✅ Cancel button calls `onClose`
- ✅ `isSaving=true` → Cancel disabled, loading label shown
- ✅ Dirty-state gating (Save disabled while pristine in edit mode)

**Coverage target**: **60-70% lines**. Lower than other layers because Radix portal branches are unreachable in jsdom.

**i18n namespace**: Components use `useTranslation('<feature>')` — the test must have the namespace strings loaded in `src/test/test-utils.tsx`. **Append, never replace** existing namespaces. Use the key paths that exist in `<feature>.json` — don't invent labels.

**Selector hierarchy** (in order):
1. 🥇 `getByRole('button', { name: 'Save' })`
2. 🥈 `getByLabelText(/Name/i)` (works because `<Field>` auto-pairs `htmlFor` via `useId`)
3. 🥉 `getByTestId('...')` — only for row disambiguation; production strips `data-testid`

**Anti-patterns**:
- ❌ `fireEvent.click(...)` — use `userEvent.click(...)` (Radix-safe focus + event order)
- ❌ Asserting on Radix `<Select>` value after `user.click(SelectItem)` — portal flake
- ❌ Snapshot of full DOM — brittle on Radix internals
- ❌ Hardcoded `await new Promise(r => setTimeout(r, 500))` — use `findBy*` or `waitFor`
- ❌ Reaching into form internals (`form.formState.errors.x`) — test the rendered UI

---

## Layer 5 — Integration tests (opt-in)

**File**: `<feature>/pages/<EntityRolePage>/index.test.tsx`
**Tools**: vitest + custom `render` with `route:` + MSW + `userEvent`

Integration mode is **opt-in** — caller explicitly asks for it. Default features get smoke tests only.

Use integration tests for **one** thing: a full flow that touches MSW endpoints, query invalidation, and UI state in sequence. Example: "list page → click row → drawer opens → edit → submit → drawer closes → list refetches".

```tsx
import { render, screen, within } from '@/test/test-utils'
import userEvent from '@testing-library/user-event'
import { HttpResponse, http } from 'msw'
import { server } from '@/test/server'
import { FooListPage } from './index'

it('creates a foo and re-renders the list', async () => {
  // Initial empty list, then one item after POST.
  const items = [{ foo_id: 'f1', name: 'Existing' }]
  server.use(
    http.get('*/pps/v1/foo', () =>
      HttpResponse.json({ data: { content: items, total_elements: items.length } })
    ),
    http.post('*/pps/v1/foo', async ({ request }) => {
      const body = (await request.json()) as { name: string }
      items.push({ foo_id: 'f2', name: body.name })
      return HttpResponse.json({ data: items[items.length - 1] }, { status: 201 })
    })
  )

  render(<FooListPage />, { route: '/foo' })

  // initial list rendered
  expect(await screen.findByText('Existing')).toBeInTheDocument()

  // open create drawer
  await userEvent.setup().click(screen.getByRole('button', { name: /Add/i }))
  const drawer = screen.getByRole('dialog')
  await userEvent.setup().type(within(drawer).getByLabelText(/Name/i), 'New foo')
  await userEvent.setup().click(within(drawer).getByRole('button', { name: /Add foo/i }))

  // list refetched and shows new row
  expect(await screen.findByText('New foo')).toBeInTheDocument()
})
```

**Scope guardrails**:
- 1-3 flows per page max — pick the highest-business-risk path
- Each flow asserts on **observable state** (DOM + network call), not implementation (RHF internals, query cache shape)
- Use real MSW handlers shared with hook/component tests where possible

**Coverage target**: not a target. Integration tests are a confidence multiplier, not a coverage tool.

---

## Coverage targets — summary

| Layer | Statements | Branches | Functions | Notes |
|---|---|---|---|---|
| Schema | 100% | 100% | 100% | Pure, small, no excuse |
| API client | 90%+ | — | 90%+ | Each method × happy path |
| Query keys | 100% | 100% | 100% | Trivial, just stable-key assertion |
| Hooks | 80%+ | 50%+ | 100% | Branches lower because companyId-missing branches are skipped on happy path |
| Components | 60-70% | — | — | Radix portal branches unreachable in jsdom |
| Pages (smoke) | not measured | — | — | Integration is the confidence, not coverage |

Configure threshold in `vite.config.ts` → `test.coverage.thresholds` **only after** the suite has crossed each target for 2+ features. Premature thresholds = noise.

---

## i18n test namespace conventions

`src/test/test-utils.tsx` ships a synchronous `i18next` instance with hardcoded namespaces. When testing a component that uses `useTranslation('foo')`:

1. **Check first**: is `foo` namespace already in `resources.en.foo.foo.*`?
2. **If absent**: append it under `resources.en` — never replace another namespace
3. **Mirror JSON structure**: outer key = namespace, inner mirrors the locale file (`foo.json` → `foo: { foo: { ... } }`)
4. **Add only keys the test asserts on** — not the whole JSON file (keeps file scannable)
5. **Use real key paths** — copy from `src/i18n/locales/en/<feature>.json`, don't invent

For string assertions that need interpolation (`{{name}}`), use the same template strings as production:

```tsx
foo: {
  foo: {
    delete: {
      title: 'Delete "{{name}}"?',
    },
  },
}
```

`t('foo.delete.title', { name: 'X' })` then resolves to `'Delete "X"?'`.

---

## Anti-patterns (recap)

| Anti-pattern | Why it's bad | Fix |
|---|---|---|
| `vi.mock('@/services/api')` | Bypasses interceptors + case-transform | Use MSW |
| `fireEvent.*` for interactions | No focus/blur fidelity, breaks Radix | `userEvent.setup()` |
| Snapshot the full DOM | Brittle on Radix internals | `getByRole` + targeted assertions |
| One QueryClient shared across tests | Cache leak → flaky | `createTestQueryClient()` per render |
| `.only` / `.skip` left in code | Half-disabled suites pretend to pass | grep before commit |
| `await new Promise(r => setTimeout(r, 500))` | Slow + flaky | `findBy*` or `waitFor` |
| Asserting on `result.current.data` synchronously | Race with query refetch | `await waitFor(isSuccess)` |
| Mocking `useQuery` directly | Tests the mock, not the cache | Wrap in QueryClient + MSW |
| `getByTestId` first | Bypasses a11y safety net | Role → Label → TestId order |
| Component test that opens Radix Select | Portal flake under jsdom | Move to integration or stub the Select |
| Coverage threshold set too early | Blocks PRs without signal | Wait until 2+ features hit target |

---

## Quick reference — when to test where

| Bug class | Catch at layer |
|---|---|
| Wrong validation message | Schema |
| Wrong API path / method / payload shape | API client |
| Query doesn't refetch after mutation | Hook (mutation) |
| Query fires before tenant ready | Hook (enable gate) |
| Form submits with empty required field | Component (smoke) |
| Save button stays enabled on pristine form | Component (smoke) |
| List doesn't refresh after creating from drawer | Integration |
| Detail page opens on row click | Integration |
| Toast appears on mutation error | Component or integration (depends where toast lives) |
| Visual regression | None of these — use screenshot/manual |

---

## Output expectations (for agent consumers)

If an agent invokes this skill, it should produce:

1. A **layered plan** — list of test files to write/expand, grouped by the 5 layers above
2. **Coverage delta** projection — current % vs target per layer
3. **i18n keys delta** — new keys to add to `test-utils.tsx` (none if namespace already exists)
4. **Risk callouts** — Radix primitives in scope (move to integration?), missing tenant accessor mock, etc.

The agent applies in **pure → impure** order (schemas first, integration last) so a failure in low layers blocks before expensive layers run.
