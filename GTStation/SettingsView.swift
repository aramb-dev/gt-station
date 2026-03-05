import SwiftUI

class AppPreferences: ObservableObject {
  static let shared = AppPreferences()

  @AppStorage("mailFontName") var mailFontName: String = "System"
  @AppStorage("mailFontSize") var mailFontSize: Double = 14

  var mailFont: Font {
    if mailFontName == "System" {
      return .system(size: mailFontSize)
    }
    return .custom(mailFontName, size: mailFontSize)
  }

  /// Available font families for the picker
  static let availableFonts: [String] = {
    var fonts = ["System"]
    fonts.append(contentsOf: NSFontManager.shared.availableFontFamilies.sorted())
    return fonts
  }()
}

struct SettingsView: View {
  @StateObject private var prefs = AppPreferences.shared

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text("Settings")
          .font(.title2)
          .bold()

        // Mail font
        GroupBox("Mail Display Font") {
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Text("Font Family")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .trailing)
              Picker("", selection: $prefs.mailFontName) {
                ForEach(AppPreferences.availableFonts, id: \.self) { name in
                  Text(name).tag(name)
                }
              }
              .frame(width: 250)
            }

            HStack {
              Text("Font Size")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .trailing)
              Slider(value: $prefs.mailFontSize, in: 10...24, step: 1)
                .frame(width: 200)
              Text("\(Int(prefs.mailFontSize))pt")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 40)
            }

            // Preview
            GroupBox("Preview") {
              Text("The quick brown fox jumps over the lazy dog.\n\nDear Mayor, this is how your emails will look in Gas Station.")
                .font(prefs.mailFont)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
          }
        }
      }
      .padding()
    }
  }
}
