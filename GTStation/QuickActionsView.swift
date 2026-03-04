import SwiftUI

struct QuickActionsView: View {
  @EnvironmentObject var appState: AppState
  @State private var nudgeTarget: String = ""
  @State private var nudgeMessage: String = ""
  @State private var feedback: String? = nil
  @State private var isRunning: Bool = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("Quick Actions")
          .font(.title2)
          .bold()

        GroupBox("Send Nudge") {
          VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Target:") {
              TextField("gtstation/witness", text: $nudgeTarget)
                .textFieldStyle(.roundedBorder)
            }
            LabeledContent("Message:") {
              TextField("Your message", text: $nudgeMessage)
                .textFieldStyle(.roundedBorder)
            }
            Button("Send Nudge") {
              Task { await sendNudge() }
            }
            .disabled(nudgeTarget.isEmpty || nudgeMessage.isEmpty || isRunning)
            .buttonStyle(.borderedProminent)
          }
        }

        GroupBox("System") {
          HStack(spacing: 12) {
            Button("Refresh All") {
              Task { await appState.refresh() }
            }
            .disabled(appState.isLoading)
          }
        }

        if let feedback {
          Text(feedback)
            .foregroundStyle(.green)
            .font(.caption)
        }
      }
      .padding()
    }
  }

  private func sendNudge() async {
    isRunning = true
    do {
      _ = try await GTClient.shared.nudge(nudgeTarget, message: nudgeMessage)
      feedback = "Nudge sent to \(nudgeTarget)"
      nudgeMessage = ""
    } catch {
      feedback = "Error: \(error.localizedDescription)"
    }
    isRunning = false
  }
}
