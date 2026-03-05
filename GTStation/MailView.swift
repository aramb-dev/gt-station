import SwiftUI

struct MailView: View {
  @EnvironmentObject var appState: AppState
  @State private var selectedMailId: String? = nil
  @State private var selectedContent: String = ""
  @State private var isLoadingContent: Bool = false
  @State private var showCompose: Bool = false
  @State private var actionFeedback: String? = nil

  var body: some View {
    HSplitView {
      // Mail list
      VStack(spacing: 0) {
        // Header
        HStack(alignment: .center) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Inbox")
              .font(.title3)
              .fontWeight(.semibold)
            if appState.unreadMailCount > 0 {
              Text("\(appState.unreadMailCount) unread of \(appState.mailItems.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
              Text("\(appState.mailItems.count) messages")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          Spacer()
          Button {
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

        if appState.mailItems.isEmpty {
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
          List(appState.mailItems, selection: $selectedMailId) { item in
            MailListRow(item: item)
              .tag(item.id)
          }
          .listStyle(.inset)
        }
      }
      .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
      .onChange(of: selectedMailId) { _, newId in
        if let id = newId {
          Task { await loadMailContent(id: id) }
        } else {
          selectedContent = ""
        }
      }

      // Mail content
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

        if isLoadingContent {
          VStack(spacing: 12) {
            ProgressView()
              .scaleEffect(0.8)
            Text("Loading message...")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let selectedId = selectedMailId,
                  let item = appState.mailItems.first(where: { $0.id == selectedId }) {
          MailDetailView(
            item: item,
            content: selectedContent,
            onMarkRead: { await markRead() }
          )
        } else {
          VStack(spacing: 12) {
            Image(systemName: "envelope.open")
              .font(.system(size: 40))
              .foregroundStyle(.quaternary)
            Text("Select a message to read")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .frame(minWidth: 420)
    }
    .sheet(isPresented: $showCompose) {
      ComposeMailView(isPresented: $showCompose)
        .environmentObject(appState)
    }
  }

  private func loadMailContent(id: String) async {
    isLoadingContent = true
    do {
      selectedContent = try await GTClient.shared.mailRead(id)
    } catch {
      selectedContent = "Error: \(error.localizedDescription)"
    }
    isLoadingContent = false
  }

  private func markRead() async {
    guard let id = selectedMailId else { return }
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

// MARK: - Mail List Row

struct MailListRow: View {
  let item: MailItem

  var body: some View {
    HStack(spacing: 10) {
      // Unread indicator
      Circle()
        .fill(item.isUnread ? .blue : .clear)
        .frame(width: 8, height: 8)

      // Avatar circle
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
          Text(item.from ?? "unknown")
            .font(.callout)
            .fontWeight(item.isUnread ? .semibold : .regular)
          Spacer()
          Text(item.formattedDate)
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        Text(item.subject.isEmpty ? "(no subject)" : item.subject)
          .font(.subheadline)
          .foregroundStyle(item.isUnread ? .primary : .secondary)
          .lineLimit(1)
        if let body = item.body {
          Text(body)
            .font(.caption)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
        }
      }

      if let priority = item.priority, priority != "normal" {
        PriorityBadge(priority: priority)
      }
    }
    .padding(.vertical, 4)
  }

  private var avatarInitial: String {
    let name = item.from ?? "?"
    return String(name.prefix(1)).uppercased()
  }

  private var avatarColor: Color {
    let name = item.from ?? ""
    switch name.lowercased() {
    case "overseer": return .purple
    case let n where n.contains("witness"): return .orange
    case let n where n.contains("refinery"): return .teal
    case let n where n.contains("deacon"): return .green
    default: return .blue
    }
  }
}

// MARK: - Mail Detail View

struct MailDetailView: View {
  let item: MailItem
  let content: String
  let onMarkRead: () async -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      VStack(alignment: .leading, spacing: 8) {
        Text(item.subject)
          .font(.title2)
          .fontWeight(.semibold)
          .textSelection(.enabled)

        HStack(spacing: 16) {
          HStack(spacing: 6) {
            ZStack {
              Circle()
                .fill(avatarColor.opacity(0.15))
                .frame(width: 24, height: 24)
              Text(String((item.from ?? "?").prefix(1)).uppercased())
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(avatarColor)
            }
            VStack(alignment: .leading, spacing: 0) {
              Text(item.from ?? "unknown")
                .font(.callout)
                .fontWeight(.medium)
              if let to = item.to {
                Text("to \(to)")
                  .font(.caption2)
                  .foregroundStyle(.tertiary)
              }
            }
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 2) {
            Text(item.formattedDate)
              .font(.caption)
              .foregroundStyle(.secondary)
            if let threadId = item.thread_id {
              Text(threadId.prefix(12))
                .font(.caption2)
                .foregroundStyle(.quaternary)
            }
          }
        }

        if let priority = item.priority, priority != "normal" {
          PriorityBadge(priority: priority)
        }
      }
      .padding(16)
      .background(.secondary.opacity(0.04))

      Divider()

      // Body
      ScrollView {
        Text(content.isEmpty ? "(empty)" : content)
          .font(.system(.body, design: .monospaced))
          .lineSpacing(4)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(16)
          .textSelection(.enabled)
      }

      Divider()

      // Actions bar
      HStack(spacing: 12) {
        if item.isUnread {
          Button {
            Task { await onMarkRead() }
          } label: {
            Label("Mark Read", systemImage: "envelope.open")
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        }
        Spacer()
        Text(item.id)
          .font(.caption2)
          .foregroundStyle(.quaternary)
          .textSelection(.enabled)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
    }
  }

  private var avatarColor: Color {
    let name = item.from ?? ""
    switch name.lowercased() {
    case "overseer": return .purple
    case let n where n.contains("witness"): return .orange
    case let n where n.contains("refinery"): return .teal
    case let n where n.contains("deacon"): return .green
    default: return .blue
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
  @State private var to: String = ""
  @State private var subject: String = ""
  @State private var message: String = ""
  @State private var isSending: Bool = false
  @State private var feedback: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("New Message")
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
        HStack {
          Text("To")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(width: 60, alignment: .trailing)
          TextField("e.g. overseer, fursatech/witness", text: $to)
            .textFieldStyle(.roundedBorder)
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
        Button("Send") {
          Task { await send() }
        }
        .disabled(to.isEmpty || subject.isEmpty || message.isEmpty || isSending)
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 500, height: 400)
  }

  private func send() async {
    isSending = true
    do {
      _ = try await GTClient.shared.mailSend(to: to, subject: subject, message: message)
      feedback = "Sent!"
      try? await Task.sleep(for: .seconds(1))
      isPresented = false
    } catch {
      feedback = "Error: \(error.localizedDescription)"
    }
    isSending = false
  }
}
