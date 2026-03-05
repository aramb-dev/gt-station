import SwiftUI

// MARK: - Local message history

struct NudgeMessage: Codable, Identifiable {
  let id: UUID
  let to: String
  let text: String
  let timestamp: Date
  let mode: String
  let priority: String

  init(to: String, text: String, mode: String = "immediate", priority: String = "normal") {
    self.id = UUID()
    self.to = to
    self.text = text
    self.timestamp = Date()
    self.mode = mode
    self.priority = priority
  }
}

class NudgeHistory: ObservableObject {
  static let shared = NudgeHistory()

  @Published var messages: [NudgeMessage] = []

  private let storeURL: URL = {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
      .appendingPathComponent("GasStation", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("nudge-history.json")
  }()

  init() { load() }

  func append(_ msg: NudgeMessage) {
    messages.append(msg)
    save()
  }

  func messages(to target: String) -> [NudgeMessage] {
    messages.filter { $0.to == target }
  }

  private func save() {
    if let data = try? JSONEncoder().encode(messages) {
      try? data.write(to: storeURL, options: .atomic)
    }
  }

  private func load() {
    guard let data = try? Data(contentsOf: storeURL),
          let loaded = try? JSONDecoder().decode([NudgeMessage].self, from: data)
    else { return }
    messages = loaded
  }
}

// MARK: - Agent entry

struct NudgeAgent: Identifiable, Hashable {
  let id: String    // address
  let name: String
  let role: String
  let isRunning: Bool
}

// MARK: - NudgeView

struct NudgeView: View {
  @EnvironmentObject var appState: AppState
  @ObservedObject private var history = NudgeHistory.shared
  @State private var selectedId: String? = nil
  @State private var searchText: String = ""

  private var agents: [NudgeAgent] {
    var result: [NudgeAgent] = []
    // Town-level agents
    if let list = appState.townStatus?.agents {
      for a in list {
        let addr = a.address ?? a.name
        result.append(NudgeAgent(id: addr, name: a.name, role: a.role ?? "agent", isRunning: a.running))
      }
    }
    // Rig agents
    if let rigs = appState.townStatus?.rigs {
      for rig in rigs {
        for a in rig.agents ?? [] {
          let addr = a.address ?? "\(rig.name)/\(a.name)"
          result.append(NudgeAgent(id: addr, name: a.name, role: "\(a.role ?? "agent") · \(rig.name)", isRunning: a.running))
        }
      }
    }
    return result
  }

  private var filteredAgents: [NudgeAgent] {
    guard !searchText.isEmpty else { return agents }
    let q = searchText.lowercased()
    return agents.filter {
      $0.name.lowercased().contains(q) ||
      $0.id.lowercased().contains(q) ||
      $0.role.lowercased().contains(q)
    }
  }

  private var selectedAgent: NudgeAgent? {
    agents.first { $0.id == selectedId }
  }

  var body: some View {
    HSplitView {
      agentList
        .frame(minWidth: 220, idealWidth: 240, maxWidth: 300)

      if let agent = selectedAgent {
        ChatPanel(agent: agent)
          .frame(minWidth: 420)
      } else {
        emptyState
          .frame(minWidth: 420)
      }
    }
  }

  // MARK: Agent list

  private var agentList: some View {
    VStack(spacing: 0) {
      // Search bar
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.tertiary)
          .font(.callout)
        TextField("Search", text: $searchText)
          .textFieldStyle(.plain)
          .font(.callout)
      }
      .padding(8)
      .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      .padding(.horizontal, 12)
      .padding(.top, 12)
      .padding(.bottom, 8)

      Divider()

