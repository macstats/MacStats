import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let viewModel = StatsViewModel()
    private let locationManager = LocationManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        locationManager.requestAuthorization()
        statusBarController = StatusBarController(viewModel: viewModel)
        viewModel.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stop()
    }
}
