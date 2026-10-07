# MacStats Performance Notes

MacStats is a menu bar app that is expected to run for weeks. The goal is
therefore not "fast when you look at it" but **as close to zero as possible
when you don't** — while still feeling instant when the popover opens.

Everything below is measured on the development machine (Apple Silicon,
macOS 26.0.1) with `Scripts/bench.sh`, which drives the real sampling code.

## What the numbers are

```
bash Scripts/bench.sh 200
```

| Metric | Old (v1.1) | New (v2.0) |
| --- | --- | --- |
| Sampling pass, scheduled (`refresh`) avg | 0.595 ms | **0.049 ms** |
| Sampling pass, p95 | 5.03 ms | **0.053 ms** |
| Sampling pass, worst case (scheduled) | 6.39 ms | 0.074 ms |
| Top-process ranking avg | 1.244 ms | 1.179 ms |

Per-monitor cost in isolation (new):

| Monitor | Average | p95 | Notes |
| --- | --- | --- | --- |
| CPU | 0.011 ms | 0.014 ms | one Mach call, zero allocations |
| Memory | 0.001 ms | 0.001 ms | one `host_statistics64` call |
| Network | 0.021 ms | 0.021 ms | `getifaddrs`, no `String` bridging |
| Disk | 0.0012 ms | 0.0013 ms | `statfs` instead of `FileManager` |
| Battery | 0.131 ms | 0.361 ms | registry read tiered to every 4th pass |
| Wi-Fi | 2.027 ms | 3.761 ms | dominated by `rssiValue()`, sampled every other pass |
| Processes | 1.132 ms | 1.434 ms | syscall-bound: one `proc_pidinfo` per process |

The old numbers hid the same work behind a coarse schedule: a single pass could
cost 5–6 ms whenever the disk or IOKit path came due. The new pass is flat
because the expensive monitors back off individually *and* because each one got
cheaper.

## The five changes that mattered

### 1. `statfs` instead of `FileManager` (≈3800× on disk reads)

`FileManager.attributesOfFileSystem` builds a dictionary and bridges two
`NSNumber`s per read — ~5 ms, and the single largest spike in the old app.
`DiskMonitor` now calls `statfs` into a stack struct (0.0013 ms) and resolves
the volume name once at init.

### 2. Change-driven backoff

Slow monitors (disk, battery, Wi-Fi) are scheduled on their own clocks. When a
value comes back identical, its next read doubles (disk 4s → 30s while the
popover is open, 15s → 120s in the background; battery 8s → 30s / 30s → 120s;
Wi-Fi 5s → 20s / 20s → 90s). A value that changes snaps back to its base
cadence, so nothing goes stale when it matters.

### 3. Tiered Wi-Fi sampling

`CWInterface.rssiValue()` costs ~3.5 ms on macOS 26; every other CoreWLAN call
costs ~0.25 ms. Signal strength is therefore read every other pass and
SSID/channel/IP every sixth, which cuts the average Wi-Fi cost roughly in half
while keeping the panel visually live.

### 4. Suspension when nobody is looking

The whole sampling loop stops when the display sleeps or the screen locks, and
resumes with an immediate sample on wake/unlock. Sampling also adapts to
Low Power Mode (×2 interval) and thermal pressure (×1.5/×2). While the popover
is open the interval drops to ≤2s so the UI feels immediate.

### 5. Rendering kept off the hot path

- The status bar title is cached per value set; the chart is redrawn only when
  a new sample revision arrives.
- The chart renders into one reused bitmap context at the display's backing
  scale (crisper on Retina, no per-bar `NSColor` → `CGColor` bridging).
- The view model publishes **per section and only on change**; panels conform
  to `Equatable` and are used with `.equatable()`, so a CPU tick does not
  re-render the battery panel.
- History uses a fixed-capacity ring buffer instead of `Array.removeFirst()`
  on every tick.

## Idle cost

Measured on the same machine with the same protocol: process CPU-time delta
over a 45 s window with the popover closed, plus resident size from `ps` after
the app had been running for a few minutes. Both builds are debug builds from
this repository (the old one checked out from the 1.0 commit).

| | Old (v1.1) | New (v2.0) |
| --- | --- | --- |
| Menu bar CPU | 0.378 % | **0.156 %** |
| Resident memory | 72.7 MB | **48.6 MB** |

The installed universal release build measures the same steady state
(0.133 % CPU, 48 MB resident). Note that the *first* launch of a freshly
installed bundle is slower for reasons outside the app: macOS validates the new
binary, which showed up as a one-time multi-second CPU burst that never
reappears on subsequent launches.

Two design changes are part of that result and worth stating plainly:

- The *Refresh* setting now describes the open popover. The menu bar samples at
  twice that interval (capped at 10 s), so the default "Balanced 3s" means 3 s
  while you are watching and 6 s in the background.
- The popover's SwiftUI tree is created on first open, so a launch that never
  opens it never pays for the views.

`--benchmark` also reports per-monitor costs, so future regressions can be
attributed to a single syscall instead of guessed at.
