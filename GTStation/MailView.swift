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
        HStack {
          Text("Inbox")
            .font(.headline)
            .padding()
          Spacer()
          Text("\(appState.unreadMailCount) unread")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.trailing, 8)
          Button {
            showCompose = true
          } label: {
            Image(systemName: "square.and.pencil")
          }
          .padding(.trailing)
        }
        Divider()

        if appState.mailItems.isEmpty {
          Text("No messages")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          List(appState.mailItems, selection: $selectedMailId) { item in
            HStack(spacing: 8) {
              if item.isUnread {
                Circle()
                  .fill(.blue)
                  .frame(width: 6, height: 6)
              } else {
                Circle()
                  .fill(.clear)
                  .frame(width: 6, height: 6)
              }
              VStack(alignment: .leading, spacing: 2) {
                Text(item.subject.isEmpty ? "(no subject)" : item.subject)
                  .font(.body)
                  .fontWeight(item.isUnread ? .semibold : .regular)
                  .lineLimit(1)
                HStack {
                  Text(item.from ?? "unknown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  Spacer()
                  Text(item.formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
              }
            }
            .padding(.vertical, 2)
            .tag(item.id)
          }
        }
      }
      .frame(minWidth: 260, maxWidth: 340)
      .onChange(of: selectedMailId) { _, newId in
        if let id = newId {
          Task { await loadMailContent(id: id) }
        }
      }

      // Mail content
      VStack(alignment: .leading, spacing: 0) {
        if let feedback = actionFeedback {
          HStack {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(.green)
            Text(feedback)
              .font(.caption)
          }
          .padding(.horizontal)
          .padding(.vertical, 6)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.green.opacity(0.1))
        }

        if isLoadingContent {
          ProgressView("Loading...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let selectedId = selectedMailId,
                  let item = appState.mailItems.first(where: { $0.id == selectedId }) {
          // Header
          VStack(alignment: .leading, spacing: 4) {
            Text(item.subject)
              .font(.title3)
              .fontWeight(.semibold)
            HStack {
              Text("From: \(item.from ?? "unknown")")
              Spacer()
              Text(item.formattedDate)
                .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let priority = item.priority, priority != "normal" {
              Text(priority.uppercased())
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(priority == "urgent" ? .red.opacity(0.2) : .orange.opacity(0.2), in: Capsule())
            }
          }
          .padding()

          Divider()

          // Body
          ScrollView {
            Text(selectedContent)
              .font(.system(.body, design: .monospaced))
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding()
              .textSelection(.enabled)
          }

          Divider()

          HStack {
            Button("Mark Read") {
              Task { await markRead() }
            }
            .disabled(selectedMailId == nil)
            Spacer()
          }
          .padding()
        } else {
          VStack(spacing: 8) {
            Image(systemName: "envelope.open")
              .font(.largeTitle)
              .foregroundStyle(.secondary)
            Text("Select a message")
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .frame(minWidth: 400)
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

struct ComposeMailView: View {
  @Binding var isPresented: Bool
  @EnvironmentObject var appState: AppState
  @State private var to: String = ""
  @State private var subject: String = ""
  @State private var message: String = ""
  @State private var isSending: Bool = false
  @State private var feedback: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Compose Mail")
        .font(.headline)

      LabeledContent("To:") {
        TextField("e.g. overseer, fursatech/witness", text: $to)
          .textFieldStyle(.roundedBorder)
      }
      LabeledContent("Subject:") {
        TextField("Subject", text: $subject)
          .textFieldStyle(.roundedBorder)
      }

      Text("Message:")
        .font(.caption)
        .foregroundStyle(.secondary)
      TextEditor(text: $message)
        .font(.system(.body, design: .monospaced))
        .frame(height: 140)
        .border(.secondary.opacity(0.3))

      if let feedback {
        Text(feedback)
          .foregroundStyle(feedback.hasPrefix("Error") ? .red : .green)
      }

      HStack {
        Button("Cancel") { isPresented = false }
        Spacer()
        Button("Send") {
          Task { await send() }
        }
        .disabled(to.isEmpty || subject.isEmpty || message.isEmpty || isSending)
        .buttonStyle(.borderedProminent)
      }
    }
    .padding()
    .frame(width: 460, height: 360)
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
