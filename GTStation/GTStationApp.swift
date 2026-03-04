import SwiftUI

@main
struct GTStationApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @StateObject private var appState = AppState()

  var body: some Scene {
    MenuBarExtra("GT Station", systemImage: "bolt.fill") {
      MenuBarView()
        .environmentObject(appState)
    }
    .menuBarExtraStyle(.window)

    Window("GT Station Dashboard", id: "dashboard") {
      DashboardView()
        .environmentObject(appState)
        .frame(minWidth: 800, minHeight: 600)
    }
    .windowStyle(.titleBar)
    .windowToolbarStyle(.unified)
  }
}

class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }
}
