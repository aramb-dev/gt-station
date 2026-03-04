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
            VStack(alignment: .leading, spacing: 2) {
              Text(item.subject.isEmpty ? "(no subject)" : item.subject)
                .font(.body)
                .lineLimit(1)
              Text(item.id)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            .tag(item.id)
          }
        }
      }
      .frame(minWidth: 220, maxWidth: 300)
      .onChange(of: selectedMailId) { _, newId in
        if let id = newId {
          Task { await loadMailContent(id: id) }
        }
      }

      // Mail content
      VStack(alignment: .leading, spacing: 0) {
        if let feedback = actionFeedback {
          Text(feedback)
            .foregroundStyle(.green)
            .padding()
        }

        if isLoadingContent {
          ProgressView("Loading...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if selectedMailId != nil {
          ScrollView {
            Text(selectedContent)
              .font(.system(.body, design: .monospaced))
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding()
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
          Text("Select a message")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .frame(minWidth: 300)
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
        TextField("gtstation/witness", text: $to)
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
        .frame(height: 120)
        .border(.secondary.opacity(0.3))

      if let feedback {
        Text(feedback)
          .foregroundStyle(.green)
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
    .frame(width: 420, height: 320)
  }

  private func send() async {
    isSending = true
    do {
      _ = try await GTClient.shared.mailSend(to: to, subject: subject, message: message)
      feedback = "Sent!"
      try? await Task.sleep(for: .seconds(1.5))
      isPresented = false
    } catch {
      feedback = "Error: \(error.localizedDescription)"
    }
    isSending = false
  }
}
