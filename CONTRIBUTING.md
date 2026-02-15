# Contributing to MacStats

Thanks for your interest in contributing! Here's how to get started.

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/macstats/MacStats.git
   cd MacStats
   ```

2. Build and run in debug mode:
   ```bash
   bash Scripts/build.sh debug
   .build/debug/MacStats
   ```

3. Build the full app bundle:
   ```bash
   bash Scripts/bundle.sh
   open .build/release/MacStats.app
   ```

## Project Structure

- `Sources/MacStats/Monitors/` — System data collection (one file per metric)
- `Sources/MacStats/Views/` — SwiftUI views (one file per section)
- `Sources/MacStats/Views/Components/` — Reusable UI primitives
- `Sources/MacStats/ViewModels/` — Data binding between monitors and views
- `Sources/MacStats/Models/` — Data structures
- `Sources/MacStats/App/` — Application lifecycle and status bar controller
- `Scripts/` — Build, bundle, and icon generation scripts

## Guidelines

### Code Style

- Follow existing patterns in the codebase
- Use `final class` for classes that aren't subclassed
- Prefer value types (`struct`) over reference types where possible
- Keep monitors independent — each should be self-contained
- Use Swift's native APIs and system frameworks; avoid third-party dependencies

### Commits

- Write clear, concise commit messages
- Use conventional commits format: `feat:`, `fix:`, `refactor:`, `docs:`, etc.
- Keep commits focused on a single change

### Pull Requests

- Open an issue first for significant changes to discuss the approach
- Keep PRs focused — one feature or fix per PR
- Include a description of what changed and why
- Test on macOS 13+ before submitting

## Adding a New Monitor

1. Create `Sources/MacStats/Monitors/YourMonitor.swift` — implement data collection
2. Add the data model to `Sources/MacStats/Models/SystemStats.swift`
3. Wire it into `Sources/MacStats/Monitors/SystemMonitor.swift`
4. Add the view in `Sources/MacStats/Views/YourDetailView.swift`
5. Include the view in `PopoverContentView.swift`
6. Add the source file to `Scripts/build.sh` SOURCES array

## Reporting Issues

- Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md)
- Include your macOS version and hardware (Intel vs Apple Silicon)
- Describe what you expected vs what happened

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
