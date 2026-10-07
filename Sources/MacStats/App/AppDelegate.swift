import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let settings = AppSettings()
    private lazy var viewModel = StatsViewModel(settings: settings)
    private let locationManager = LocationManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        locationManager.requestAuthorization()
        viewModel.requestNotificationAuthorization()
        statusBarController = StatusBarController(viewModel: viewModel, settings: settings)
        viewModel.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stop()
    }
}
