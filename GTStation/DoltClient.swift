import Foundation
import MySQLNIO
import NIOPosix
import Logging

actor DoltClient {
  static let shared = DoltClient()

  private let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
  private var connection: MySQLConnection?
  private var logger = Logger(label: "town.gastown.dolt")

  private let host = "127.0.0.1"
  private let port = 3307
  private let username = "root"
  private let database = "hq"

  deinit {
    try? eventLoopGroup.syncShutdownGracefully()
  }

  private func getConnection() async throws -> MySQLConnection {
    if let conn = connection, !conn.isClosed {
      return conn
    }
    let conn = try await MySQLConnection.connect(
      to: .makeAddressResolvingHost(host, port: port),
      username: username,
      database: database,
      password: "",
      tlsConfiguration: nil,
      on: eventLoopGroup.next()
    ).get()
    connection = conn
    return conn
  }

  func close() async {
    try? await connection?.close().get()
    connection = nil
  }

  // MARK: - Mail Queries

  func fetchMail(identity: String) async throws -> [MailItem] {
    let conn = try await getConnection()

    // Mail = wisps with gt:message label, assigned to identity
    let rows = try await conn.query(
      """
      SELECT w.id, w.title, w.description, w.created_at, w.priority, w.assignee
      FROM wisps w
      INNER JOIN wisp_labels wl ON wl.issue_id = w.id AND wl.label = 'gt:message'
      WHERE w.assignee = ?
      ORDER BY w.created_at DESC
      """,
      [MySQLData(string: identity)]
    ).get()

    var items: [MailItem] = []
    for row in rows {
      let id = row.column("id")?.string ?? ""
      let subject = row.column("title")?.string ?? ""
      let body = row.column("description")?.string
      let createdAt = row.column("created_at")?.string
      let priorityVal = row.column("priority")?.int

      // Fetch labels for this wisp to extract mail metadata
      let labelRows = try await conn.query(
        "SELECT label FROM wisp_labels WHERE issue_id = ?",
        [MySQLData(string: id)]
      ).get()

      var from: String?
      var threadId: String?
      var replyTo: String?
      var isRead = false
      var mailType: String?
      var priorityStr: String?

      for lr in labelRows {
        guard let label = lr.column("label")?.string else { continue }
        if label.hasPrefix("from:") {
          from = String(label.dropFirst(5))
        } else if label.hasPrefix("thread:") {
          threadId = String(label.dropFirst(7))
        } else if label.hasPrefix("reply-to:") {
          replyTo = String(label.dropFirst(9))
        } else if label == "read" {
          isRead = true
        } else if label.hasPrefix("priority:") {
          priorityStr = String(label.dropFirst(9))
        }
      }

      // Map numeric priority to string if no label
      if priorityStr == nil, let p = priorityVal {
        switch p {
        case 0: priorityStr = "critical"
        case 1: priorityStr = "urgent"
        case 2: priorityStr = "normal"
        default: priorityStr = "low"
        }
      }

      // Format timestamp for ISO8601
      var timestamp: String?
      if let ts = createdAt {
        timestamp = ts.hasSuffix("Z") ? ts : ts + "Z"
      }

      items.append(MailItem(
        id: id,
        from: from,
        to: identity,
        subject: subject,
        body: body,
        timestamp: timestamp,
        read: isRead,
        priority: priorityStr,
        type: mailType,
        thread_id: threadId,
        reply_to: replyTo
      ))
    }

    return items
  }

  func fetchUnreadCount(identity: String) async throws -> Int {
    let conn = try await getConnection()

    let rows = try await conn.query(
      """
      SELECT COUNT(*) AS cnt
      FROM wisps w
      INNER JOIN wisp_labels msg ON msg.issue_id = w.id AND msg.label = 'gt:message'
      LEFT JOIN wisp_labels rd ON rd.issue_id = w.id AND rd.label = 'read'
      WHERE w.assignee = ? AND rd.label IS NULL
      """,
      [MySQLData(string: identity)]
    ).get()

    return rows.first?.column("cnt")?.int ?? 0
  }
}
