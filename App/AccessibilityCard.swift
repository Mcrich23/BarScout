import SwiftUI

struct AccessibilityCard: View {
  var hasAccess: Bool
  var requestAccess: (() -> Void)?

  var body: some View {
    SetupCard {
      HStack(spacing: 12) {
        SetupCardIcon(symbol: "hand.raised")

        VStack(alignment: .leading, spacing: 4) {
          Text("Accessibility")
            .fontWeight(.semibold)
          Text(hasAccess ? "Access is enabled." : "Turn on BarScout in Privacy & Security → Accessibility.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }

        Spacer(minLength: 8)

        if hasAccess {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .accessibilityHidden(true)
        } else if let requestAccess {
          Button("Open System Settings", action: requestAccess)
            .fixedSize()
        }
      }
    }
  }
}
