import SwiftUI

struct DoltHealthView: View {
  @EnvironmentObject var appState: AppState
  @State private var feedback: String? = nil
  @State private var isRunningAction: Bool = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("Dolt Health")
          .font(.title2)
          .bold()
          .padding(.horizontal)

        RawOutputCard(title: "Server Status", content: appState.doltStatus)
          .padding(.horizontal)

        HStack(spacing: 12) {
          Button("Start") {
            Task { await runAction("start") { try await GTClient.shared.doltStart() } }
          }
          .buttonStyle(.bordered)

          Button("Stop") {
            Task { await runAction("stop") { try await GTClient.shared.doltStop() } }
          }
          .buttonStyle(.bordered)

          Button("Cleanup") {
            Task { await runAction("cleanup") { try await GTClient.shared.doltCleanup() } }
          }
          .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .disabled(isRunningAction)

        if let feedback {
          ScrollView {
            Text(feedback)
              .font(.system(.body, design: .monospaced))
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding()
          }
          .frame(maxHeight: 200)
          .background(.secondary.opacity(0.1))
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .padding(.horizontal)
        }
      }
      .padding(.vertical)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func runAction(_ name: String, action: @escaping () async throws -> String) async {
    isRunningAction = true
    feedback = "Running \(name)..."
    do {
      let result = try await action()
      feedback = result.isEmpty ? "\(name) completed." : result
      await appState.refresh()
    } catch {
      feedback = "Error: \(error.localizedDescription)"
    }
    isRunningAction = false
  }
}
