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

  func status() async throws -> String {
    try await run(["status"])
  }

  func rigList() async throws -> String {
    try await run(["rig", "list"])
  }

  func mailInbox() async throws -> String {
    try await run(["mail", "inbox"])
  }

  func mailRead(_ id: String) async throws -> String {
    try await run(["mail", "read", id])
  }

  func mailSend(to recipient: String, subject: String, message: String) async throws -> String {
    try await run(["mail", "send", recipient, "-s", subject, "-m", message])
  }

  func mailMarkRead(_ id: String) async throws -> String {
    try await run(["mail", "mark-read", id])
  }

  func escalateList() async throws -> String {
    try await run(["escalate", "list"])
  }

  func escalateAck(_ id: String) async throws -> String {
    try await run(["escalate", "ack", id])
  }

  func escalateClose(_ id: String) async throws -> String {
    try await run(["escalate", "close", id])
  }

  func doltStatus() async throws -> String {
    try await run(["dolt", "status"])
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

  func polecatList() async throws -> String {
    try await run(["polecat", "list"])
  }

  func convoyList() async throws -> String {
    try await run(["convoy", "list"])
  }

  func nudge(_ target: String, message: String) async throws -> String {
    try await run(["nudge", target, message])
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
