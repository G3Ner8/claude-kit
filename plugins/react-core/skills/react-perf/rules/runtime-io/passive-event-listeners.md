---
title: Pass `{ passive: true }` for Scroll and Touch
impact: MEDIUM
impactDescription: tells the browser the listener won't `preventDefault()` — lets the compositor scroll without waiting for JS, fixes jank on touch devices
tags: runtime, scroll, touch, passive, dom-events
---

## Pass `{ passive: true }` for Scroll and Touch

When you attach a listener to `scroll`, `wheel`, `touchstart`, `touchmove`, or `touchend`, the browser doesn't know whether your handler will call `preventDefault()` to cancel the scroll. To stay safe, it waits for your handler to run before scrolling — which on a slow device introduces visible jank.

`{ passive: true }` is a promise: "I will not call `preventDefault()` in this handler." With that promise, the browser scrolls in parallel with your JS, and the page feels smooth.

Modern browsers treat `touchstart`/`touchmove` as passive **by default** in some cases (e.g. when attached to `document` or `window`), but explicit `{ passive: true }` is portable and self-documenting.

**Incorrect — implicit non-passive scroll listener:**

```ts
window.addEventListener('scroll', () => {
  updateScrollIndicator(window.scrollY);
});
```

The browser pessimistically waits for the handler each frame. On a 60Hz device, that handler must complete in < 16 ms to keep the frame budget. If it doesn't, scrolling stutters.

**Correct — explicit passive listener:**

```ts
window.addEventListener(
  'scroll',
  () => updateScrollIndicator(window.scrollY),
  { passive: true },
);
```

The browser scrolls without waiting. The handler still runs every frame but is no longer on the critical path.

## When you actually need preventDefault

If the handler *needs* to cancel the default scroll (a swipe-to-dismiss interaction, a custom drag-resize that hijacks scroll), you can't pass `passive: true` — the browser will warn and ignore your `preventDefault()`. In that case, attach the listener to a **specific element** rather than `document`, and keep the handler trivial.

```ts
slider.addEventListener('touchmove', (e) => {
  if (isDragging) e.preventDefault();
}, { passive: false });
```

`passive: false` is explicit consent that the handler may cancel. Outside of intentional gesture handlers, you almost never want it.

## In React

JSX event props (`onScroll`, `onTouchMove`) cannot be passive — React's synthetic event system attaches them as non-passive. For passive listeners on JSX elements, attach via ref + `addEventListener`:

```tsx
function ScrollIndicator({ children }: { children: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const onScroll = () => updateIndicator(el.scrollTop);
    el.addEventListener('scroll', onScroll, { passive: true });
    return () => el.removeEventListener('scroll', onScroll);
  }, []);

  return <div ref={ref}>{children}</div>;
}
```

## When NOT to apply

- **Click and keyboard events** — `click`, `keydown`, `keyup` don't have a "passive" notion. The flag has no effect.
- **The handler legitimately calls `preventDefault()`** — you can't use passive in that case (see above).
- **The listener is rare and short** — for a one-shot `scroll` listener that fires once and detaches (e.g. waiting for the user to scroll past the hero), the overhead is negligible. Apply the rule to long-lived listeners.

## Verify

Chrome DevTools → Performance recording during a scroll. Look for "Recalculate Style" or "Hit Test" entries blocked behind your handler in the main thread. If they show up *after* your handler, the listener is non-passive.

## Related

- [`event-listeners`](./event-listeners.md) — share one passive listener across all subscribers when many components want the scroll position.
