import AppKit
import SwiftUI

struct SetupLayout<Sidebar: View, Content: View>: View {
  @ViewBuilder var sidebar: Sidebar
  @ViewBuilder var content: Content

  var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        Image(nsImage: NSApp.applicationIconImage)
          .resizable()
          .frame(width: 76, height: 76)
          .accessibilityHidden(true)

        Text("BarScout")
          .font(.title2.weight(.semibold))
          .padding(.bottom, 14)

        sidebar
        Spacer(minLength: 0)
      }
      .padding(22)
      .frame(width: 174, alignment: .leading)
      .frame(maxHeight: .infinity, alignment: .topLeading)
      .background {
        LinearGradient(
          colors: [.indigo.opacity(0.16), .purple.opacity(0.04)],
          startPoint: .topLeading, endPoint: .bottomTrailing
        )
      }

      Divider()

      content
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .frame(width: 665, height: 370)
  }
}
