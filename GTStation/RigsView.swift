import SwiftUI

struct RigsView: View {
  @EnvironmentObject var appState: AppState
  @State private var feedback: String? = nil
  @State private var isRunningAction: Bool = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text("Rigs")
            .font(.title2)
            .bold()
          Spacer()
          if let feedback {
            Text(feedback)
              .font(.caption)
              .foregroundStyle(feedback.hasPrefix("Error") ? .red : .green)
              .transition(.opacity)
          }
        }
        .padding(.horizontal)

        if appState.rigs.isEmpty {
          VStack(spacing: 8) {
            Image(systemName: "server.rack")
              .font(.largeTitle)
              .foregroundStyle(.secondary)
            Text("No rigs found")
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding(.top, 60)
        } else {
          ForEach(appState.rigs) { rig in
            RigCard(rig: rig, feedback: $feedback, isRunningAction: $isRunningAction)
              .padding(.horizontal)
          }
        }

        // Rig details from town status
        if let rigDetails = appState.townStatus?.rigs, !rigDetails.isEmpty {
          Divider()
            .padding(.horizontal)

          Text("Agent Details")
            .font(.headline)
            .padding(.horizontal)

          ForEach(rigDetails, id: \.name) { detail in
            if let agents = detail.agents, !agents.isEmpty {
              SectionCard(title: detail.name) {
                ForEach(agents, id: \.name) { agent in
                  HStack {
                    Circle()
                      .fill(agent.running ? .green : .red)
                      .frame(width: 8, height: 8)
                    Text(agent.name)
                      .fontWeight(.medium)
                    if let role = agent.role {
                      Text(role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let mail = agent.unread_mail, mail > 0 {
                      Label("\(mail)", systemImage: "envelope")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                  }
                  .padding(.vertical, 2)
                }
              }
              .padding(.horizontal)
            }
          }
        }
      }
      .padding(.vertical)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct RigCard: View {
  let rig: RigInfo
  @Binding var feedback: String?
  @Binding var isRunningAction: Bool

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Circle()
            .fill(rig.witness == "running" ? .green : .yellow)
            .frame(width: 10, height: 10)
          Text(rig.name)
            .font(.headline)
          Spacer()
          if let status = rig.status {
            Text(status)
              .font(.caption)
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(statusColor(status).opacity(0.15), in: Capsule())
              .foregroundStyle(statusColor(status))
          }
        }

        HStack(spacing: 20) {
          Label("Witness: \(rig.witness ?? "?")", systemImage: "eye")
            .font(.caption)
            .foregroundStyle(rig.witness == "running" ? .primary : .secondary)
          Label("Refinery: \(rig.refinery ?? "?")", systemImage: "gearshape")
            .font(.caption)
            .foregroundStyle(rig.refinery == "running" ? .primary : .secondary)
          Label("Polecats: \(rig.polecats ?? 0)", systemImage: "hare")
            .font(.caption)
          Label("Crew: \(rig.crew ?? 0)", systemImage: "person.2")
            .font(.caption)
        }

        HStack(spacing: 8) {
          Button("Start") {
            Task { await runAction("start \(rig.name)") { try await GTClient.shared.rigStart(rig.name) } }
          }
          .buttonStyle(.bordered)
          .controlSize(.small)

          Button("Stop") {
            Task { await runAction("stop \(rig.name)") { try await GTClient.shared.rigStop(rig.name) } }
          }
          .buttonStyle(.bordered)
          .controlSize(.small)

          Spacer()

          Button("Dock") {
            Task { await runAction("dock \(rig.name)") { try await GTClient.shared.rigDock(rig.name) } }
          }
          .buttonStyle(.bordered)
          .controlSize(.small)

          Button("Undock") {
            Task { await runAction("undock \(rig.name)") { try await GTClient.shared.rigUndock(rig.name) } }
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        }
        .disabled(isRunningAction)
      }
    }
  }

  @MainActor
  private func runAction(_ name: String, action: @escaping () async throws -> String) async {
    isRunningAction = true
    do {
      let result = try await action()
      feedback = result.isEmpty ? "\(name): done" : result.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
      feedback = "Error: \(error.localizedDescription)"
    }
    isRunningAction = false
    try? await Task.sleep(for: .seconds(3))
    feedback = nil
  }

  private func statusColor(_ status: String) -> Color {
    switch status.lowercased() {
    case "operational": return .green
    case "docked": return .secondary
    case "parked": return .yellow
    default: return .primary
    }
  }
}
