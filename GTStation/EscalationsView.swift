import SwiftUI

struct EscalationsView: View {
  @EnvironmentObject var appState: AppState

  var body: some View {
    // Escalations are shown in the overview now
    // This view could be expanded later
    VStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text("Escalations are shown in the Overview tab")
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
