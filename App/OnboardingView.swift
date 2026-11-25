import SwiftUI

struct OnboardingView: View {
  var shortcuts: ShortcutSettings
  var hasAccess: Bool
  var requestAccess: () -> Void
  var finish: (Bool) -> Void

  @State private var step = Step.welcome

  var body: some View {
    SetupLayout {
      ForEach(Step.allCases, id: \.self) { item in
        Label {
          Text(item.title)
        } icon: {
          Image(systemName: item.rawValue < step.rawValue ? "checkmark.circle.fill" : item.symbol)
            .frame(width: 18)
        }
          .font(.callout.weight(step == item ? .semibold : .regular))
          .foregroundStyle(step == item ? .primary : .secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .background(.primary.opacity(step == item ? 0.08 : 0), in: .rect(cornerRadius: 8))
          .accessibilityAddTraits(step == item ? .isSelected : [])
          .accessibilityValue(item.rawValue < step.rawValue ? Text("Completed") : Text(""))
      }
    } content: {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
          Text(step.heading)
            .font(.largeTitle.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
          Text(step.description)
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        switch step {
        case .welcome:
          searchExample
            .accessibilityHidden(true)
        case .accessibility:
          AccessibilityCard(hasAccess: hasAccess)
        case .shortcut:
          ShortcutControl(shortcuts: shortcuts)
        }

        Spacer(minLength: 0)

        HStack(spacing: 10) {
          if step != .welcome {
            Button("Back", action: goBack)
              .disabled(shortcuts.isRecording)
          }

          Spacer()

          if step == .welcome || (step == .accessibility && !hasAccess) {
            Button("Set Up Later") { finish(false) }
          }

          primaryButton
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
      }
    }
  }

  private var searchExample: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 9) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.tint)
        Text("Search the menu bar…")
          .foregroundStyle(.secondary)
        Spacer()
        Text(shortcuts.shortcut.displayName)
          .font(.caption.monospaced())
          .padding(5)
          .background(.primary.opacity(0.07), in: .rect(cornerRadius: 5))
      }
      .padding(10)
      Divider()
      Label("Wi-Fi", systemImage: "wifi")
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 9)
        .background(.tint.opacity(0.14), in: .rect(cornerRadius: 6))
        .padding(5)
      Label("Sound", systemImage: "speaker.wave.2")
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }
    .font(.callout)
    .background(.primary.opacity(0.04), in: .rect(cornerRadius: 10))
    .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.10)) }
  }

  @ViewBuilder
  private var primaryButton: some View {
    switch step {
    case .welcome:
      Button("Get Started") { step = .accessibility }
    case .accessibility:
      if hasAccess {
        Button("Continue") { step = .shortcut }
      } else {
        Button("Open System Settings", action: requestAccess)
      }
    case .shortcut:
      Button("Open Search") { finish(true) }
        .disabled(shortcuts.isRecording || !hasAccess)
    }
  }

  private func goBack() {
    if let previous = Step(rawValue: step.rawValue - 1) { step = previous }
  }

  private enum Step: Int, CaseIterable {
    case welcome, accessibility, shortcut

    var title: LocalizedStringKey {
      switch self {
      case .welcome: "Welcome"
      case .accessibility: "Accessibility"
      case .shortcut: "Shortcut"
      }
    }

    var symbol: String {
      switch self {
      case .welcome: "magnifyingglass"
      case .accessibility: "hand.raised"
      case .shortcut: "keyboard"
      }
    }

    var heading: LocalizedStringKey {
      switch self {
      case .welcome: "Find your menu bar items"
      case .accessibility: "Allow Accessibility"
      case .shortcut: "Choose your shortcut"
      }
    }

    var description: LocalizedStringKey {
      switch self {
      case .welcome: "Search by item or app name, then press Return to open it."
      case .accessibility: "Accessibility lets BarScout find and open items from other apps."
      case .shortcut: "Click the shortcut to change it."
      }
    }
  }
}
