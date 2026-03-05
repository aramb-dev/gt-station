import SwiftUI

struct StatusCard: View {
  let title: String
  let value: String
  let icon: String
  let color: Color

  var body: some View {
    VStack(spacing: 8) {
      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .fill(color.opacity(0.1))
          .frame(width: 36, height: 36)
        Image(systemName: icon)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(color)
      }
      Text(value)
        .font(.system(.callout, design: .rounded, weight: .bold))
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 14)
    .background(.secondary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(.secondary.opacity(0.08), lineWidth: 1)
    )
  }
}

struct SectionCard<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.headline)
        .foregroundStyle(.primary)
      VStack(alignment: .leading, spacing: 6) {
        content
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.secondary.opacity(0.04))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(.secondary.opacity(0.08), lineWidth: 1)
    )
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
