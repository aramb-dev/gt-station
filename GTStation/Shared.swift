import SwiftUI

struct RawOutputCard: View {
  let title: String
  let content: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
      ScrollView {
        Text(content.isEmpty ? "(empty)" : content)
          .font(.system(.caption, design: .monospaced))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(8)
      }
      .frame(maxHeight: 120)
      .background(.secondary.opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: 6))
    }
  }
}

struct StatusRow: View {
  let label: String
  let value: String
  var color: Color = .secondary

  var body: some View {
    HStack {
      Text(label)
        .foregroundStyle(.secondary)
        .font(.caption)
        .frame(width: 80, alignment: .leading)
      Text(value)
        .foregroundStyle(color)
        .font(.caption)
    }
  }
}
