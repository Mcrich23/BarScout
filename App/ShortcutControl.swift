import SwiftUI

struct ShortcutControl: View {
  var shortcuts: ShortcutSettings

  var body: some View {
    SetupCard {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          SetupCardIcon(symbol: "keyboard")
          Text("Open search").fontWeight(.semibold)
          Spacer(minLength: 8)

          Button {
            shortcuts.toggleRecording()
          } label: {
            if shortcuts.isRecording {
              Text("Cancel")
            } else {
              Text(shortcuts.shortcut.displayName)
            }
          }
          .monospaced()
          .fixedSize()
          .accessibilityLabel(shortcuts.isRecording ? "Cancel shortcut recording" : "Change search shortcut")
          .accessibilityValue(shortcuts.shortcut.displayName)
        }

        if let message = shortcuts.feedback {
          Text(message).font(.callout).foregroundStyle(.secondary)
        }

        if !shortcuts.isRecording && shortcuts.shortcut != .standard {
          Button("Restore Default", action: shortcuts.restoreDefault)
            .buttonStyle(.link)
        }
      }
    }
  }
}
