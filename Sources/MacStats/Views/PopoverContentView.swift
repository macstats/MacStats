import SwiftUI

struct PopoverContentView: View {
    @ObservedObject var viewModel: StatsViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    if !viewModel.activeAlerts.isEmpty {
                        AlertBannerView(alerts: viewModel.activeAlerts)
                    }

                    SystemInfoHeader(
                        uptime: viewModel.uptime,
                        thermalLevel: viewModel.stats.thermalLevel
                    )

                    CPUDetailView(
                        stats: viewModel.stats.cpu,
                        history: viewModel.cpuHistory
                    )
                    if viewModel.stats.gpu.isAvailable {
                        GPUDetailView(
                            stats: viewModel.stats.gpu,
                            history: viewModel.gpuHistory
                        )
                    }
                    MemoryDetailView(stats: viewModel.stats.memory)
                    NetworkDetailView(
                        stats: viewModel.stats.network,
                        upHistory: viewModel.netUpHistory,
                        downHistory: viewModel.netDownHistory,
                        connections: viewModel.stats.connections
                    )
                    if viewModel.stats.wifi.isActive {
                        WiFiDetailView(stats: viewModel.stats.wifi)
                    }
                    DiskDetailView(
                        stats: viewModel.stats.disk,
                        readHistory: viewModel.diskReadHistory,
                        writeHistory: viewModel.diskWriteHistory
                    )
                    if viewModel.stats.sensors.isAvailable {
                        SensorDetailView(stats: viewModel.stats.sensors)
                    }
                    if viewModel.stats.battery.isPresent {
                        BatteryDetailView(stats: viewModel.stats.battery)
                    }
                    ProcessListView(viewModel: viewModel)
                }
                .padding(12)
            }

            VStack(spacing: 0) {
                Divider()
                HStack {
                    Text("MacStats v1.0.0")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    Spacer()
                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "power")
                                .font(.system(size: 9, weight: .semibold))
                            Text("Quit")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
        .frame(width: 360, height: 620)
    }
}
