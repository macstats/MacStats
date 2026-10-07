import Foundation
import Testing
@testable import MacStatsCore

/// Regression cover for the pure status/percentage math the UI renders:
/// usage percentages (including the zero-total guards), Wi-Fi signal
/// bucketing, the shared `StatusLevel` classification and the
/// pressure/thermal label mappings.
@Suite("Model math")
struct ModelMathTests {

    @Test("memory usage percent guards a zero total")
    func memoryUsagePercentGuardsZeroTotal() {
        #expect(MemoryStats().usagePercent == 0)
        #expect(MemoryStats(totalBytes: 0, usedBytes: 4_096).usagePercent == 0)
        #expect(MemoryStats(totalBytes: 16_000, usedBytes: 4_000).usagePercent == 25)
        #expect(abs(MemoryStats(totalBytes: 6_000, usedBytes: 3_000).usagePercent - 50) < 1e-9)
        #expect(abs(MemoryStats(totalBytes: 3, usedBytes: 1).usagePercent - 33.3333333333) < 1e-6)
    }

    @Test("disk usage derives used bytes from total minus free")
    func diskUsageDerivesUsedBytesFromTotalAndFree() {
        let disk = DiskStats(totalBytes: 1_000_000_000, freeBytes: 250_000_000)
        #expect(disk.usedBytes == 750_000_000)
        #expect(abs(disk.usagePercent - 75) < 1e-9)
        #expect(DiskStats(totalBytes: 0, freeBytes: 0).usagePercent == 0)
        #expect(DiskStats().volumeName == "Macintosh HD")
    }

    @Test("battery charge percent guards a zero max capacity")
    func batteryChargePercentGuardsZeroMaxCapacity() {
        #expect(BatteryStats().chargePercent == 0)
        #expect(BatteryStats(currentCapacity: 2_500, maxCapacity: 0).chargePercent == 0)
        #expect(abs(BatteryStats(currentCapacity: 2_500, maxCapacity: 5_000).chargePercent - 50) < 1e-9)
        #expect(abs(BatteryStats(currentCapacity: 5_000, maxCapacity: 6_000).chargePercent - 83.3333333333) < 1e-6)
    }

    @Test("wifi signal bars use the documented RSSI thresholds")
    func wifiSignalBarsUseDocumentedThresholds() {
        #expect(WiFiStats(rssi: -30).signalBars == 4)
        #expect(WiFiStats(rssi: -50).signalBars == 4)
        #expect(WiFiStats(rssi: -51).signalBars == 3)
        #expect(WiFiStats(rssi: -60).signalBars == 3)
        #expect(WiFiStats(rssi: -61).signalBars == 2)
        #expect(WiFiStats(rssi: -70).signalBars == 2)
        #expect(WiFiStats(rssi: -71).signalBars == 1)
        #expect(WiFiStats(rssi: -80).signalBars == 1)
        #expect(WiFiStats(rssi: -81).signalBars == 0)
        #expect(WiFiStats(rssi: -90).signalBars == 0)
    }

    @Test("wifi signal level and default state follow the bar count")
    func wifiSignalLevelFollowsBarCount() {
        #expect(WiFiStats(rssi: -50).signalLevel == .normal)
        #expect(WiFiStats(rssi: -60).signalLevel == .normal)
        #expect(WiFiStats(rssi: -65).signalLevel == .elevated)
        #expect(WiFiStats(rssi: -75).signalLevel == .critical)
        #expect(WiFiStats().isActive == false)
        // The default rssi of 0 falls in the strongest bucket, so the
        // "no reading yet" state renders as four bars unless the caller
        // checks `isActive` first.
        #expect(WiFiStats().signalBars == 4)
        #expect(WiFiStats().signalLevel == .normal)
    }

    @Test("wifi band label maps channel numbers to bands")
    func wifiBandLabelMapsChannelsToBands() {
        #expect(WiFiStats().bandLabel == "—")
        #expect(WiFiStats(channel: 1).bandLabel == "2.4 GHz")
        #expect(WiFiStats(channel: 14).bandLabel == "2.4 GHz")
        #expect(WiFiStats(channel: 15).bandLabel == "5 GHz")
        #expect(WiFiStats(channel: 177).bandLabel == "5 GHz")
        #expect(WiFiStats(channel: 178).bandLabel == "6 GHz")
    }

