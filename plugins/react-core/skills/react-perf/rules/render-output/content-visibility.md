---
title: `content-visibility: auto` for Long Off-Screen Lists
impact: MEDIUM
impactDescription: lets the browser skip layout and paint of off-screen content — first paint becomes much cheaper for long pages
tags: render-output, content-visibility, css, layout, performance
---

## `content-visibility: auto` for Long Off-Screen Lists

`content-visibility: auto` tells the browser: "Skip layout, paint, and rendering for this element while it's outside the viewport. Render it as the user scrolls toward it."

For long, mostly-off-screen lists, this is a massive win — the browser does work proportional to the visible portion, not the entire DOM. Long article pages, feeds, and reports with hundreds of cards can see 5-10x faster first paint.

The cost: the browser needs an estimate of the element's size when it's not rendered (otherwise scrollbar jumps as elements render in). Pair with `contain-intrinsic-size` for a stable placeholder.

**Incorrect — long list rendered in full on first paint:**

```css
.long-list {
  /* renders all 500 cards on first paint, even though only ~10 are visible */
}
```

The browser does layout work for all 500 cards every time anything in the list changes.

**Correct — `content-visibility: auto` with an intrinsic size hint:**

```css
.card {
  content-visibility: auto;
  contain-intrinsic-size: 0 200px;   /* 0 width = auto, 200px = estimated height */
}
```

Now the browser skips layout for cards outside the viewport, reserving 200px of placeholder space for each.

## Picking `contain-intrinsic-size`

The hint should match the real (eventual) size as closely as possible:

- **Card with known fixed-ish height (e.g. always ~180-220 px)**: `contain-intrinsic-size: 0 200px`.
- **Variable height that depends on content**: profile typical sizes, pick a representative value. A bad guess only causes scrollbar jitter when entries first paint.
- **Width is auto-fit (full container)**: `0` is correct for width.

## When NOT to apply

- **Short lists (< 30 items)** — overhead exceeds savings.
- **Items that drive measure-dependent layout** — if you measure heights for masonry or virtual scrolling, `content-visibility` hides the layout from your measurement until the item is on-screen. The two techniques don't compose.
- **Animated transitions across viewport boundaries** — items entering the viewport may briefly flash without their style applied. Test scroll-into-view animations.
- **Critical above-the-fold content** — `auto` doesn't actually skip if the element is on-screen, but it adds a layer of CSS containment that may interact with positioning. Only apply where the perf gain is measured.

## Browser support

- Chrome / Edge: shipping since 85.
- Safari: shipping since 18.
- Firefox: shipping since 125.

The CSS gracefully degrades — older browsers ignore the property and render everything as before. No fallback needed.

## Verify

Chrome DevTools → Performance → record first paint. The "Recalculate Style" and "Layout" entries should be smaller for the `content-visibility: auto` list. Lighthouse → Performance → "Avoid an excessive DOM size" should improve.

## Related

- **`react-window` / `react-virtual`** — for truly enormous lists (10,000+), virtual scrolling is the right tool. `content-visibility` is the lower-friction option for medium-sized lists (50-500).
