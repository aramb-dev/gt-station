import Foundation

/// Caches known recipient addresses from mail history and town agents.
/// Persists to disk for near-instant compose autocomplete.
class AddressCache: ObservableObject {
  static let shared = AddressCache()

  @Published private(set) var addresses: [CachedAddress] = []

  private let cacheURL: URL = {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let dir = appSupport.appendingPathComponent("GasStation", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("address-cache.json")
  }()

  init() {
    load()
  }

  struct CachedAddress: Codable, Identifiable, Hashable {
    let address: String
    let displayName: String
    var lastUsed: Date
    var useCount: Int

    var id: String { address }
  }

  /// Update cache from mail items and town status
  func update(from mailItems: [MailItem], townStatus: TownStatus?) {
    var known = Dictionary(uniqueKeysWithValues: addresses.map { ($0.address, $0) })

    // Extract addresses from mail
    for item in mailItems {
      if let from = item.from, !from.isEmpty {
        addOrUpdate(&known, address: from, displayName: from)
      }
      if let to = item.to, !to.isEmpty {
        addOrUpdate(&known, address: to, displayName: to)
      }
    }

    // Extract addresses from town agents
    if let agents = townStatus?.agents {
      for agent in agents {
        if let addr = agent.address {
          addOrUpdate(&known, address: addr, displayName: "\(agent.name) (\(agent.role ?? "agent"))")
        }
      }
    }
    if let rigs = townStatus?.rigs {
      for rig in rigs {
        if let agents = rig.agents {
          for agent in agents {
            if let addr = agent.address {
              addOrUpdate(&known, address: addr, displayName: "\(agent.name) in \(rig.name)")
            }
          }
        }
      }
    }

    // Always include overseer
    addOrUpdate(&known, address: "overseer", displayName: "Overseer")

    addresses = known.values
      .sorted { $0.useCount > $1.useCount }
    save()
  }

  /// Record that an address was used for sending
  func recordSend(to address: String) {
    var known = Dictionary(uniqueKeysWithValues: addresses.map { ($0.address, $0) })
    if var existing = known[address] {
      existing.lastUsed = Date()
      existing.useCount += 1
      known[address] = existing
    } else {
      known[address] = CachedAddress(address: address, displayName: address, lastUsed: Date(), useCount: 1)
    }
    addresses = known.values.sorted { $0.useCount > $1.useCount }
    save()
  }

  /// Search addresses by prefix
  func search(_ query: String) -> [CachedAddress] {
    if query.isEmpty { return addresses }
    let q = query.lowercased()
    return addresses.filter {
      $0.address.lowercased().contains(q) || $0.displayName.lowercased().contains(q)
    }
  }

  // MARK: - Private

  private func addOrUpdate(_ dict: inout [String: CachedAddress], address: String, displayName: String) {
    if dict[address] == nil {
      dict[address] = CachedAddress(address: address, displayName: displayName, lastUsed: Date(), useCount: 0)
    }
  }

  private func save() {
    if let data = try? JSONEncoder().encode(addresses) {
      try? data.write(to: cacheURL, options: .atomic)
    }
  }

  private func load() {
    guard let data = try? Data(contentsOf: cacheURL),
          let cached = try? JSONDecoder().decode([CachedAddress].self, from: data) else { return }
    addresses = cached
  }
}
