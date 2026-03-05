import Foundation
import Combine

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

    async let statusTask = client.statusJSON()
    async let rigsTask = client.rigListJSON()
    async let mailTask = client.mailInboxJSON()
    async let doltTask = client.doltStatus()
    async let polecatTask = client.polecatListJSON()
    async let convoyTask = client.convoyListJSON()

    townStatus = try? await statusTask
    rigs = (try? await rigsTask) ?? []
    mailItems = (try? await mailTask) ?? []
    doltStatusText = (try? await doltTask) ?? "Error fetching status"
    polecats = (try? await polecatTask) ?? []
    convoys = (try? await convoyTask) ?? []

    lastRefresh = Date()
    isLoading = false
  }

  // Derived properties
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
