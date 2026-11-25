import AppKit
import ApplicationServices

enum MenuBarCatalog {
  static func scan(_ apps: [NSRunningApplication]) -> [MenuBarItem] {
    let workerCount = min(apps.count, 8)
    let lock = NSLock()
    var items: [MenuBarItem] = []
    DispatchQueue.concurrentPerform(iterations: workerCount) { worker in
      let results = stride(from: worker, to: apps.count, by: workerCount).flatMap {
        appItems(apps[$0])
      }
      lock.withLock { items.append(contentsOf: results) }
    }

    if #available(macOS 27.0, *),
      let agent = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").first
    {
      let appByPID = Dictionary(apps.map { ($0.processIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
      let root = AXUIElementCreateApplication(agent.processIdentifier)
      AXUIElementSetMessagingTimeout(root, 0.15)
      let windows = attribute(root, kAXWindowsAttribute) as? [AXUIElement] ?? []
      var knownPIDs = Set(items.map(\.pid))
      for window in windows {
        for slot in children(of: window) {
          // Hidden third-party items keep their hosted slot, even when AppKit
          // stops exposing the owner's AXExtrasMenuBar and its item elements.
          guard let owner = children(of: slot).first,
            attribute(owner, kAXRoleAttribute) as? String == kAXApplicationRole
          else { continue }
          var pid: pid_t = 0
          guard AXUIElementGetPid(owner, &pid) == .success,
            let app = appByPID[pid],
            let label = app.localizedName ?? app.bundleIdentifier,
            knownPIDs.insert(pid).inserted
          else { continue }
          items.append(MenuBarItem(
            id: "\(pid):hosted", title: label, appName: label, icon: app.icon, element: owner, pid: pid
          ))
        }
      }
    }

    return items.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
  }

  private static func appItems(_ app: NSRunningApplication) -> [MenuBarItem] {
    let process = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(process, 0.12)
    guard let bar = elementAttribute(process, "AXExtrasMenuBar"),
      let children = attribute(bar, kAXChildrenAttribute) as? [AXUIElement],
      !children.isEmpty
    else { return [] }

    let appName = app.localizedName ?? app.bundleIdentifier ?? String(localized: "Menu Bar Item")
    let icon = app.icon
    return children.enumerated().compactMap { index, element in
      let role = attribute(element, kAXRoleAttribute) as? String
      guard role != "AXSeparator" else { return nil }
      var actions: CFArray?
      AXUIElementCopyActionNames(element, &actions)
      let actionNames = actions as? [String] ?? []
      if !actionNames.contains(kAXPressAction) && !actionNames.contains(kAXPickAction) {
        if #available(macOS 27.0, *) {
          guard role == kAXMenuBarItemRole || role == kAXButtonRole else { return nil }
        } else {
          return nil
        }
      }

      let label = ["AXLabel", kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute]
        .lazy.compactMap { attribute(element, $0) as? String }
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }
      let title = label ?? (children.count == 1 ? appName : String(localized: "\(appName) item \(index + 1)"))
      return MenuBarItem(
        id: itemID(element, children: children, pid: app.processIdentifier, index: index),
        title: title, appName: appName, icon: icon, element: element, pid: app.processIdentifier
      )
    }
  }

  static func open(_ item: MenuBarItem) -> Bool {
    var result = AXUIElementPerformAction(item.element, kAXPressAction as CFString)
    if result == .actionUnsupported {
      result = AXUIElementPerformAction(item.element, kAXPickAction as CFString)
    }
    // A menu can start tracking before its accessibility callback returns.
    return result == .success || result == .cannotComplete
  }

  static func children(of element: AXUIElement) -> [AXUIElement] {
    attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
  }

  static func frame(of element: AXUIElement) -> CGRect? {
    if let value = axValue(element, "AXFrame", type: .cgRect) {
      var frame = CGRect.zero
      if AXValueGetValue(value, .cgRect, &frame) { return frame }
    }
    guard let position = axValue(element, kAXPositionAttribute, type: .cgPoint),
      let size = axValue(element, kAXSizeAttribute, type: .cgSize)
    else { return nil }
    var origin = CGPoint.zero
    var extent = CGSize.zero
    guard AXValueGetValue(position, .cgPoint, &origin), AXValueGetValue(size, .cgSize, &extent) else {
      return nil
    }
    return CGRect(origin: origin, size: extent)
  }

  private static func axValue(_ element: AXUIElement, _ name: String, type: AXValueType) -> AXValue? {
    guard let value = attribute(element, name), CFGetTypeID(value) == AXValueGetTypeID() else {
      return nil
    }
    let axValue = value as! AXValue
    return AXValueGetType(axValue) == type ? axValue : nil
  }

  private static func itemID(_ element: AXUIElement, children: [AXUIElement], pid: pid_t, index: Int) -> String {
    if let identifier = attribute(element, kAXIdentifierAttribute) as? String, !identifier.isEmpty {
      let occurrence = children.prefix(index).filter {
        attribute($0, kAXIdentifierAttribute) as? String == identifier
      }.count
      return "\(pid):\(identifier):\(occurrence)"
    }
    let title = attribute(element, kAXTitleAttribute) as? String
      ?? attribute(element, kAXDescriptionAttribute) as? String
    if let title, !title.isEmpty {
      let occurrence = children.prefix(index).filter {
        let name = attribute($0, kAXTitleAttribute) as? String ?? attribute($0, kAXDescriptionAttribute) as? String
        return name == title
      }.count
      return "\(pid):\(title):\(occurrence)"
    }
    return "\(pid):slot:\(index)"
  }

  static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
      return nil
    }
    return value
  }

  static func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
    guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else {
      return nil
    }
    return (value as! AXUIElement)
  }
}
