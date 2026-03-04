import SwiftUI

@main
struct GTStationApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @StateObject private var appState = AppState()

  var body: some Scene {
    WindowGroup("GT Station", id: "dashboard") {
      DashboardView()
        .environmentObject(appState)
        .frame(minWidth: 900, minHeight: 650)
    }
    .windowStyle(.titleBar)
    .windowToolbarStyle(.unified)

    MenuBarExtra("GT Station", systemImage: "bolt.fill") {
      MenuBarView()
        .environmentObject(appState)
    }
    .menuBarExtraStyle(.window)
  }
}

class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }
}
