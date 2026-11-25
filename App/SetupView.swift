import ApplicationServices
import SwiftUI

struct SetupView: View {
  var shortcuts: ShortcutSettings
  var isOnboarding: Bool
  var requestAccess: () -> Void
  var finish: (Bool) -> Void

  @State private var hasAccess = AXIsProcessTrusted()

  #if DEBUG
  @State private var didResetOnboarding = false
  #endif

  var body: some View {
    Group {
      if isOnboarding {
        OnboardingView(
          shortcuts: shortcuts, hasAccess: hasAccess,
          requestAccess: requestAccess, finish: finish
        )
      } else {
        settings
      }
    }
    .task {
      while !Task.isCancelled {
        hasAccess = AXIsProcessTrusted()
        do {
          try await Task.sleep(for: .seconds(0.5))
        } catch {
          return
        }
      }
    }
  }

  private var settings: some View {
    SetupLayout {
      EmptyView()
    } content: {
      VStack(alignment: .leading, spacing: 14) {
        Text("Settings")
          .font(.largeTitle.weight(.semibold))
          .accessibilityAddTraits(.isHeader)
          .padding(.bottom, 6)

        ShortcutControl(shortcuts: shortcuts)
        AccessibilityCard(hasAccess: hasAccess, requestAccess: requestAccess)

        Spacer(minLength: 0)

        #if DEBUG
        HStack(spacing: 12) {
          Menu("Debug") {
            Button("Reset Onboarding") {
              OnboardingPreferences.reset()
              didResetOnboarding = true
            }
          }
          .fixedSize()

          if didResetOnboarding {
            Text("Setup will appear next time you open BarScout.")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }
        #endif
      }
    }
  }
}
