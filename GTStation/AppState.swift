import Foundation
import Combine

@MainActor
class AppState: ObservableObject {
  @Published var status: String = ""
  @Published var polecats: String = ""
  @Published var convoys: String = ""
  @Published var mailItems: [MailItem] = []
  @Published var escalations: [EscalationItem] = []
  @Published var doltStatus: String = ""
  @Published var isLoading: Bool = false
  @Published var lastError: String? = nil

  private var refreshTimer: Timer?
  private let client = GTClient.shared

  init() {
    startPolling()
    Task { await refresh() }
  }

  func startPolling() {
    refreshTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        await self?.refresh()
      }
    }
  }

  func stopPolling() {
    refreshTimer?.invalidate()
    refreshTimer = nil
  }

  func refresh() async {
    isLoading = true
    lastError = nil

    async let statusTask = client.status()
    async let doltTask = client.doltStatus()
    async let mailTask = client.mailInbox()
    async let escalationTask = client.escalateList()
    async let polecatTask = client.polecatList()
    async let convoyTask = client.convoyList()

    status = (try? await statusTask) ?? "Error fetching status"
    doltStatus = (try? await doltTask) ?? "Error fetching dolt status"
    polecats = (try? await polecatTask) ?? "Error fetching polecats"
    convoys = (try? await convoyTask) ?? "Error fetching convoys"

    let mailRaw = try? await mailTask
    let escRaw = try? await escalationTask

    if let mailRaw {
      mailItems = parseMailItems(mailRaw)
    }
    if let escRaw {
      escalations = parseEscalations(escRaw)
    }

    isLoading = false
  }

  private func parseMailItems(_ raw: String) -> [MailItem] {
    var items: [MailItem] = []
    let lines = raw.split(separator: "\n", omittingEmptySubsequences: true)
    for line in lines {
      let str = String(line).trimmingCharacters(in: .whitespaces)
      // Skip header/blank lines
      if str.hasPrefix("#") || str.hasPrefix("[") || str.isEmpty { continue }
      // Try to extract an ID and subject from tab/space-separated lines
      let parts = str.split(separator: "\t", maxSplits: 1)
      if parts.count >= 2 {
        let id = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let subject = String(parts[1]).trimmingCharacters(in: .whitespaces)
        if !id.isEmpty { items.append(MailItem(id: id, subject: subject)) }
      } else {
        let spaceParts = str.split(separator: " ", maxSplits: 2)
        if spaceParts.count >= 2 {
          let id = String(spaceParts[0]).trimmingCharacters(in: .whitespaces)
          let subject = spaceParts.dropFirst().joined(separator: " ")
          if id.count < 30 { items.append(MailItem(id: id, subject: subject)) }
        }
      }
    }
    return items
  }

  private func parseEscalations(_ raw: String) -> [EscalationItem] {
    var items: [EscalationItem] = []
    let lines = raw.split(separator: "\n", omittingEmptySubsequences: true)
    for line in lines {
      let str = String(line).trimmingCharacters(in: .whitespaces)
      if str.hasPrefix("#") || str.hasPrefix("[") || str.isEmpty { continue }
      let parts = str.split(separator: " ", maxSplits: 3)
      if parts.count >= 2 {
        let id = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let desc = parts.dropFirst().joined(separator: " ")
        if id.count < 30 { items.append(EscalationItem(id: id, description: desc, severity: "unknown")) }
      }
    }
    return items
  }
}

struct MailItem: Identifiable {
  let id: String
  let subject: String
}

struct EscalationItem: Identifiable {
  let id: String
  let description: String
  let severity: String
}
