---
title: Conditional Module Loading
impact: HIGH
impactDescription: loads large data or modules only when a feature is activated
tags: bundle, conditional-loading, lazy-loading
---

## Conditional Module Loading

Load large data or modules only when a feature is actually activated. Keep them out of the initial chunk entirely.

**Example (lazy-load animation frames):**

```tsx
function AnimationPlayer({ enabled, setEnabled }: { enabled: boolean; setEnabled: React.Dispatch<React.SetStateAction<boolean>> }) {
  const [frames, setFrames] = useState<Frame[] | null>(null)

  useEffect(() => {
    if (enabled && !frames) {
      import('./animation-frames.js')
        .then(mod => setFrames(mod.frames))
        .catch(() => setEnabled(false))
    }
  }, [enabled, frames, setEnabled])

  if (!frames) return <Skeleton />
  return <Canvas frames={frames} />
}
```

**Example (lazy-load a chart library only when the user opens analytics):**

```tsx
function AnalyticsTab({ visible }: { visible: boolean }) {
  const [Chart, setChart] = useState<React.ComponentType<ChartProps> | null>(null)

  useEffect(() => {
    if (visible && !Chart) {
      import('chart-library')
        .then(mod => setChart(() => mod.Chart))
    }
  }, [visible, Chart])

  if (!visible || !Chart) return null
  return <Chart data={...} />
}
```

For components that should be lazy-loaded **whenever they render** (not behind a flag), prefer `React.lazy` — see [Dynamic Imports for Heavy Components](./dynamic-imports.md).
