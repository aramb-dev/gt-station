import SwiftUI

struct StatusCard: View {
  let title: String
  let value: String
  let icon: String
  let color: Color

  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundStyle(color)
      Text(value)
        .font(.callout)
        .fontWeight(.semibold)
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(.secondary.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }
}

struct SectionCard<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 4) {
        content
      }
    } label: {
      Text(title)
        .font(.headline)
    }
  }
}

struct RawOutputCard: View {
  let title: String
  let content: String

  var body: some View {
    GroupBox(title) {
      ScrollView {
        Text(content.isEmpty ? "(empty)" : content)
          .font(.system(.caption, design: .monospaced))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(8)
          .textSelection(.enabled)
      }
      .frame(maxHeight: 120)
    }
  }
}
