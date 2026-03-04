import SwiftUI

struct DashboardView: View {
  @EnvironmentObject var appState: AppState
  @State private var selectedSection: DashboardSection = .status

  enum DashboardSection: String, CaseIterable, Identifiable {
    case status = "Status"
    case mail = "Mail"
    case escalations = "Escalations"
    case dolt = "Dolt"
    case quickActions = "Quick Actions"

    var id: String { rawValue }

    var icon: String {
      switch self {
      case .status: return "gauge"
      case .mail: return "envelope"
      case .escalations: return "exclamationmark.triangle"
      case .dolt: return "cylinder"
      case .quickActions: return "bolt"
      }
    }
  }

  var body: some View {
    NavigationSplitView {
      List(DashboardSection.allCases, selection: $selectedSection) { section in
        Label(section.rawValue, systemImage: section.icon)
          .tag(section)
      }
      .navigationSplitViewColumnWidth(min: 150, ideal: 180)
    } detail: {
      Group {
        switch selectedSection {
        case .status:
          StatusView()
        case .mail:
          MailView()
        case .escalations:
          EscalationsView()
        case .dolt:
          DoltHealthView()
        case .quickActions:
          QuickActionsView()
        }
      }
      .environmentObject(appState)
    }
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button {
          Task { await appState.refresh() }
        } label: {
          Label("Refresh", systemImage: "arrow.clockwise")
        }
        .disabled(appState.isLoading)
      }
    }
    .navigationTitle("GT Station")
  }
}

struct StatusView: View {
  @EnvironmentObject var appState: AppState

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("System Status")
          .font(.title2)
          .bold()
          .padding(.horizontal)

        RawOutputCard(title: "GT Status", content: appState.status)
          .padding(.horizontal)
        RawOutputCard(title: "Polecats", content: appState.polecats)
          .padding(.horizontal)
        RawOutputCard(title: "Convoys", content: appState.convoys)
          .padding(.horizontal)
      }
      .padding(.vertical)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
