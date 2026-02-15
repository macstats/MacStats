import Foundation
import IOKit.ps

final class BatteryMonitor {

    func read() -> BatteryStats {
        var stats = BatteryStats()

        // Power source info (capacity, charging, time estimates)
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
           let first = sources.first,
           let desc = IOPSGetPowerSourceDescription(snapshot, first)?.takeUnretainedValue() as? [String: Any] {

            stats.isPresent = (desc[kIOPSIsPresentKey] as? Bool) ?? false

            if stats.isPresent {
                stats.currentCapacity = (desc[kIOPSCurrentCapacityKey] as? Int) ?? 0
                stats.maxCapacity = (desc[kIOPSMaxCapacityKey] as? Int) ?? 0
                stats.isCharging = (desc[kIOPSIsChargingKey] as? Bool) ?? false

                let powerSource = (desc[kIOPSPowerSourceStateKey] as? String) ?? ""
                stats.isPluggedIn = (powerSource == kIOPSACPowerValue)

                let tte = (desc[kIOPSTimeToEmptyKey] as? Int) ?? -1
                stats.timeToEmpty = tte >= 0 ? tte : -1

                let ttf = (desc[kIOPSTimeToFullChargeKey] as? Int) ?? -1
                stats.timeToFull = ttf >= 0 ? ttf : -1
            }
        }

        guard stats.isPresent else { return stats }

        // AppleSmartBattery: cycle count, design capacity, temperature
        readSmartBattery(&stats)

        return stats
    }

    private func readSmartBattery(_ stats: inout BatteryStats) {
        let matching = IOServiceMatching("AppleSmartBattery")
        var service: io_service_t = IO_OBJECT_NULL
        service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != IO_OBJECT_NULL else { return }
        defer { IOObjectRelease(service) }

        var propsRef: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == kIOReturnSuccess,
              let props = propsRef?.takeRetainedValue() as? [String: Any] else { return }

        stats.cycleCount = (props["CycleCount"] as? Int) ?? 0

        let designCap = (props["DesignCapacity"] as? Int) ?? 0
        stats.designCapacity = designCap

        // MaxCapacity from smart battery (more accurate than power source for health calc)
        let maxCap = (props["MaxCapacity"] as? Int) ?? stats.maxCapacity
        if designCap > 0 {
            stats.healthPercent = Double(maxCap) / Double(designCap) * 100.0
        }

        // Temperature is in centi-Celsius (e.g. 2930 = 29.30 C)
        if let tempRaw = props["Temperature"] as? Int {
            stats.temperature = Double(tempRaw) / 100.0
        }
    }
}
