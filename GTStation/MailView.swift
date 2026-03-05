import SwiftUI

// MARK: - Thread Model

struct MailThread: Identifiable {
  let id: String // thread_id
  let messages: [MailItem]

  var latestMessage: MailItem {
    messages.first!
  }

  var subject: String {
    // Use the first non-"Re:" subject, or fall back to latest
    let original = messages.last(where: { !$0.subject.hasPrefix("Re:") })
    return original?.subject ?? latestMessage.subject
  }

  var hasUnread: Bool {
    messages.contains { $0.isUnread }
  }

  var unreadCount: Int {
    messages.filter { $0.isUnread }.count
  }

  var latestDate: String {
    latestMessage.formattedDate
  }

  var participants: [String] {
    Array(Set(messages.compactMap { $0.from }))
  }
}

// MARK: - Mail View

struct MailView: View {
  @EnvironmentObject var appState: AppState
  @State private var selectedThreadId: String? = nil
  @State private var selectedMessageId: String? = nil
  @State private var selectedContent: String = ""
  @State private var isLoadingContent: Bool = false
  @State private var bodyCache: [String: String] = [:]  // id → stripped body
  @State private var showCompose: Bool = false
  @State private var replyContext: ReplyContext? = nil
  @State private var actionFeedback: String? = nil

  struct ReplyContext {
    let to: String
    let subject: String
    let replyToId: String
  }

  private var threads: [MailThread] {
    let grouped = Dictionary(grouping: appState.mailItems) { item in
      item.thread_id ?? item.id
    }
    return grouped.map { (threadId, messages) in
      MailThread(
        id: threadId,
        messages: messages.sorted { ($0.timestamp ?? "") > ($1.timestamp ?? "") }
      )
    }
    .sorted { ($0.latestMessage.timestamp ?? "") > ($1.latestMessage.timestamp ?? "") }
  }

  private var selectedThread: MailThread? {
    threads.first { $0.id == selectedThreadId }
  }

