# MacStats

A lightweight, native macOS menu bar system monitor. Real-time CPU, memory, network, disk, battery, and WiFi stats — zero dependencies, pure Swift.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.8](https://img.shields.io/badge/Swift-5.8-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

<p align="center">
  <img src="assets/screenshot.png" alt="MacStats Popover" width="400">
</p>

## Features

**Menu Bar** — Always-visible system metrics at a glance:
- CPU usage %, Memory %, Upload/Download speeds
- Mini CPU history bar chart with color-coded thresholds

**Popover Dashboard** (click the menu bar item):
- System uptime and thermal status
- Per-core CPU breakdown with sparkline history
- GPU utilization, GPU name, and unified/VRAM memory in use
- Memory composition (active, wired, compressed, free)
- Network I/O with live sparklines
- TCP connection states (established / listening / time wait / close wait) and listening ports
- Disk usage plus real-time read/write throughput and session totals
- Thermals straight from the AppleSMC: CPU temperature and fan RPM
- WiFi signal strength and connection info
- Battery level, health, cycle count, and temperature
- Process manager: top 5/10/20, sort by CPU or memory, filter by name/path, and
  terminate or force-kill a process from its context menu
- Threshold alerts (CPU, memory, disk, battery, thermal) as an in-popover banner
  plus native macOS notifications

**Right-Click Menu**:
- Open Activity Monitor
- Copy stats summary to clipboard
- Export the session metrics buffer to CSV
- Alerts submenu: enable/disable threshold alerts, send a test notification
- Quick Actions: Sleep Display, Toggle Dark Mode, Restart Finder
- Launch at Login toggle

## CLI Diagnostics

The binary doubles as a headless diagnostic tool (no GUI session needed):

```bash
./.build/debug/MacStats --dump-once   # one real sample of every monitor, then exit
./.build/debug/MacStats --kill-test   # spawn a disposable sleep, find it, SIGTERM it
./.build/debug/MacStats --alert-test  # feed synthetic breaches through AlertCenter
```

`--dump-once` ticks the slow-cadence monitors (disk I/O, SMC, TCP) so the output
contains real deltas, and it self-checks the CSV schema.

## Install

### Download

Download the latest `MacStats.dmg` from [Releases](https://github.com/macstats/MacStats/releases), open it, and drag MacStats to Applications.

> Universal Binary — supports both Apple Silicon and Intel Macs.

### Build from Source

Requires **Xcode Command Line Tools** and **macOS 13+** (Ventura or later).

```bash
git clone https://github.com/macstats/MacStats.git
cd MacStats

# Build the app bundle (universal binary, ad-hoc signed)
bash Scripts/bundle.sh

# Launch
open .build/release/MacStats.app
```

To keep it running permanently, drag `MacStats.app` to `/Applications` and enable **Launch at Login** from the right-click menu.

### Debug Build

```bash
bash Scripts/build.sh debug
.build/debug/MacStats
```

## Architecture

```
Sources/MacStats/
├── main.swift                  # Entry point
├── App/
│   ├── AppDelegate.swift       # NSApplicationDelegate
│   ├── LocationManager.swift   # CoreLocation authorization for WiFi SSID
│   ├── AlertCenter.swift       # Threshold evaluation + notifications
│   ├── MetricsExporter.swift   # Session buffer -> CSV
│   ├── DumpOnce.swift          # --dump-once / --kill-test / --alert-test
│   └── StatusBarController.swift  # Menu bar UI + popover + context menu
├── Models/
│   ├── SystemStats.swift       # Data structures
│   ├── TopProcess.swift        # Process info
│   └── MetricSample.swift      # One session history row
├── Monitors/                   # System data collection
│   ├── SystemMonitor.swift     # Orchestrator + caching
│   ├── CPUMonitor.swift        # Mach host_processor_info
│   ├── MemoryMonitor.swift     # vm_statistics64
│   ├── NetworkMonitor.swift    # getifaddrs
│   ├── DiskMonitor.swift       # statfs + IOBlockStorageDriver throughput
│   ├── ProcessMonitor.swift    # proc_pidinfo (top N, sort/search/kill)
│   ├── BatteryMonitor.swift    # IOKit + AppleSmartBattery
│   ├── WiFiMonitor.swift       # CoreWLAN
│   ├── GPUMonitor.swift        # IOAccelerator PerformanceStatistics
│   ├── SensorMonitor.swift     # AppleSMC temperature + fans
│   └── ConnectionMonitor.swift # libproc socket enumeration (TCP states)
├── ViewModels/
│   └── StatsViewModel.swift    # MVVM binding + refresh loop
└── Views/                      # SwiftUI components
    ├── PopoverContentView.swift
    ├── SystemInfoHeader.swift
    ├── CPUDetailView.swift
    ├── GPUDetailView.swift
    ├── MemoryDetailView.swift
    ├── NetworkDetailView.swift
    ├── DiskDetailView.swift    # capacity + live read/write
    ├── SensorDetailView.swift  # SMC thermals / fans
    ├── AlertBannerView.swift   # active threshold breaches
    ├── BatteryDetailView.swift
    ├── WiFiDetailView.swift
    ├── ProcessListView.swift   # sort / filter / terminate
    └── Components/             # Reusable UI primitives
        ├── RingView.swift
        ├── SparklineView.swift
        ├── SectionCardView.swift
        ├── SegmentedBarView.swift
        ├── StatRowView.swift
        └── UsageBarView.swift
```

### Design Decisions

- **Zero external dependencies** — only Apple system frameworks (AppKit, SwiftUI, IOKit, Combine, ServiceManagement, CoreWLAN, CoreLocation)
- **Universal Binary** — single binary runs natively on both Apple Silicon and Intel Macs
- **MVVM pattern** — `StatsViewModel` drives both the status bar (via callback) and popover (via `@Published`)
- **Smart caching** — GPU every ~6s, disk/SMC every ~15s, TCP/battery/WiFi every ~30–45s, CPU/memory/network every 3s
- **Visibility gating** — SwiftUI views only receive updates when the popover is open
- **3-second refresh interval** — balances responsiveness with energy efficiency
- **Fixed-width status bar** — prevents layout jitter as values change
- **No helper processes** — disk I/O comes from `IOBlockStorageDriver`, TCP state from in-process
  `libproc` socket enumeration, thermals from the AppleSMC user client. (Spawning `netstat`
  from an ad-hoc signed app returns an empty PCB listing on current macOS.)
- **Graceful degradation** — the GPU, SMC and connection sections disappear when the machine
  or permissions do not expose them

### Known Limitations

- TCP states cover the current user's processes; root daemons are not visible without
  elevated privileges.
- Temperature/fan keys differ between Intel and Apple Silicon (and between SMC firmware
  versions). `SensorMonitor` probes both key sets, tries both float endiannesses, and hides
  the card when nothing decodes.
- Alerts deliver native notifications only when running from `MacStats.app` (a bundle
  identifier is required); the raw binary still shows the in-popover banner.

## Requirements

| Requirement | Version |
|-------------|---------|
| macOS       | 13.0+ (Ventura) |
| Swift       | 5.8+ |
| Xcode CLT   | 14+ |
| Architecture | Universal (Apple Silicon + Intel) |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE)
