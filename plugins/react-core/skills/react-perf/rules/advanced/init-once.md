---
title: Initialize App Singletons Exactly Once Across StrictMode
impact: LOW-MEDIUM
impactDescription: StrictMode double-invokes effects in development — naive initialization runs twice; idempotent guards prevent duplicate listeners, sockets, or analytics calls
tags: advanced, strictmode, init, singleton, idempotent
---

## Initialize App Singletons Exactly Once Across StrictMode

In development, React 18+ StrictMode intentionally mounts each component **twice** to surface bugs caused by non-idempotent setup. Effects fire twice; cleanup fires once in between.

For most effects (event listeners, subscriptions), this is healthy: the cleanup runs, the second mount re-attaches, and double-mounting flushes out missing cleanup paths.

But for **singletons** — analytics SDKs, WebSocket connections, third-party libraries with global state — the second initialization can be harmful: duplicate `gtag('config', ...)` calls, two WebSocket connections to the same room, two `init()` calls to a library that doesn't tolerate it.

The fix is to make initialization explicitly idempotent: track that init has happened, skip the second call.

**Incorrect — naive init runs twice in dev:**

```tsx
useEffect(() => {
  gtag('config', 'GA_MEASUREMENT_ID');   // runs twice in StrictMode
}, []);
```

In dev, two `config` calls. In prod, one. The difference itself is a smell — the dev signal is what catches the real prod bug (e.g., when a future change makes this an `<App>` re-mount).

**Correct — module-level singleton guard:**

```ts
// analytics.ts
let initialized = false;

export function initAnalytics() {
  if (initialized) return;
  initialized = true;
  gtag('config', 'GA_MEASUREMENT_ID');
}
```

```tsx
useEffect(() => {
  initAnalytics();   // safe to call multiple times
}, []);
```

The guard runs on the first call; subsequent calls (including StrictMode's second invocation, or any future caller) become no-ops.

## When the resource has a teardown

Some singletons should actually tear down (close WebSocket, unsubscribe from feature flags). For those, you don't want a one-shot init; you want correct cleanup:

```tsx
useEffect(() => {
  const socket = openSocket();
  return () => socket.close();
}, []);
```

StrictMode runs this twice: open, close, open. The pair of open/close happens — that's a feature, not a bug, because it proves your cleanup works.

The init-once pattern is specifically for resources that **don't** have a meaningful teardown (analytics, feature flags initialized once per session, third-party SDKs).

## When NOT to apply

- **Resources with proper cleanup** — use a real cleanup function instead.
- **Per-component initialization** — this rule is about app-level singletons. Component-level effects should react to mount/unmount normally.
- **Production-only init** — guarding via `if (process.env.NODE_ENV === 'production')` masks the StrictMode signal. Don't.

## Related

- [`prevent-rerender/move-effect-to-event`](../prevent-rerender/move-effect-to-event.md) — many one-shot initializations are misplaced as effects; consider whether the init belongs in a route loader or a service module evaluated at import.
