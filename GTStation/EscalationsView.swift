import SwiftUI

struct EscalationsView: View {
  @EnvironmentObject var appState: AppState
  @State private var feedback: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("Escalations")
          .font(.title2)
          .bold()
        Spacer()
        if let feedback {
          Text(feedback)
            .foregroundStyle(.green)
            .font(.caption)
        }
      }
      .padding()

      Divider()

      if appState.escalations.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "checkmark.circle")
            .font(.largeTitle)
            .foregroundStyle(.green)
          Text("No open escalations")
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(appState.escalations) { item in
          VStack(alignment: .leading, spacing: 6) {
            Text(item.description)
              .font(.body)
            HStack {
              Text(item.id)
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer()
              Button("Ack") {
                Task { await ack(id: item.id) }
              }
              .buttonStyle(.bordered)
              .controlSize(.small)
              Button("Close") {
                Task { await close(id: item.id) }
              }
              .buttonStyle(.borderedProminent)
              .controlSize(.small)
            }
          }
          .padding(.vertical, 4)
        }
      }
    }
  }

  private func ack(id: String) async {
    do {
      _ = try await GTClient.shared.escalateAck(id)
      feedback = "Acknowledged: \(id)"
      await appState.refresh()
    } catch {
      feedback = "Error: \(error.localizedDescription)"
    }
  }

  private func close(id: String) async {
    do {
      _ = try await GTClient.shared.escalateClose(id)
      feedback = "Closed: \(id)"
      await appState.refresh()
    } catch {
      feedback = "Error: \(error.localizedDescription)"
    }
  }
}