  var body: some View {
    HSplitView {
      // Thread list
      VStack(spacing: 0) {
        // Header
        HStack(alignment: .center) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Inbox")
              .font(.title3)
              .fontWeight(.semibold)
            if appState.unreadMailCount > 0 {
              Text("\(appState.unreadMailCount) unread, \(threads.count) threads")
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
              Text("\(threads.count) threads")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          Spacer()
          Button {
            replyContext = nil
            showCompose = true
          } label: {
            Image(systemName: "square.and.pencil")
              .font(.title3)
          }
          .buttonStyle(.plain)
          .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        Divider()

        if threads.isEmpty {
          VStack(spacing: 12) {
            Image(systemName: "tray")
              .font(.system(size: 36))
              .foregroundStyle(.quaternary)
            Text("No messages")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          List(threads, selection: $selectedThreadId) { thread in
            ThreadListRow(thread: thread)
              .tag(thread.id)
          }
          .listStyle(.inset)
        }
      }
      .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
      .onChange(of: selectedThreadId) { _, newId in
        selectedMessageId = nil
        selectedContent = ""
        if let thread = threads.first(where: { $0.id == newId }),
           let first = thread.messages.first {
          selectedMessageId = first.id
          Task { await loadMailContent(id: first.id) }
          // Pre-warm remaining messages in thread concurrently
          for msg in thread.messages.dropFirst() where bodyCache[msg.id] == nil {
            Task { await loadMailContent(id: msg.id) }
          }
        }
      }

      // Thread detail
      VStack(spacing: 0) {
        if let feedback = actionFeedback {
          HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(.green)
            Text(feedback)
              .font(.callout)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.green.opacity(0.08))
        }

        if isLoadingContent && selectedThread == nil {
          VStack(spacing: 12) {
            ProgressView()
              .scaleEffect(0.8)
            Text("Loading...")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let thread = selectedThread {
          ThreadDetailView(
            thread: thread,
            selectedMessageId: $selectedMessageId,
            selectedContent: $selectedContent,
            isLoadingContent: isLoadingContent,
            onLoadMessage: { id in await loadMailContent(id: id) },
            onReply: { item in
              replyContext = ReplyContext(
                to: item.from ?? "unknown",
                subject: item.subject.hasPrefix("Re:") ? item.subject : "Re: \(item.subject)",
                replyToId: item.id
              )
              showCompose = true
            },
            onMarkRead: { id in await markRead(id: id) }
          )
        } else {
          VStack(spacing: 12) {
            Image(systemName: "envelope.open")
              .font(.system(size: 40))
              .foregroundStyle(.quaternary)
            Text("Select a conversation")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .frame(minWidth: 420)
    }
    .sheet(isPresented: $showCompose) {
      ComposeMailView(
        isPresented: $showCompose,
        prefillTo: replyContext?.to ?? "",
        prefillSubject: replyContext?.subject ?? "",
        replyToId: replyContext?.replyToId
      )
      .environmentObject(appState)
    }
  }

  private func loadMailContent(id: String) async {
    // Serve from cache instantly if already fetched
    if let cached = bodyCache[id] {
      selectedContent = cached
      return
    }
    isLoadingContent = true
    do {
      let raw = try await GTClient.shared.mailRead(id)
      let body = stripMailHeaders(raw)
      bodyCache[id] = body
      selectedContent = body
    } catch {
      selectedContent = "Error: \(error.localizedDescription)"
    }
    isLoadingContent = false
  }

  private func markRead(id: String) async {
    do {
      _ = try await GTClient.shared.mailMarkRead(id)
      actionFeedback = "Marked as read"
      await appState.refresh()
      try? await Task.sleep(for: .seconds(2))
      actionFeedback = nil
    } catch {
      actionFeedback = "Error: \(error.localizedDescription)"
    }
  }
}

// MARK: - Thread List Row

struct ThreadListRow: View {
  let thread: MailThread

  var body: some View {
    HStack(spacing: 10) {
      // Unread indicator
      Circle()
        .fill(thread.hasUnread ? .blue : .clear)
        .frame(width: 8, height: 8)

      // Avatar
      ZStack {
        Circle()
          .fill(avatarColor.opacity(0.15))
          .frame(width: 32, height: 32)
        Text(avatarInitial)
          .font(.system(.caption, design: .rounded, weight: .semibold))
          .foregroundStyle(avatarColor)
      }

      VStack(alignment: .leading, spacing: 3) {
        HStack {
          Text(thread.participants.map { ContactStore.shared.resolveDisplayName(for: $0) }.joined(separator: ", "))
            .font(.callout)
            .fontWeight(thread.hasUnread ? .semibold : .regular)
            .lineLimit(1)
          Spacer()
          Text(thread.latestDate)
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        Text(thread.subject)
          .font(.subheadline)
          .foregroundStyle(thread.hasUnread ? .primary : .secondary)
          .lineLimit(1)
        if let body = thread.latestMessage.body {
          Text(body)
            .font(.caption)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
        }
      }

      // Message count badge
      if thread.messages.count > 1 {
        Text("\(thread.messages.count)")
          .font(.caption2)
          .fontWeight(.bold)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(.secondary.opacity(0.12), in: Capsule())
      }
    }
    .padding(.vertical, 4)
  }

  private var avatarInitial: String {
    let name = thread.latestMessage.from ?? "?"
    return String(name.prefix(1)).uppercased()
  }

  private var avatarColor: Color {
    let name = thread.latestMessage.from ?? ""
    return colorForSender(name)
  }
}

// MARK: - Thread Detail View

struct ThreadDetailView: View {
  let thread: MailThread
  @Binding var selectedMessageId: String?
  @Binding var selectedContent: String
  let isLoadingContent: Bool
  let onLoadMessage: (String) async -> Void
  let onReply: (MailItem) -> Void
  let onMarkRead: (String) async -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Thread header
      HStack {
        Text(thread.subject)
          .font(.title2)
          .fontWeight(.semibold)
          .lineLimit(2)
          .textSelection(.enabled)
        Spacer()
        Text("\(thread.messages.count) messages")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(16)
      .background(.secondary.opacity(0.04))

      Divider()

      // Messages in thread
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(thread.messages.reversed(), id: \.id) { message in
            ThreadMessageRow(
              message: message,
              isSelected: message.id == selectedMessageId,
              content: message.id == selectedMessageId ? selectedContent : nil,
              isLoading: message.id == selectedMessageId && isLoadingContent,
              onSelect: {
                selectedMessageId = message.id
                Task { await onLoadMessage(message.id) }
              },
              onReply: { onReply(message) },
              onMarkRead: { Task { await onMarkRead(message.id) } }
            )
            Divider()
          }
        }
      }

      Divider()

      // Reply bar
      HStack(spacing: 12) {
        Button {
          if let latest = thread.messages.first {
            onReply(latest)
          }
        } label: {
          Label("Reply", systemImage: "arrowshape.turn.up.left")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
    }
  }
}

// MARK: - Thread Message Row

struct ThreadMessageRow: View {
  let message: MailItem
  let isSelected: Bool
  let content: String?
  let isLoading: Bool
  let onSelect: () -> Void
  let onReply: () -> Void
  let onMarkRead: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Message header (always visible)
      Button(action: onSelect) {
        HStack(spacing: 10) {
          // Unread dot
          Circle()
            .fill(message.isUnread ? .blue : .clear)
            .frame(width: 6, height: 6)

          // Avatar
          ZStack {
            Circle()
              .fill(colorForSender(message.from ?? "").opacity(0.15))
              .frame(width: 28, height: 28)
            Text(String((message.from ?? "?").prefix(1)).uppercased())
              .font(.system(.caption2, design: .rounded, weight: .bold))
              .foregroundStyle(colorForSender(message.from ?? ""))
          }

          VStack(alignment: .leading, spacing: 1) {
            HStack {
              Text(ContactStore.shared.resolveDisplayName(for: message.from ?? "unknown"))
                .font(.callout)
                .fontWeight(message.isUnread ? .semibold : .medium)
              if let to = message.to {
                Text("to \(ContactStore.shared.resolveDisplayName(for: to))")
                  .font(.caption2)
                  .foregroundStyle(.tertiary)
              }
            }
            Text(message.formattedDate)
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }

          Spacer()

          if let priority = message.priority, priority != "normal" {
            PriorityBadge(priority: priority)
          }

          Image(systemName: isSelected ? "chevron.down" : "chevron.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .background(isSelected ? Color.secondary.opacity(0.06) : Color.clear)

      // Expanded content
      if isSelected {
        VStack(alignment: .leading, spacing: 0) {
          if isLoading {
            HStack {
              ProgressView()
                .scaleEffect(0.7)
              Text("Loading...")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 12)
          } else if let content {
            Text(content)
              .font(.system(.body))
              .lineSpacing(5)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 56)
              .padding(.vertical, 12)
              .textSelection(.enabled)

            // Per-message actions
            HStack(spacing: 10) {
              Button {
                onReply()
              } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
              }
              .buttonStyle(.bordered)
              .controlSize(.mini)

              if message.isUnread {
                Button {
                  onMarkRead()
                } label: {
                  Label("Mark Read", systemImage: "envelope.open")
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
              }

              Spacer()
            }
            .padding(.horizontal, 56)
            .padding(.bottom, 12)
          }
        }
        .background(.secondary.opacity(0.03))
      }
    }
  }
}

// MARK: - Priority Badge

struct PriorityBadge: View {
  let priority: String

  var body: some View {
    Text(priority.uppercased())
      .font(.system(.caption2, design: .rounded, weight: .bold))
      .padding(.horizontal, 7)
      .padding(.vertical, 3)
      .background(badgeColor.opacity(0.15), in: Capsule())
      .foregroundStyle(badgeColor)
  }

  private var badgeColor: Color {
    switch priority.lowercased() {
    case "urgent": return .red
    case "high": return .orange
    case "low": return .secondary
    default: return .blue
    }
  }
}

// MARK: - Compose

struct ComposeMailView: View {
  @Binding var isPresented: Bool
  @EnvironmentObject var appState: AppState
  @ObservedObject private var addressCache = AddressCache.shared
  @State private var to: String
  @State private var subject: String
  @State private var message: String = ""
  @State private var isSending: Bool = false
  @State private var feedback: String? = nil
  @State private var showSuggestions: Bool = false
  private let replyToId: String?

  init(isPresented: Binding<Bool>, prefillTo: String = "", prefillSubject: String = "", replyToId: String? = nil) {
    _isPresented = isPresented
    _to = State(initialValue: prefillTo)
    _subject = State(initialValue: prefillSubject)
    self.replyToId = replyToId
  }

  var isReply: Bool { replyToId != nil }

  private var suggestions: [AddressCache.CachedAddress] {
    addressCache.search(to)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text(isReply ? "Reply" : "New Message")
          .font(.title3)
          .fontWeight(.semibold)
        Spacer()
        Button {
          isPresented = false
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.title3)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }

      VStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text("To")
              .font(.callout)
              .foregroundStyle(.secondary)
              .frame(width: 60, alignment: .trailing)
            TextField("e.g. overseer, mayor/", text: $to)
              .textFieldStyle(.roundedBorder)
              .onChange(of: to) { _, newValue in
                showSuggestions = !newValue.isEmpty && !suggestions.isEmpty
              }
          }

          // Address suggestions dropdown
          if showSuggestions && !suggestions.isEmpty {
            VStack(spacing: 0) {
              ForEach(suggestions.prefix(5)) { addr in
                Button {
                  to = addr.address
                  showSuggestions = false
                } label: {
                  HStack {
                    Text(addr.address)
                      .font(.callout)
                      .fontWeight(.medium)
                    if addr.displayName != addr.address {
                      Text(addr.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if addr.useCount > 0 {
                      Text("\(addr.useCount)x")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                  }
                  .padding(.horizontal, 10)
                  .padding(.vertical, 6)
                  .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider()
              }
            }
            .background(.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.secondary.opacity(0.12), lineWidth: 1)
            )
            .padding(.leading, 68)
          }
        }

        HStack {
          Text("Subject")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(width: 60, alignment: .trailing)
          TextField("Subject", text: $subject)
            .textFieldStyle(.roundedBorder)
        }
      }

      TextEditor(text: $message)
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 140)
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(.secondary.opacity(0.2), lineWidth: 1)
        )

      if let feedback {
        HStack(spacing: 6) {
          Image(systemName: feedback.hasPrefix("Error") ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
            .foregroundStyle(feedback.hasPrefix("Error") ? .red : .green)
          Text(feedback)
            .font(.callout)
        }
      }

      HStack {
        Spacer()
        Button("Cancel") { isPresented = false }
          .keyboardShortcut(.cancelAction)
        Button(isReply ? "Send Reply" : "Send") {
          Task { await send() }
        }
        .disabled(to.isEmpty || subject.isEmpty || message.isEmpty || isSending)
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 500, height: 440)
  }

  private func send() async {
    isSending = true
    do {
      _ = try await GTClient.shared.mailSend(to: to, subject: subject, message: message, replyTo: replyToId)
      AddressCache.shared.recordSend(to: to)
      feedback = "Sent!"
      await appState.refresh()
      try? await Task.sleep(for: .seconds(1))
      isPresented = false
    } catch {
      feedback = "Error: \(error.localizedDescription)"
    }
    isSending = false
  }
}

// MARK: - Helpers

func colorForSender(_ name: String) -> Color {
  switch name.lowercased() {
  case "overseer": return .purple
  case let n where n.contains("witness"): return .orange
  case let n where n.contains("refinery"): return .teal
  case let n where n.contains("deacon"): return .green
  case let n where n.contains("mayor"): return .indigo
  default: return .blue
  }
}

/// Strip technical headers from `gt mail read` output.
/// Headers may appear in multiple blocks separated by blank lines.
/// Body starts after the last header line.
func stripMailHeaders(_ raw: String) -> String {
  let lines = raw.split(separator: "\n", omittingEmptySubsequences: false)
  let headerPrefixes = ["Subject:", "From:", "To:", "Date:", "ID:", "Thread:", "Reply-To:", "CC:", "Priority:", "Type:"]

  // Find the last line that is a known header
  var lastHeaderLine = -1
  for (i, line) in lines.enumerated() {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if headerPrefixes.contains(where: { trimmed.hasPrefix($0) }) {
      lastHeaderLine = i
    }
  }

  if lastHeaderLine < 0 { return raw }

  // Skip blank lines after the last header to find body start
  var bodyStart = lastHeaderLine + 1
  while bodyStart < lines.count && lines[bodyStart].trimmingCharacters(in: .whitespaces).isEmpty {
    bodyStart += 1
  }

  if bodyStart >= lines.count { return raw }
  return lines[bodyStart...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
}
