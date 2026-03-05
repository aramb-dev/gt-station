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

        // Nudge
        GroupBox("Send Nudge") {
          VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Target:") {
              TextField("e.g. fursatech/witness, mayor/", text: $nudgeTarget)
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

        // System info
        if let town = appState.townStatus {
          GroupBox("Town Info") {
            VStack(alignment: .leading, spacing: 6) {
              LabeledContent("Name", value: town.name)
              LabeledContent("Location", value: town.location)
              if let overseer = town.overseer {
                LabeledContent("Overseer", value: overseer.name ?? "unknown")
              }
              if let tmux = town.tmux {
                LabeledContent("Tmux Sessions", value: "\(tmux.session_count ?? 0)")
              }
            }
            .font(.callout)
          }
        }

        // Refresh
        GroupBox("System") {
          HStack(spacing: 12) {
            Button("Refresh All Data") {
              Task { await appState.refresh() }
            }
            .disabled(appState.isLoading)
            .buttonStyle(.bordered)
          }
        }

        if let feedback {
          Text(feedback)
            .foregroundStyle(feedback.hasPrefix("Error") ? .red : .green)
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
