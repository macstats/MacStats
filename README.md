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
- Memory composition (active, wired, compressed, free)
- Network I/O with live sparklines
- Disk usage
- WiFi signal strength and connection info
- Battery level, health, cycle count, and temperature
- Top 5 processes by CPU usage

**Right-Click Menu**:
- Open Activity Monitor
- Copy stats summary to clipboard
- Quick Actions: Sleep Display, Toggle Dark Mode, Restart Finder
- Launch at Login toggle

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
│   └── StatusBarController.swift  # Menu bar UI + popover + context menu
├── Models/
│   ├── SystemStats.swift       # Data structures
│   └── TopProcess.swift        # Process info
├── Monitors/                   # System data collection
│   ├── SystemMonitor.swift     # Orchestrator + caching
│   ├── CPUMonitor.swift        # Mach host_processor_info
│   ├── MemoryMonitor.swift     # vm_statistics64
│   ├── NetworkMonitor.swift    # getifaddrs
│   ├── DiskMonitor.swift       # statfs
│   ├── ProcessMonitor.swift    # proc_pidinfo (top 5)
│   ├── BatteryMonitor.swift    # IOKit + AppleSmartBattery
│   └── WiFiMonitor.swift       # CoreWLAN
├── ViewModels/
│   └── StatsViewModel.swift    # MVVM binding + refresh loop
└── Views/                      # SwiftUI components
    ├── PopoverContentView.swift
    ├── SystemInfoHeader.swift
    ├── CPUDetailView.swift
    ├── MemoryDetailView.swift
    ├── NetworkDetailView.swift
    ├── DiskDetailView.swift
    ├── BatteryDetailView.swift
    ├── WiFiDetailView.swift
    ├── ProcessListView.swift
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
- **Smart caching** — disk/battery/WiFi refresh at lower frequencies than CPU/memory/network
- **Visibility gating** — SwiftUI views only receive updates when the popover is open
- **3-second refresh interval** — balances responsiveness with energy efficiency
- **Fixed-width status bar** — prevents layout jitter as values change

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
