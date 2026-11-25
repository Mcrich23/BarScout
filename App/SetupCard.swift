import SwiftUI

struct SetupCard<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    content
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.primary.opacity(0.04), in: .rect(cornerRadius: 10))
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .strokeBorder(.primary.opacity(0.10))
          .allowsHitTesting(false)
      }
  }
}

struct SetupCardIcon: View {
  var symbol: String

  var body: some View {
    Image(systemName: symbol)
      .font(.system(size: 17, weight: .medium))
      .foregroundStyle(.tint)
      .frame(width: 32, height: 32)
      .background(.tint.opacity(0.11), in: .rect(cornerRadius: 8))
      .accessibilityHidden(true)
  }
}
