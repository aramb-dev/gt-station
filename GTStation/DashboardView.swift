import SwiftUI

struct DashboardView: View {
  @EnvironmentObject var appState: AppState
  @State private var selectedSection: DashboardSection = .overview

  enum DashboardSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case mail = "Mail"
    case rigs = "Rigs"
    case dolt = "Dolt"
    case nudge = "Nudge"

    var id: String { rawValue }

    var icon: String {
      switch self {
      case .overview: return "gauge.open.with.lines.needle.33percent"
      case .mail: return "envelope"
      case .rigs: return "server.rack"
      case .dolt: return "cylinder"
      case .nudge: return "bubble.left.and.bubble.right"
      }
    }
  }

  var body: some View {
    NavigationSplitView {
      List(DashboardSection.allCases, selection: $selectedSection) { section in
        Label {
          HStack {
            Text(section.rawValue)
            Spacer()
            if section == .mail && appState.unreadMailCount > 0 {
              Text("\(appState.unreadMailCount)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.blue, in: Capsule())
            }
          }
        } icon: {
          Image(systemName: section.icon)
        }
        .tag(section)
      }
      .navigationSplitViewColumnWidth(min: 160, ideal: 190)
      .listStyle(.sidebar)
    } detail: {
      Group {
        switch selectedSection {
        case .overview:
          OverviewView()
        case .mail:
          MailView()
        case .rigs:
          RigsView()
        case .dolt:
          DoltHealthView()
        case .nudge:
          NudgeView()
        }
      }
      .environmentObject(appState)
    }
    .toolbar {
      ToolbarItem(placement: .automatic) {
        HStack(spacing: 8) {
          if let lastRefresh = appState.lastRefresh {
            Text(lastRefresh, style: .time)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Button {
            Task { await appState.refresh() }
          } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
          }
          .disabled(appState.isLoading)
        }
      }
    }
    .navigationTitle("Gas Station")
  }
}

// MARK: - Overview

struct OverviewView: View {
  @EnvironmentObject var appState: AppState

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // Status cards row
        HStack(spacing: 16) {
          StatusCard(
            title: "Daemon",
            value: appState.isDaemonRunning ? "Running" : "Stopped",
            icon: "bolt.circle.fill",
            color: appState.isDaemonRunning ? .green : .red
          )
          StatusCard(
            title: "Dolt",
            value: appState.isDoltRunning ? "Running" : "Stopped",
            icon: "cylinder.fill",
            color: appState.isDoltRunning ? .green : .red
          )
          StatusCard(
            title: "Rigs",
            value: "\(appState.rigCount)",
            icon: "server.rack",
            color: .blue
          )
          StatusCard(
            title: "Polecats",
            value: "\(appState.activePolecatCount)",
            icon: "hare.fill",
            color: .orange
          )
          StatusCard(
            title: "Mail",
            value: "\(appState.unreadMailCount) unread",
            icon: "envelope.fill",
            color: appState.unreadMailCount > 0 ? .blue : .secondary
          )
        }

        // Agents section
        if let agents = appState.townStatus?.agents, !agents.isEmpty {
          SectionCard(title: "Town Agents") {
            ForEach(agents, id: \.name) { agent in
              HStack {
                Circle()
                  .fill(agent.running ? .green : .red)
                  .frame(width: 8, height: 8)
                Text(agent.name)
                  .fontWeight(.medium)
                if let role = agent.role {
                  Text("(\(role))")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
                Spacer()
                if let state = agent.state {
                  Text(state)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.15), in: Capsule())
                }
                if let mail = agent.unread_mail, mail > 0 {
                  Text("\(mail) mail")
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
              }
              .padding(.vertical, 2)
            }
          }
        }

        // Rigs section
        if !appState.rigs.isEmpty {
          SectionCard(title: "Rigs") {
            ForEach(appState.rigs) { rig in
              HStack {
                Circle()
                  .fill(rig.witness == "running" ? .green : .yellow)
                  .frame(width: 8, height: 8)
                Text(rig.name)
                  .fontWeight(.medium)
                Spacer()
                HStack(spacing: 12) {
                  Label("W: \(rig.witness ?? "?")", systemImage: "eye")
                    .font(.caption)
                  Label("R: \(rig.refinery ?? "?")", systemImage: "gearshape")
                    .font(.caption)
                  Label("P: \(rig.polecats ?? 0)", systemImage: "hare")
                    .font(.caption)
                }
                .foregroundStyle(.secondary)
              }
              .padding(.vertical, 2)
            }
          }
        }

        // Recent mail
        if !appState.mailItems.isEmpty {
          SectionCard(title: "Recent Mail") {
            ForEach(appState.mailItems.prefix(5)) { item in
              HStack {
                if item.isUnread {
                  Circle()
                    .fill(.blue)
                    .frame(width: 6, height: 6)
                } else {
                  Circle()
                    .fill(.clear)
                    .frame(width: 6, height: 6)
                }
                VStack(alignment: .leading, spacing: 1) {
                  Text(item.subject)
                    .font(.callout)
                    .fontWeight(item.isUnread ? .semibold : .regular)
                    .lineLimit(1)
                  HStack {
                    Text(item.from ?? "unknown")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                    Text(item.formattedDate)
                      .font(.caption)
                      .foregroundStyle(.tertiary)
                  }
                }
                Spacer()
              }
              .padding(.vertical, 2)
            }
          }
        }

        // Polecats
        if !appState.polecats.isEmpty {
          SectionCard(title: "Active Polecats") {
            ForEach(appState.polecats) { polecat in
              HStack {
                Text(polecat.name ?? "unnamed")
                  .fontWeight(.medium)
                if let rig = polecat.rig {
                  Text("in \(rig)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
                Spacer()
                if let status = polecat.status {
                  Text(status)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.15), in: Capsule())
                }
              }
              .padding(.vertical, 2)
            }
          }
        }

        // Convoys
        if !appState.convoys.isEmpty {
          SectionCard(title: "Active Convoys") {
            ForEach(appState.convoys) { convoy in
              HStack {
                Text(convoy.name ?? "unnamed")
                  .fontWeight(.medium)
                Spacer()
                if let status = convoy.status {
                  Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              .padding(.vertical, 2)
            }
          }
        }
      }
      .padding()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
