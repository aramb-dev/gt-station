import Foundation
import Combine
import UserNotifications

@MainActor
class AppState: ObservableObject {
  @Published var townStatus: TownStatus? = nil
  @Published var rigs: [RigInfo] = []
  @Published var mailItems: [MailItem] = []
  @Published var polecats: [PolecatInfo] = []
  @Published var convoys: [ConvoyInfo] = []
  @Published var doltStatusText: String = ""
  @Published var isLoading: Bool = false
  @Published var lastError: String? = nil
  @Published var lastRefresh: Date? = nil

  // Track known mail IDs to detect new arrivals
  private var knownMailIds: Set<String> = []
  private var isFirstLoad = true

  private var refreshTimer: Timer?
  private let client = GTClient.shared

  init() {
    requestNotificationPermission()
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

    async let statusTask = client.statusJSON()
    async let rigsTask = client.rigListJSON()
    async let mailTask = client.mailInboxJSON(identity: "overseer")
    async let doltTask = client.doltStatus()
    async let polecatTask = client.polecatListJSON()
    async let convoyTask = client.convoyListJSON()

    townStatus = try? await statusTask
    rigs = (try? await rigsTask) ?? []
    let newMail = (try? await mailTask) ?? []
    doltStatusText = (try? await doltTask) ?? "Error fetching status"
    polecats = (try? await polecatTask) ?? []
    convoys = (try? await convoyTask) ?? []

    // Detect new messages and send notifications
    if !isFirstLoad {
      let newIds = Set(newMail.map { $0.id })
      let arrivals = newMail.filter { !knownMailIds.contains($0.id) && $0.isUnread }
      for item in arrivals {
        sendNewMailNotification(item)
      }
      knownMailIds = newIds
    } else {
      knownMailIds = Set(newMail.map { $0.id })
      isFirstLoad = false
    }

    mailItems = newMail

    // Update address cache
    AddressCache.shared.update(from: mailItems, townStatus: townStatus)

    lastRefresh = Date()
    isLoading = false
  }

  // MARK: - Notifications

  private func requestNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
  }

  private func sendNewMailNotification(_ item: MailItem) {
    let content = UNMutableNotificationContent()
    content.title = "New Mail: \(item.subject)"
    content.body = "From \(item.from ?? "unknown")"
    content.sound = .default

    if let priority = item.priority, priority == "urgent" || priority == "high" {
      content.interruptionLevel = .timeSensitive
    }

    let request = UNNotificationRequest(
      identifier: "mail-\(item.id)",
      content: content,
      trigger: nil // Deliver immediately
    )
    UNUserNotificationCenter.current().add(request)
  }

  func sendEscalationNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .defaultCritical
    content.interruptionLevel = .critical

    let request = UNNotificationRequest(
      identifier: "escalation-\(UUID().uuidString)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }

  // MARK: - Derived properties

  var unreadMailCount: Int {
    mailItems.filter { $0.isUnread }.count
  }

  var isDoltRunning: Bool {
    townStatus?.dolt?.running ?? false
  }

  var isDaemonRunning: Bool {
    townStatus?.daemon?.running ?? false
  }

  var rigCount: Int {
    townStatus?.summary?.rig_count ?? rigs.count
  }

  var activePolecatCount: Int {
    townStatus?.summary?.polecat_count ?? polecats.count
  }
}
