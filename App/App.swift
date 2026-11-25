import SwiftUI

@main
struct AppDefinition: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

  var body: some Scene {
    Settings { EmptyView() }
      .commands {
        CommandGroup(replacing: .appSettings) {
          Button("Settings…", action: delegate.showSettings)
            .keyboardShortcut(",", modifiers: .command)
        }
      }
  }
}
