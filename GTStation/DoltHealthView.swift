import SwiftUI

struct DoltHealthView: View {
  @EnvironmentObject var appState: AppState
  @State private var feedback: String? = nil
  @State private var isRunningAction: Bool = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text("Dolt Health")
            .font(.title2)
            .bold()
          Spacer()
          HStack(spacing: 4) {
            Circle()
              .fill(appState.isDoltRunning ? .green : .red)
              .frame(width: 10, height: 10)
            Text(appState.isDoltRunning ? "Running" : "Stopped")
              .font(.callout)
              .fontWeight(.medium)
          }
        }
        .padding(.horizontal)

        // Connection details
        if let dolt = appState.townStatus?.dolt {
          GroupBox("Connection") {
            VStack(alignment: .leading, spacing: 6) {
              if let pid = dolt.pid {
                LabeledContent("PID", value: "\(pid)")
              }
              if let port = dolt.port {
                LabeledContent("Port", value: "\(port)")
              }
              if let dir = dolt.data_dir {
                LabeledContent("Data Dir", value: dir)
              }
            }
            .font(.caption)
          }
          .padding(.horizontal)
        }

        // Raw status output
        GroupBox("Server Status") {
          ScrollView {
            Text(appState.doltStatusText.isEmpty ? "(no output)" : appState.doltStatusText)
              .font(.system(.caption, design: .monospaced))
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(8)
              .textSelection(.enabled)
          }
          .frame(maxHeight: 200)
        }
        .padding(.horizontal)

        // Actions
        GroupBox("Actions") {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
              Button("Start Dolt") {
                Task { await runAction("start") { try await GTClient.shared.doltStart() } }
              }
              .buttonStyle(.bordered)

              Button("Stop Dolt") {
                Task { await runAction("stop") { try await GTClient.shared.doltStop() } }
              }
              .buttonStyle(.bordered)

              Button("Cleanup Orphans") {
                Task { await runAction("cleanup") { try await GTClient.shared.doltCleanup() } }
              }
              .buttonStyle(.bordered)
            }
            .disabled(isRunningAction)

            if let feedback {
              ScrollView {
                Text(feedback)
                  .font(.system(.caption, design: .monospaced))
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(8)
                  .textSelection(.enabled)
              }
              .frame(maxHeight: 150)
              .background(.secondary.opacity(0.08))
              .clipShape(RoundedRectangle(cornerRadius: 6))
            }
          }
        }
        .padding(.horizontal)
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
