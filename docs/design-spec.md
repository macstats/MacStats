# MacStats Design Spec — "Precision Instrument"

This document is the source of truth for MacStats' visual language. It exists so
future changes stay inside one coherent system instead of drifting back into
decorative, AI-generated-looking UI.

## Direction

**Information school, native desktop.** MacStats is an instrument, not a
landing page: the user opens it to read numbers accurately for a few seconds.
The design therefore optimizes for scan speed, numeric stability, and looking
like a first-class piece of macOS rather than a web dashboard.

Three rules follow from that and drive everything else:

1. **Data first.** Real values appear immediately; there is no hero copy,
   no empty state decoration, no marketing surface.
2. **Color means something.** Chrome, icons, and labels are monochrome.
   Saturated color is reserved for state (health, pressure, thresholds) and
   for the three data hues that encode which subsystem a number belongs to.
3. **One signature surface.** The overview panel — four gauges over one wide
   CPU trace — is the screen's 120% element. Everything below it is quieter
   detail, so the popover has a single focal point.

## Palette

| Token | Value | Use |
| --- | --- | --- |
| `Palette.accent` | `NSColor.controlAccentColor` | Interactive emphasis; follows the user's system accent |
| `Palette.panel` | `controlBackgroundColor` @ 62% | Panel fill, lets the popover's native material show |
| `Palette.hairline` | `separatorColor` @ 60% | 1pt panel borders and dividers |
| `Palette.track` | `quaternaryLabelColor` @ 70% | Empty portion of bars and gauges |
| `Palette.cpu` | `systemBlue` | CPU data |
| `Palette.memory` | `systemTeal` | Memory data (composition uses an opacity ramp of this hue) |
| `Palette.disk` | `systemIndigo` | Disk data |
| `Palette.down` / `up` | `systemBlue` / `systemTeal` | Network direction, always paired with an arrow |
| `Palette.ok/warn/alert` | `systemGreen/orange/red` | Threshold state only |

Rules:

- Never introduce a new hue without deleting one; the palette is closed.
- Status colors always override a data hue when a value crosses a threshold
  (≥65% elevated, ≥85% critical unless a metric defines its own bounds).
- Text uses `labelColor` / `secondaryLabelColor` / `tertiaryLabelColor` only.
- No purple-blue gradients, no neon-on-dark, no colored card accents.

## Typography

Five sizes, all SF Pro; every number uses tabular/monospaced digits so values
never shift the layout as they change.

| Token | Size / weight | Use |
| --- | --- | --- |
| `Text.metric` | 20 semibold rounded | One hero number per panel |
| `Text.readout` | 15 semibold rounded | Secondary readouts (battery time, tile values) |
| `Text.title` | 12 semibold | Panel titles |
| `Text.body` | 11 regular | Row labels |
| `Text.label` | 10 medium | Inline values, captions in headers |
| `Text.micro` | 9 medium | Column headers, metadata |
| `Text.mono(_:)` | monospaced digits | Every numeric value |

Numbers are always monospaced digits; labels are never monospaced.

## Layout

- 8pt grid: 4 / 8 / 12 / 16 / 24. Panel padding is 12, section gap is 8.
- Panels are flat surfaces with a 1pt hairline border and a 12pt continuous
  corner radius. Drop shadows are not used; depth comes from the popover's own
  material and the hairline hierarchy.
- Each panel is: header (symbol tile + title + accessory) → hero number →
  visualization → supporting rows.
- Graphics primitives (`ProgressBar`, `SegmentedBar`, `TraceView`, `RingGauge`,
  `CoreBar`) read their own rect through `Shape`/`Canvas`. `GeometryReader` is
  not used for layout.
- Popover width is fixed at 360pt so the menu bar item, the panels, and the
  charts all share one column rhythm.

## Motion

- Bars: 0.35s ease-out on value change. Rings: 0.45s ease-out.
- Hover highlight: 0.12s.
- Every animation is disabled when *Reduce Motion* is on
  (`@Environment(\.accessibilityReduceMotion)`).

## Accessibility

- Composite rows use `accessibilityElement(children: .combine)` with a
  composed label ("Download 4.21 MB/s") instead of exposing raw fragments.
- Decorative graphics (bars, traces, gauges, signal bars) are hidden from
  VoiceOver; the value they encode is always present as text.
- The status item exposes a label ("MacStats"), a value
  ("CPU 34%, memory 59%") and a tooltip with the full reading.
- Color is never the only signal: thresholds also change numbers and icons.
- Interactive controls use standard SwiftUI controls (`Picker`, `Menu`,
  `Button`) with real labels, sized for pointer use.

## Anti-slop checklist

| Rule | Status |
| --- | --- |
| No purple-blue gradients | ✅ single system accent, solid surfaces |
| No emoji as icons | ✅ SF Symbols only |
| No rounded card + left accent border | ✅ flat panels with hairline borders |
| No generic hero section | ✅ the header is one line of identity data |
| No Inter/Roboto | ✅ system fonts only |
| No neon-on-dark | ✅ system materials, adaptive colors |
| No symmetric 3-column feature grid | ✅ content-driven: 4 gauges, then detail panels |
| No AI-drawn illustrations | ✅ no illustrations at all |
| No default-blue-everywhere | ✅ accent follows the system accent; data hues carry meaning |
| No random spacing | ✅ 8pt grid tokens only |

## Reference screenshot

`assets/screenshot.png` (light) and `assets/screenshot-dark.png` (dark) are
generated from the real view tree with
`MacStats --snapshot assets/screenshot.png [dark]`, so they cannot drift from
the implementation.
