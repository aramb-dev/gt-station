import SwiftUI

// MARK: - Contact Model

struct Contact: Codable, Identifiable, Hashable {
  let id: String  // The technical address (e.g. "mayor/", "overseer")
  var displayName: String
  var role: String
  var notes: String
  var isFavorite: Bool

  var initials: String {
    let words = displayName.split(separator: " ")
    if words.count >= 2 {
      return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased()
    }
    return String(displayName.prefix(2)).uppercased()
  }
}

// MARK: - Contact Store

class ContactStore: ObservableObject {
  static let shared = ContactStore()

  @Published var contacts: [Contact] = []

  private let storeURL: URL = {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let dir = appSupport.appendingPathComponent("GasStation", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("contacts.json")
  }()

  init() {
    load()
  }

  /// Populate from town status if contacts are empty
  func populateFromTown(_ status: TownStatus?) {
    guard let status else { return }

    var existing = Set(contacts.map { $0.id })

    // Add overseer
    if !existing.contains("overseer") {
      if let overseer = status.overseer {
        contacts.append(Contact(
          id: "overseer",
          displayName: overseer.name ?? "Overseer",
          role: "Overseer",
          notes: overseer.email ?? "",
          isFavorite: true
        ))
        existing.insert("overseer")
      }
    }

    // Add town agents
    if let agents = status.agents {
      for agent in agents {
        let addr = agent.address ?? agent.name
        if !existing.contains(addr) {
          contacts.append(Contact(
            id: addr,
            displayName: friendlyName(for: agent.name, role: agent.role),
            role: agent.role ?? "agent",
            notes: "",
            isFavorite: false
          ))
          existing.insert(addr)
        }
      }
    }

    // Add rig agents
    if let rigs = status.rigs {
      for rig in rigs {
        if let agents = rig.agents {
          for agent in agents {
            let addr = agent.address ?? "\(rig.name)/\(agent.name)"
            if !existing.contains(addr) {
              contacts.append(Contact(
                id: addr,
                displayName: friendlyName(for: agent.name, role: agent.role),
                role: "\(agent.role ?? "agent") (\(rig.name))",
                notes: "",
                isFavorite: false
              ))
              existing.insert(addr)
            }
          }
        }
      }
    }

    save()
  }

  func resolveDisplayName(for address: String) -> String {
    contacts.first(where: { $0.id == address })?.displayName ?? address
  }

  func updateContact(_ contact: Contact) {
    if let idx = contacts.firstIndex(where: { $0.id == contact.id }) {
      contacts[idx] = contact
    } else {
      contacts.append(contact)
    }
    save()
  }

  func deleteContact(_ id: String) {
    contacts.removeAll { $0.id == id }
    save()
  }

  private func friendlyName(for name: String, role: String?) -> String {
    let capitalized = name.prefix(1).uppercased() + name.dropFirst()
    if let role, !role.isEmpty {
      return "\(capitalized) (\(role))"
    }
    return capitalized
  }

  private func save() {
    if let data = try? JSONEncoder().encode(contacts) {
      try? data.write(to: storeURL, options: .atomic)
    }
  }

  private func load() {
    guard let data = try? Data(contentsOf: storeURL),
          let loaded = try? JSONDecoder().decode([Contact].self, from: data) else { return }
    contacts = loaded
  }
}

// MARK: - Contacts View

struct ContactsView: View {
  @StateObject private var store = ContactStore.shared
  @EnvironmentObject var appState: AppState
  @State private var selectedContactId: String? = nil
  @State private var searchText: String = ""
  @State private var showAddContact: Bool = false

  private var filteredContacts: [Contact] {
    let sorted = store.contacts.sorted { a, b in
      if a.isFavorite != b.isFavorite { return a.isFavorite }
      return a.displayName < b.displayName
    }
    if searchText.isEmpty { return sorted }
    let q = searchText.lowercased()
    return sorted.filter {
      $0.displayName.lowercased().contains(q) ||
      $0.id.lowercased().contains(q) ||
      $0.role.lowercased().contains(q)
    }
  }

