import SwiftUI

struct MenuBarView: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.openWindow) var openWindow

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: "bolt.fill")
          .foregroundStyle(.yellow)
        Text("GT Station")
          .font(.headline)
        Spacer()
        if appState.isLoading {
          ProgressView()
            .scaleEffect(0.6)
            .frame(width: 16, height: 16)
        }
      }
      .padding(.horizontal)
      .padding(.top, 8)

      Divider()

      Group {
        StatusRow(label: "Dolt", value: doltStatusBrief, color: doltStatusColor)
        StatusRow(label: "Mail", value: "\(appState.mailItems.count) messages")
        StatusRow(label: "Escalations", value: "\(appState.escalations.count) open",
                  color: appState.escalations.isEmpty ? .secondary : .orange)
      }
      .padding(.horizontal)

      Divider()

      Button("Open Dashboard") {
        openWindow(id: "dashboard")
        NSApp.activate(ignoringOtherApps: true)
      }
      .padding(.horizontal)

      Button("Refresh") {
        Task { await appState.refresh() }
      }
      .disabled(appState.isLoading)
      .padding(.horizontal)

      Divider()

      Button("Quit GT Station") {
        NSApplication.shared.terminate(nil)
      }
      .padding(.horizontal)
      .padding(.bottom, 8)
    }
    .frame(width: 280)
  }

  private var doltStatusBrief: String {
    let s = appState.doltStatus.lowercased()
    if s.contains("running") { return "Running" }
    if s.contains("stopped") { return "Stopped" }
    if appState.doltStatus.isEmpty { return "Unknown" }
    return "Check dashboard"
  }

  private var doltStatusColor: Color {
    let s = appState.doltStatus.lowercased()
    if s.contains("running") { return .green }
    if s.contains("stopped") { return .red }
    return .secondary
  }
}