    @Test("memory pressure keeps its kernel raw values and labels")
    func memoryPressureKeepsKernelRawValues() {
        #expect(MemoryPressure.normal.rawValue == 1)
        #expect(MemoryPressure.warning.rawValue == 2)
        #expect(MemoryPressure.critical.rawValue == 4)
        #expect(MemoryPressure.normal.label == "Normal")
        #expect(MemoryPressure.warning.label == "Warning")
        #expect(MemoryPressure.critical.label == "Critical")
        #expect(MemoryPressure.normal.level == .normal)
        #expect(MemoryPressure.warning.level == .elevated)
        #expect(MemoryPressure.critical.level == .critical)
    }

    @Test("thermal levels map to labels, symbols and status levels")
    func thermalLevelsMapToLabelsSymbolsAndLevels() {
        #expect(ThermalLevel.nominal.rawValue == 0)
        #expect(ThermalLevel.critical.rawValue == 3)
        #expect(ThermalLevel.nominal.label == "Normal")
        #expect(ThermalLevel.fair.label == "Fair")
        #expect(ThermalLevel.serious.label == "Serious")
        #expect(ThermalLevel.critical.label == "Critical")
        #expect(ThermalLevel.nominal.symbol == "thermometer.low")
        #expect(ThermalLevel.fair.symbol == "thermometer.medium")
        #expect(ThermalLevel.serious.symbol == "thermometer.high")
        #expect(ThermalLevel.critical.symbol == "flame.fill")
        #expect(ThermalLevel.fair.level == .normal)
        #expect(ThermalLevel.serious.level == .elevated)
        #expect(ThermalLevel.critical.level == .critical)
    }

    @Test("busiest core reports the first peak and ignores idle cores")
    func busiestCoreReportsFirstPeakAndIgnoresIdleCores() {
        #expect(CPUStats().busiestCore == nil)
        #expect(CPUStats(perCoreUsage: [0, 0, 0]).busiestCore == nil)
        #expect(CPUStats(perCoreUsage: [0, 0]).coreCount == 2)

        let busiest = CPUStats(perCoreUsage: [10, 40, 40]).busiestCore
        #expect(busiest?.index == 1)
        #expect(busiest?.usage == 40)
    }

    @Test("status level classifies a usage fraction at the default thresholds")
    func statusLevelClassifiesUsageFraction() {
        #expect(StatusLevel.usage(0) == .normal)
        #expect(StatusLevel.usage(0.64) == .normal)
        #expect(StatusLevel.usage(0.65) == .elevated)
        #expect(StatusLevel.usage(0.84) == .elevated)
        #expect(StatusLevel.usage(0.85) == .critical)
        #expect(StatusLevel.usage(1) == .critical)
    }

    @Test("status level honours explicit thresholds")
    func statusLevelHonoursExplicitThresholds() {
        #expect(StatusLevel.usage(0.49, elevated: 0.5, critical: 0.75) == .normal)
        #expect(StatusLevel.usage(0.5, elevated: 0.5, critical: 0.75) == .elevated)
        #expect(StatusLevel.usage(0.75, elevated: 0.5, critical: 0.75) == .critical)
    }

    @Test("status levels keep their severity ordering")
    func statusLevelsKeepSeverityOrdering() {
        #expect(StatusLevel.normal < StatusLevel.elevated)
        #expect(StatusLevel.elevated < StatusLevel.critical)
        #expect(StatusLevel.normal.rawValue == "normal")
        #expect(StatusLevel.critical.rawValue == "critical")
    }

    @Test("unitClamped pins fractions to the 0...1 range")
    func unitClampedPinsFractionsToUnitRange() {
        #expect((-1.0).unitClamped == 0)
        #expect(0.0.unitClamped == 0)
        #expect(0.5.unitClamped == 0.5)
        #expect(1.0.unitClamped == 1)
        #expect(2.0.unitClamped == 1)
    }
}
