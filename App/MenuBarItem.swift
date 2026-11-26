import AppKit
import ApplicationServices

struct MenuBarItem: Identifiable {
  var id: String
  var title: String
  var appName: String
  var icon: NSImage?
  var element: AXUIElement
  var pid: pid_t
  var systemIcon: SystemMenuBarIcon? = nil
}

enum SystemMenuBarIcon {
  case symbol(String)
  case bluetooth
}
