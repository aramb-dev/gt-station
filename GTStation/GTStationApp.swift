import SwiftUI

@main
struct GasStationApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @StateObject private var appState = AppState()

  var body: some Scene {
    WindowGroup("Gas Station", id: "dashboard") {
      DashboardView()
        .environmentObject(appState)
        .frame(minWidth: 960, minHeight: 700)
    }
    .windowStyle(.titleBar)
    .windowToolbarStyle(.unified)
  }
}

class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }
}
