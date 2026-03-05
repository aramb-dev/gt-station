import Foundation

actor GTClient {
  static let shared = GTClient()

  private let gtBinary = "/opt/homebrew/bin/gt"
  private let townRoot = "/Volumes/aramb/aramb-town"

  func run(_ args: [String]) async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: gtBinary)
    process.arguments = args
    var env = ProcessInfo.processInfo.environment
    env["HOME"] = NSHomeDirectory()
    process.environment = env
    process.currentDirectoryURL = URL(fileURLWithPath: townRoot)

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

    if process.terminationStatus != 0 {
      let errorStr = String(data: errorData, encoding: .utf8) ?? ""
      throw GTError.commandFailed(exitCode: process.terminationStatus, stderr: errorStr)
    }

    return String(data: outputData, encoding: .utf8) ?? ""
  }

  // JSON-returning commands
  func statusJSON() async throws -> TownStatus {
    let raw = try await run(["status", "--json"])
    return try JSONDecoder().decode(TownStatus.self, from: Data(raw.utf8))
  }

  func rigListJSON() async throws -> [RigInfo] {
    let raw = try await run(["rig", "list", "--json"])
    return try JSONDecoder().decode([RigInfo].self, from: Data(raw.utf8))
  }

  func mailInboxJSON() async throws -> [MailItem] {
    let raw = try await run(["mail", "inbox", "--json", "-a"])
    return try JSONDecoder().decode([MailItem].self, from: Data(raw.utf8))
  }

  func polecatListJSON() async throws -> [PolecatInfo] {
    let raw = try await run(["polecat", "list", "--all", "--json"])
    return try JSONDecoder().decode([PolecatInfo].self, from: Data(raw.utf8))
  }

  func convoyListJSON() async throws -> [ConvoyInfo] {
    let raw = try await run(["convoy", "list", "--json"])
    return try JSONDecoder().decode([ConvoyInfo].self, from: Data(raw.utf8))
  }

  // Text-returning commands (no JSON support)
  func doltStatus() async throws -> String {
    try await run(["dolt", "status"])
  }

  func mailRead(_ id: String) async throws -> String {
    try await run(["mail", "read", id])
  }

  // Actions
  func mailSend(to recipient: String, subject: String, message: String) async throws -> String {
    try await run(["mail", "send", recipient, "-s", subject, "-m", message])
  }

  func mailMarkRead(_ id: String) async throws -> String {
    try await run(["mail", "mark-read", id])
  }

  func nudge(_ target: String, message: String) async throws -> String {
    try await run(["nudge", target, message])
  }

  func doltStart() async throws -> String {
    try await run(["dolt", "start"])
  }

  func doltStop() async throws -> String {
    try await run(["dolt", "stop"])
  }

  func doltCleanup() async throws -> String {
    try await run(["dolt", "cleanup"])
  }

  func rigStart(_ rig: String) async throws -> String {
    try await run(["rig", "start", rig])
  }

  func rigStop(_ rig: String) async throws -> String {
    try await run(["rig", "stop", rig])
  }

  func rigDock(_ rig: String) async throws -> String {
    try await run(["rig", "dock", rig])
  }

  func rigUndock(_ rig: String) async throws -> String {
    try await run(["rig", "undock", rig])
  }
}

enum GTError: Error, LocalizedError {
  case commandFailed(exitCode: Int32, stderr: String)

  var errorDescription: String? {
    switch self {
    case .commandFailed(let code, let stderr):
      return "Command failed (exit \(code)): \(stderr)"
    }
  }
}
