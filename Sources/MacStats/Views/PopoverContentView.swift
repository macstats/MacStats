import AppKit
import SwiftUI

/// Root of the popover: identity line, summary, detail panels, footer.
struct PopoverContentView: View {
    @ObservedObject var viewModel: StatsViewModel
    @ObservedObject var settings: AppSettings
    @State private var launchAtLogin = AppActions.isLaunchAtLoginEnabled

    private var version: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return value ?? "2.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DS.Layout.sectionGap) {
                    SystemInfoHeader(
                        uptime: viewModel.uptime,
                        thermalLevel: viewModel.thermalLevel,
                        lastUpdated: viewModel.lastUpdated
                    )
                    .equatable()

                    if !viewModel.activeAlerts.isEmpty {
                        AlertBannerView(alerts: viewModel.activeAlerts)
                            .equatable()
                    }

                    OverviewPanel(
                        cpu: viewModel.cpu,
                        memory: viewModel.memory,
                        disk: viewModel.disk,
                        network: viewModel.network,
                        cpuTrace: viewModel.cpuTrace
                    )
                    .equatable()

                    CPUDetailView(stats: viewModel.cpu, trace: viewModel.cpuTrace)
                        .equatable()

                    if viewModel.gpu.isAvailable {
                        GPUDetailView(stats: viewModel.gpu, history: viewModel.gpuTrace)
                            .equatable()
                    }

                    MemoryDetailView(stats: viewModel.memory)
                        .equatable()

                    NetworkDetailView(
                        stats: viewModel.network,
                        uploadTrace: viewModel.uploadTrace,
                        downloadTrace: viewModel.downloadTrace,
                        connections: viewModel.connections
                    )
                    .equatable()

                    if viewModel.wifi.isActive {
                        WiFiDetailView(stats: viewModel.wifi)
                            .equatable()
                    }

                    DiskDetailView(
                        stats: viewModel.disk,
                        readTrace: viewModel.diskReadTrace,
                        writeTrace: viewModel.diskWriteTrace
                    )
                        .equatable()

                    if viewModel.sensors.isAvailable {
                        SensorDetailView(stats: viewModel.sensors)
                            .equatable()
                    }

                    if viewModel.battery.isPresent {
                        BatteryDetailView(stats: viewModel.battery)
                            .equatable()
                    }

                    ProcessListView(viewModel: viewModel, sort: $settings.processSort)
                }
                .padding(DS.Space.m)
            }

            Rectangle()
                .fill(DS.Palette.hairline)
                .frame(height: 1)

            footer
        }
        .frame(width: DS.Layout.popoverWidth, height: 620)
    }

    private var footer: some View {
        HStack(spacing: DS.Space.s) {
            Text("MacStats \(version)")
                .font(DS.Text.micro)
                .foregroundColor(DS.Palette.tertiary)

            Spacer(minLength: DS.Space.s)

            Menu {
                menuContent
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Palette.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 22)
            .accessibilityLabel("More actions")

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .controlSize(.small)
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, DS.Space.s)
    }

    @ViewBuilder
    private var menuContent: some View {
        Button("Open Activity Monitor", action: AppActions.openActivityMonitor)
        Button("Copy Stats Summary") {
            AppActions.copySummary(viewModel.latestStats)
        }
        Button("Export Metrics CSV…") {
            AppActions.saveCSV(
                viewModel.csvSnapshot(),
                suggestedName: MetricsExporter.suggestedFileName()
            )
        }

        Toggle(
            "Enable Alerts",
            isOn: Binding(
                get: { viewModel.alertsEnabled },
                set: { viewModel.setAlertsEnabled($0) }
            )
        )

        Divider()

        Menu("Quick Actions") {
            Button("Sleep Display", action: AppActions.sleepDisplay)
            Button("Toggle Dark Mode", action: AppActions.toggleDarkMode)
            Button("Restart Finder", action: AppActions.restartFinder)
        }

        Divider()

        Picker("Menu Bar", selection: $settings.menuBarStyle) {
            ForEach(AppSettings.MenuBarStyle.allCases) { style in
                Text(style.label).tag(style)
            }
        }

        Picker("Refresh", selection: $settings.refreshRate) {
            ForEach(AppSettings.RefreshRate.allCases) { rate in
                Text(rate.label).tag(rate)
            }
        }

        Toggle("Launch at Login", isOn: $launchAtLogin)
            .onChange(of: launchAtLogin) { newValue in
                if newValue != AppActions.isLaunchAtLoginEnabled {
                    AppActions.toggleLaunchAtLogin()
                }
                launchAtLogin = AppActions.isLaunchAtLoginEnabled
            }
    }
}
