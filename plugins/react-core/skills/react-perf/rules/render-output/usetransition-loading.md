---
title: Use useTransition Over Manual Loading States
impact: LOW
impactDescription: reduces re-renders and improves code clarity for non-urgent updates
tags: rendering, transitions, useTransition, loading, state
---

## Use useTransition Over Manual Loading States

For non-urgent state updates (search results, filter changes, tab switches), `useTransition` is a drop-in replacement for manual `isLoading` flags. It gives you a built-in `isPending` flag, automatically resets it on error, and lets React interrupt the transition if the user types again before the previous one finishes.

**Incorrect (manual loading state):**

```tsx
function SearchResults() {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<Result[]>([])
  const [isLoading, setIsLoading] = useState(false)

  const handleSearch = async (value: string) => {
    setIsLoading(true)
    setQuery(value)
    const data = await fetchResults(value)
    setResults(data)
    setIsLoading(false)
  }

  return (
    <>
      <input onChange={(e) => handleSearch(e.target.value)} />
      {isLoading && <Spinner />}
      <ResultsList results={results} />
    </>
  )
}
```

Problems with this: if `fetchResults` throws, `setIsLoading(false)` never runs. If the user types fast, you accumulate stale fetches and the latest one might not be the one that lands.

**Correct (useTransition with built-in pending state):**

```tsx
import { useTransition, useState } from 'react'

function SearchResults() {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<Result[]>([])
  const [isPending, startTransition] = useTransition()

  const handleSearch = (value: string) => {
    setQuery(value) // Update input immediately (urgent)

    startTransition(async () => {
      // Non-urgent: React can interrupt this if the user types again
      const data = await fetchResults(value)
      setResults(data)
    })
  }

  return (
    <>
      <input onChange={(e) => handleSearch(e.target.value)} />
      {isPending && <Spinner />}
      <ResultsList results={results} />
    </>
  )
}
```

**Benefits:**

- **Automatic pending state** — no manual `setIsLoading(true/false)`
- **Error resilience** — `isPending` correctly resets even if the transition throws
- **Interrupt handling** — if the user kicks off a new transition, the previous one yields
- **Concurrent rendering** — React can pause the transition to keep input typing responsive

If you specifically need to keep showing the *previous* results while the new ones load (instead of a spinner), use `useDeferredValue` instead — see [Use Deferred Value](../rerender/use-deferred-value.md).

Reference: [useTransition](https://react.dev/reference/react/useTransition)
