import AppKit
import ApplicationServices

struct MenuBarItem: Identifiable {
  var id: String
  var title: String
  var appName: String
  var icon: NSImage?
  var element: AXUIElement
  var pid: pid_t
}