      if filteredAgents.isEmpty {
        Spacer()
        Text("No agents found")
          .font(.callout)
          .foregroundStyle(.secondary)
        Spacer()
      } else {
        List(filteredAgents, selection: $selectedId) { agent in
          AgentRow(agent: agent, unread: history.messages(to: agent.id).count)
            .tag(agent.id)
        }
        .listStyle(.inset)
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 10) {
      Image(systemName: "bubble.left.and.bubble.right")
        .font(.system(size: 40))
        .foregroundStyle(.quaternary)
      Text("Pick an agent to nudge")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Agent Row

struct AgentRow: View {
  let agent: NudgeAgent
  let unread: Int

  var body: some View {
    HStack(spacing: 10) {
      ZStack {
        Circle()
          .fill(agentColor.opacity(0.14))
          .frame(width: 32, height: 32)
        Text(String(agent.name.prefix(1)).uppercased())
          .font(.system(.caption, design: .rounded, weight: .bold))
          .foregroundStyle(agentColor)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(ContactStore.shared.resolveDisplayName(for: agent.id))
          .font(.callout)
          .fontWeight(.medium)
          .lineLimit(1)
        Text(agent.role)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer()

      Circle()
        .fill(agent.isRunning ? .green : .secondary.opacity(0.3))
        .frame(width: 7, height: 7)
    }
    .padding(.vertical, 2)
  }

  private var agentColor: Color {
    colorForSender(agent.id)
  }
}

// MARK: - Chat Panel

struct ChatPanel: View {
  let agent: NudgeAgent
  @ObservedObject private var history = NudgeHistory.shared
  @State private var input: String = ""
  @State private var isSending: Bool = false
  @State private var errorText: String? = nil
  @FocusState private var inputFocused: Bool

  // Delivery options
  @State private var mode: String = "immediate"
  @State private var priority: String = "normal"
  @State private var force: Bool = false
  @State private var ifFresh: Bool = false
  @State private var showOptions: Bool = false

  private var thread: [NudgeMessage] {
    history.messages(to: agent.id)
  }

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack(spacing: 10) {
        ZStack {
          Circle()
            .fill(colorForSender(agent.id).opacity(0.14))
            .frame(width: 36, height: 36)
          Text(String(agent.name.prefix(1)).uppercased())
            .font(.system(.callout, design: .rounded, weight: .bold))
            .foregroundStyle(colorForSender(agent.id))
        }

        VStack(alignment: .leading, spacing: 1) {
          Text(ContactStore.shared.resolveDisplayName(for: agent.id))
            .font(.headline)
          HStack(spacing: 4) {
            Circle()
              .fill(agent.isRunning ? .green : .secondary.opacity(0.4))
              .frame(width: 6, height: 6)
            Text(agent.isRunning ? "active" : "offline")
              .font(.caption2)
              .foregroundStyle(.secondary)
            Text("·")
              .font(.caption2)
              .foregroundStyle(.tertiary)
            Text(agent.id)
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
        }

        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(.secondary.opacity(0.04))

      Divider()

      // Messages
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(alignment: .trailing, spacing: 4) {
            if thread.isEmpty {
              VStack(spacing: 8) {
                Image(systemName: "bubble.right")
                  .font(.system(size: 28))
                  .foregroundStyle(.quaternary)
                Text("No nudges sent yet")
                  .font(.callout)
                  .foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity)
              .padding(.top, 60)
            } else {
              ForEach(thread) { msg in
                BubbleView(message: msg)
                  .id(msg.id)
              }
              .padding(.horizontal, 16)
              .padding(.top, 12)
            }
          }
          .padding(.bottom, 8)
        }
        .onChange(of: thread.count) { _, _ in
          if let last = thread.last {
            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
          }
        }
        .onAppear {
          if let last = thread.last {
            proxy.scrollTo(last.id, anchor: .bottom)
          }
        }
      }

      // Error
      if let err = errorText {
        Text(err)
          .font(.caption)
          .foregroundStyle(.red)
          .padding(.horizontal, 16)
          .padding(.bottom, 4)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Divider()

      // Options row (collapsed by default)
      if showOptions {
        HStack(spacing: 8) {
          // Mode picker
          Picker("", selection: $mode) {
            Text("immediate").tag("immediate")
            Text("queue").tag("queue")
            Text("wait-idle").tag("wait-idle")
          }
          .pickerStyle(.segmented)
          .frame(maxWidth: 240)

          Divider().frame(height: 16)

          // Priority
          Picker("", selection: $priority) {
            Text("normal").tag("normal")
            Text("urgent").tag("urgent")
          }
          .pickerStyle(.segmented)
          .frame(maxWidth: 130)

          Divider().frame(height: 16)

          // Toggles
          Toggle("force", isOn: $force)
            .toggleStyle(.checkbox)
            .font(.caption)
          Toggle("if-fresh", isOn: $ifFresh)
            .toggleStyle(.checkbox)
            .font(.caption)

          Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.secondary.opacity(0.04))
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }

      // Input bar
      HStack(spacing: 8) {
        // Options toggle
        Button {
          withAnimation(.spring(duration: 0.2)) { showOptions.toggle() }
        } label: {
          Image(systemName: "slider.horizontal.3")
            .font(.system(size: 16))
            .foregroundColor(showOptions ? .blue : .secondary)
        }
        .buttonStyle(.plain)
        .help("Delivery options")

        TextField("Nudge \(ContactStore.shared.resolveDisplayName(for: agent.id))…", text: $input, axis: .vertical)
          .textFieldStyle(.plain)
          .font(.body)
          .lineLimit(1...4)
          .focused($inputFocused)
          .onSubmit {
            if !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              Task { await send() }
            }
          }

        Button {
          Task { await send() }
        } label: {
          Image(systemName: isSending ? "clock" : "arrow.up.circle.fill")
            .font(.system(size: 26))
            .foregroundColor(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .blue)
        }
        .buttonStyle(.plain)
        .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
    }
    .onAppear { inputFocused = true }
  }

  private func send() async {
    let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    isSending = true
    errorText = nil
    input = ""
    // gt nudge rejects trailing slashes (e.g. "deacon/" → "deacon")
    let target = agent.id.hasSuffix("/") ? String(agent.id.dropLast()) : agent.id
    do {
      _ = try await GTClient.shared.nudge(target, message: text, mode: mode, priority: priority, force: force, ifFresh: ifFresh)
      history.append(NudgeMessage(to: agent.id, text: text, mode: mode, priority: priority))
    } catch {
      errorText = error.localizedDescription
      input = text // restore on failure
    }
    isSending = false
  }
}

// MARK: - Bubble

struct BubbleView: View {
  let message: NudgeMessage

  private var timeString: String {
    let f = DateFormatter()
    f.timeStyle = .short
    f.dateStyle = Calendar.current.isDateInToday(message.timestamp) ? .none : .short
    return f.string(from: message.timestamp)
  }

  var body: some View {
    VStack(alignment: .trailing, spacing: 2) {
      Text(message.text)
        .font(.body)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(bubbleColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(maxWidth: 360, alignment: .trailing)

      HStack(spacing: 4) {
        if message.mode != "immediate" {
          Text(message.mode)
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        if message.priority == "urgent" {
          Text("urgent")
            .font(.caption2)
            .foregroundStyle(.orange)
        }
        Text(timeString)
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
      .padding(.trailing, 4)
    }
  }

  private var bubbleColor: Color {
    message.priority == "urgent" ? .orange : .blue
  }
}
