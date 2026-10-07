import Foundation
import IOKit.ps

final class BatteryMonitor {
    private var cachedSmart = BatterySmartInfo()
    private var readCount = 0
    /// Cycle count, design capacity and temperature come from the registry
    /// and change on the scale of hours — re-read them every few samples.
    private let smartInterval = 4

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
        let needsSmart = readCount % smartInterval == 0 || cachedSmart.designCapacity == 0
        readCount &+= 1
        if needsSmart {
            cachedSmart = readSmartBattery()
        }
        stats.cycleCount = cachedSmart.cycleCount
        stats.designCapacity = cachedSmart.designCapacity
        stats.temperature = cachedSmart.temperature
        if cachedSmart.designCapacity > 0 {
            let maxCapacity = stats.maxCapacity > 0 ? stats.maxCapacity : cachedSmart.maxCapacity
            stats.healthPercent = Double(maxCapacity) / Double(cachedSmart.designCapacity) * 100.0
        }

        return stats
    }

    private struct BatterySmartInfo {
        var cycleCount = 0
        var designCapacity = 0
        var maxCapacity = 0
        var temperature = 0.0
    }

    private func readSmartBattery() -> BatterySmartInfo {
        var info = BatterySmartInfo()
        let matching = IOServiceMatching("AppleSmartBattery")
        var service: io_service_t = IO_OBJECT_NULL
        service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != IO_OBJECT_NULL else { return info }
        defer { IOObjectRelease(service) }

        var propsRef: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == kIOReturnSuccess,
              let props = propsRef?.takeRetainedValue() as? [String: Any] else { return info }

        info.cycleCount = (props["CycleCount"] as? Int) ?? 0
        info.designCapacity = (props["DesignCapacity"] as? Int) ?? 0
        info.maxCapacity = (props["MaxCapacity"] as? Int) ?? 0

        // Temperature is in centi-Celsius (e.g. 2930 = 29.30 C)
        if let tempRaw = props["Temperature"] as? Int {
            info.temperature = Double(tempRaw) / 100.0
        }

        return info
    }
}
