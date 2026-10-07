import Foundation
import Testing
@testable import MacStatsCore

/// Regression cover for the single place the app turns numbers into text.
/// Every expectation is the exact rendered string, including unit-step
/// boundaries (just below a step stays in the smaller unit) and the fixed
/// four-character menu-bar cells.
@Suite("Format")
struct FormatTests {

    @Test("byte counts below 1 KB stay in bytes")
    func bytesBelowOneKilobyteStayInBytes() {
        #expect(Format.bytes(0) == "0 B")
        #expect(Format.bytes(1) == "1 B")
        #expect(Format.bytes(1023) == "1023 B")
    }

    @Test("bytes steps up KB, MB, GB and TB with the documented precision")
    func bytesStepsAcrossUnits() {
        #expect(Format.bytes(1024) == "1 KB")
        #expect(Format.bytes(2048) == "2 KB")
        #expect(Format.bytes(1_048_575) == "1024 KB")
        #expect(Format.bytes(1_048_576) == "1 MB")
        #expect(Format.bytes(10_485_760) == "10 MB")
        #expect(Format.bytes(1_073_741_823) == "1024 MB")
        #expect(Format.bytes(1_073_741_824) == "1.0 GB")
        #expect(Format.bytes(5_368_709_120) == "5.0 GB")
        #expect(Format.bytes(1_099_511_627_775) == "1024.0 GB")
        #expect(Format.bytes(1_099_511_627_776) == "1.0 TB")
        #expect(Format.bytes(2_199_023_255_552) == "2.0 TB")
        #expect(Format.bytes(UInt64.max) == "16777216.0 TB")
    }

    @Test("compact bytes keep the same steps without the space")
    func compactBytesSteps() {
        #expect(Format.compactBytes(0) == "0B")
        #expect(Format.compactBytes(1023) == "1023B")
        #expect(Format.compactBytes(1024) == "1K")
        #expect(Format.compactBytes(2048) == "2K")
        #expect(Format.compactBytes(1_048_575) == "1024K")
        #expect(Format.compactBytes(1_048_576) == "1M")
        #expect(Format.compactBytes(1_073_741_823) == "1024M")
        #expect(Format.compactBytes(1_073_741_824) == "1.0G")
        #expect(Format.compactBytes(1_099_511_627_775) == "1024.0G")
        #expect(Format.compactBytes(1_099_511_627_776) == "1.0T")
    }

    @Test("speeds that are zero, negative or non-finite render as zero")
    func speedRejectsNonPositiveAndNonFiniteInput() {
        #expect(Format.speed(0) == "0 B/s")
        #expect(Format.speed(-1) == "0 B/s")
        #expect(Format.speed(-1_048_576) == "0 B/s")
        #expect(Format.speed(Double.nan) == "0 B/s")
        #expect(Format.speed(Double.infinity) == "0 B/s")
        #expect(Format.speed(-Double.infinity) == "0 B/s")
    }

    @Test("speed steps up B/s, KB/s, MB/s and GB/s")
    func speedStepsAcrossUnits() {
        #expect(Format.speed(0.5) == "0 B/s")
        #expect(Format.speed(512) == "512 B/s")
        #expect(Format.speed(1023) == "1023 B/s")
        #expect(Format.speed(1024) == "1.0 KB/s")
        #expect(Format.speed(1536) == "1.5 KB/s")
        #expect(Format.speed(1_048_575) == "1024.0 KB/s")
        #expect(Format.speed(1_048_576) == "1.00 MB/s")
        #expect(Format.speed(1_572_864) == "1.50 MB/s")
        #expect(Format.speed(1_073_741_823) == "1024.00 MB/s")
        #expect(Format.speed(1_073_741_824) == "1.00 GB/s")
        #expect(Format.speed(2_147_483_648) == "2.00 GB/s")
    }

    @Test("menu-bar speeds keep a fixed four-character cell")
    func menuBarSpeedKeepsFixedWidthCells() {
        #expect(Format.menuBarSpeed(0) == "0B")
        #expect(Format.menuBarSpeed(-5) == "0B")
        #expect(Format.menuBarSpeed(Double.nan) == "0B")
        #expect(Format.menuBarSpeed(512) == "512B")
        #expect(Format.menuBarSpeed(1024) == "1.0K")
        #expect(Format.menuBarSpeed(1_048_575) == "1024K")
        #expect(Format.menuBarSpeed(1_048_576) == "1.0M")
        #expect(Format.menuBarSpeed(10_485_760) == "  10M")
        #expect(Format.menuBarSpeed(1_073_741_824) == " 1.0G")
        #expect(Format.menuBarSpeed(10_737_418_240) == "10.0G")
    }

    @Test("percent renders at the requested number of decimals")
    func percentUsesRequestedDecimals() {
        #expect(Format.percent(0) == "0%")
        #expect(Format.percent(42) == "42%")
        #expect(Format.percent(42.34) == "42%")
        #expect(Format.percent(42.34, decimals: 1) == "42.3%")
        #expect(Format.percent(99.96, decimals: 1) == "100.0%")
        #expect(Format.percent(100) == "100%")
    }

    @Test("uptime drops to the next smaller unit below each threshold")
    func uptimeStepsAcrossUnits() {
        #expect(Format.uptime(0) == "0s")
        #expect(Format.uptime(59) == "59s")
        #expect(Format.uptime(60) == "1m")
        #expect(Format.uptime(3599) == "59m")
        #expect(Format.uptime(3600) == "1h 0m")
        #expect(Format.uptime(86_399) == "23h 59m")
        #expect(Format.uptime(86_400) == "1d 0h 0m")
        #expect(Format.uptime(237_600) == "2d 18h 0m")
        #expect(Format.uptime(90.9) == "1m")
    }

    @Test("battery minutes render an em dash when unknown")
    func minutesRenderEmDashWhenUnknown() {
        #expect(Format.minutes(-1) == "—")
        #expect(Format.minutes(0) == "—")
        #expect(Format.minutes(1) == "1m")
        #expect(Format.minutes(59) == "59m")
        #expect(Format.minutes(60) == "1h 0m")
        #expect(Format.minutes(150) == "2h 30m")
    }

    @Test("freshness stamps advance with the elapsed interval")
    func ageAdvancesWithElapsedInterval() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(Format.age(since: now, now: now) == "just now")
        #expect(Format.age(since: now.addingTimeInterval(-1), now: now) == "just now")
        #expect(Format.age(since: now.addingTimeInterval(-2), now: now) == "2s ago")
        #expect(Format.age(since: now.addingTimeInterval(-59), now: now) == "59s ago")
        #expect(Format.age(since: now.addingTimeInterval(-60), now: now) == "1m ago")
        #expect(Format.age(since: now.addingTimeInterval(-3599), now: now) == "59m ago")
        #expect(Format.age(since: now.addingTimeInterval(-3600), now: now) == "1h ago")
        #expect(Format.age(since: now.addingTimeInterval(-7200), now: now) == "2h ago")
    }
}