  var body: some View {
    HSplitView {
      // Contact list
      VStack(spacing: 0) {
        HStack {
          Text("Contacts")
            .font(.title3)
            .fontWeight(.semibold)
          Spacer()
          Button {
            showAddContact = true
          } label: {
            Image(systemName: "plus")
              .font(.title3)
          }
          .buttonStyle(.plain)
          .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        // Search
        HStack {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(.secondary)
          TextField("Search contacts", text: $searchText)
            .textFieldStyle(.plain)
        }
        .padding(8)
        .background(.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)

        Divider()

        if filteredContacts.isEmpty {
          VStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
              .font(.system(size: 36))
              .foregroundStyle(.quaternary)
            Text("No contacts")
              .font(.callout)
              .foregroundStyle(.secondary)
            if store.contacts.isEmpty {
              Button("Auto-populate from Town") {
                store.populateFromTown(appState.townStatus)
              }
              .buttonStyle(.bordered)
              .controlSize(.small)
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          List(filteredContacts, selection: $selectedContactId) { contact in
            HStack(spacing: 10) {
              // Avatar
              ZStack {
                Circle()
                  .fill(colorForSender(contact.id).opacity(0.15))
                  .frame(width: 32, height: 32)
                Text(contact.initials)
                  .font(.system(.caption2, design: .rounded, weight: .bold))
                  .foregroundStyle(colorForSender(contact.id))
              }

              VStack(alignment: .leading, spacing: 2) {
                HStack {
                  Text(contact.displayName)
                    .font(.callout)
                    .fontWeight(.medium)
                  if contact.isFavorite {
                    Image(systemName: "star.fill")
                      .font(.caption2)
                      .foregroundStyle(.yellow)
                  }
                }
                Text(contact.role)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            .tag(contact.id)
          }
          .listStyle(.inset)
        }
      }
      .frame(minWidth: 240, idealWidth: 280, maxWidth: 340)

      // Contact detail
      VStack {
        if let contactId = selectedContactId,
           let contact = store.contacts.first(where: { $0.id == contactId }) {
          ContactDetailView(contact: contact, store: store)
        } else {
          VStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
              .font(.system(size: 40))
              .foregroundStyle(.quaternary)
            Text("Select a contact")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .frame(minWidth: 400)
    }
    .onAppear {
      if store.contacts.isEmpty {
        store.populateFromTown(appState.townStatus)
      }
    }
    .sheet(isPresented: $showAddContact) {
      AddContactView(isPresented: $showAddContact, store: store)
    }
  }
}

// MARK: - Contact Detail

struct ContactDetailView: View {
  @State var contact: Contact
  let store: ContactStore
  @State private var isEditing: Bool = false
  @State private var editName: String = ""
  @State private var editRole: String = ""
  @State private var editNotes: String = ""

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        // Card header
        VStack(spacing: 12) {
          ZStack {
            Circle()
              .fill(colorForSender(contact.id).opacity(0.12))
              .frame(width: 80, height: 80)
            Text(contact.initials)
              .font(.system(.title, design: .rounded, weight: .bold))
              .foregroundStyle(colorForSender(contact.id))
          }

          Text(contact.displayName)
            .font(.title2)
            .fontWeight(.semibold)

          Text(contact.role)
            .font(.callout)
            .foregroundStyle(.secondary)

          HStack(spacing: 4) {
            Image(systemName: "at")
              .font(.caption)
              .foregroundStyle(.tertiary)
            Text(contact.id)
              .font(.callout)
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
          }
        }
        .padding(.top, 20)

        Divider()
          .padding(.horizontal, 40)

        if isEditing {
          // Edit form
          VStack(alignment: .leading, spacing: 12) {
            LabeledContent("Display Name") {
              TextField("Name", text: $editName)
                .textFieldStyle(.roundedBorder)
            }
            LabeledContent("Role") {
              TextField("Role", text: $editRole)
                .textFieldStyle(.roundedBorder)
            }
            LabeledContent("Notes") {
              TextField("Notes", text: $editNotes)
                .textFieldStyle(.roundedBorder)
            }
            HStack {
              Button("Cancel") {
                isEditing = false
              }
              Spacer()
              Button("Save") {
                var updated = contact
                updated.displayName = editName
                updated.role = editRole
                updated.notes = editNotes
                store.updateContact(updated)
                contact = updated
                isEditing = false
              }
              .buttonStyle(.borderedProminent)
            }
          }
          .padding(.horizontal, 40)
        } else {
          // Info cards
          VStack(alignment: .leading, spacing: 16) {
            if !contact.notes.isEmpty {
              VStack(alignment: .leading, spacing: 4) {
                Text("Notes")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Text(contact.notes)
                  .font(.body)
              }
            }

            HStack(spacing: 12) {
              Button {
                editName = contact.displayName
                editRole = contact.role
                editNotes = contact.notes
                isEditing = true
              } label: {
                Label("Edit", systemImage: "pencil")
              }
              .buttonStyle(.bordered)

              Button {
                var updated = contact
                updated.isFavorite.toggle()
                store.updateContact(updated)
                contact = updated
              } label: {
                Label(
                  contact.isFavorite ? "Unfavorite" : "Favorite",
                  systemImage: contact.isFavorite ? "star.slash" : "star"
                )
              }
              .buttonStyle(.bordered)
            }
          }
          .padding(.horizontal, 40)
        }

        Spacer()
      }
    }
    .frame(maxWidth: .infinity)
  }
}

// MARK: - Add Contact

struct AddContactView: View {
  @Binding var isPresented: Bool
  let store: ContactStore
  @State private var address: String = ""
  @State private var displayName: String = ""
  @State private var role: String = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Add Contact")
        .font(.title3)
        .fontWeight(.semibold)

      VStack(spacing: 10) {
        LabeledContent("Address") {
          TextField("e.g. mayor/, overseer", text: $address)
            .textFieldStyle(.roundedBorder)
        }
        LabeledContent("Display Name") {
          TextField("e.g. The Mayor", text: $displayName)
            .textFieldStyle(.roundedBorder)
        }
        LabeledContent("Role") {
          TextField("e.g. Coordinator", text: $role)
            .textFieldStyle(.roundedBorder)
        }
      }

      HStack {
        Spacer()
        Button("Cancel") { isPresented = false }
        Button("Add") {
          let contact = Contact(
            id: address,
            displayName: displayName.isEmpty ? address : displayName,
            role: role,
            notes: "",
            isFavorite: false
          )
          store.updateContact(contact)
          isPresented = false
        }
        .disabled(address.isEmpty)
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(20)
    .frame(width: 420, height: 260)
  }
}
