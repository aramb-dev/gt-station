import Foundation

// MARK: - Town Status

struct TownStatus: Codable {
  let name: String
  let location: String
  let overseer: OverseerInfo?
  let daemon: ServiceStatus?
  let dolt: DoltInfo?
  let tmux: TmuxInfo?
  let agents: [AgentInfo]?
  let rigs: [RigDetail]?
  let summary: TownSummary?
}

struct OverseerInfo: Codable {
  let name: String?
  let email: String?
  let username: String?
  let unread_mail: Int?
}

struct ServiceStatus: Codable {
  let running: Bool
  let pid: Int?
}

struct DoltInfo: Codable {
  let running: Bool
  let pid: Int?
  let port: Int?
  let data_dir: String?
}

struct TmuxInfo: Codable {
  let socket: String?
  let socket_path: String?
  let running: Bool
  let pid: Int?
  let session_count: Int?
}

struct AgentInfo: Codable {
  let name: String
  let address: String?
  let session: String?
  let role: String?
  let running: Bool
  let has_work: Bool?
  let state: String?
  let unread_mail: Int?
}

struct RigDetail: Codable {
  let name: String
  let polecat_count: Int?
  let crew_count: Int?
  let has_witness: Bool?
  let has_refinery: Bool?
  let agents: [AgentInfo]?
}

struct TownSummary: Codable {
  let rig_count: Int?
  let polecat_count: Int?
  let crew_count: Int?
  let witness_count: Int?
  let refinery_count: Int?
  let active_hooks: Int?
}

// MARK: - Rig List

struct RigInfo: Codable, Identifiable {
  let name: String
  let status: String?
  let witness: String?
  let refinery: String?
  let polecats: Int?
  let crew: Int?

  var id: String { name }
}

// MARK: - Mail

struct MailItem: Codable, Identifiable {
  let id: String
  let from: String?
  let to: String?
  let subject: String
  let body: String?
  let timestamp: String?
  let read: Bool?
  let priority: String?
  let type: String?
  let thread_id: String?
  let reply_to: String?

  var isUnread: Bool { !(read ?? true) }

  var formattedDate: String {
    guard let ts = timestamp else { return "" }
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = isoFormatter.date(from: ts) {
      let formatter = DateFormatter()
      formatter.dateStyle = .short
      formatter.timeStyle = .short
      return formatter.string(from: date)
    }
    // Fallback: try without fractional seconds
    isoFormatter.formatOptions = [.withInternetDateTime]
    if let date = isoFormatter.date(from: ts) {
      let formatter = DateFormatter()
      formatter.dateStyle = .short
      formatter.timeStyle = .short
      return formatter.string(from: date)
    }
    return String(ts.prefix(16))
  }
}

// MARK: - Polecats & Convoys

struct PolecatInfo: Codable, Identifiable {
  let name: String?
  let rig: String?
  let status: String?
  let bead: String?

  var id: String { "\(rig ?? "")_\(name ?? UUID().uuidString)" }
}

struct ConvoyInfo: Codable, Identifiable {
  let name: String?
  let status: String?
  let issues: [String]?

  var id: String { name ?? UUID().uuidString }
}
