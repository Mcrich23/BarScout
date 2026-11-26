import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

@available(macOS 27.0, *)
struct NativeMenuBarOverflow {
  var agent: AXUIElement
  var display: CGRect
  private let agentPID: pid_t
  private let originalPointer: CGPoint

  private struct Control {
    var element: AXUIElement
    var frame: CGRect
    var expanded: Bool
  }

  private struct Slot {
    var item: MenuBarItem
    var frame: CGRect
  }

  init?(agentPID: pid_t, at point: CGPoint) {
    guard let display = Self.displayBounds(at: point) else { return nil }
    self.display = display
    self.agentPID = agentPID
    originalPointer = point
    agent = AXUIElementCreateApplication(agentPID)
    AXUIElementSetMessagingTimeout(agent, 0.15)
  }

  func open(_ item: MenuBarItem, scan: () -> [MenuBarItem]) -> Bool {
    guard let overflow = control(), CGPreflightPostEventAccess() else {
      return MenuBarCatalog.open(item)
    }

    var pointerRestored = false
    let restorePointer = {
      CGWarpMouseCursorPosition(originalPointer)
      pointerRestored = true
    }
    defer { if !pointerRestored { restorePointer() } }

    if let visible = slot(for: item) {
      return openAndWait(visible, restorePointer: restorePointer)
    }

    defer {
      if !overflow.expanded {
        let pointerAtDismissal = CGEvent(source: nil)?.location
        _ = setExpanded(false)
        if let pointerAtDismissal { CGWarpMouseCursorPosition(pointerAtDismissal) }
      }
    }
    guard setExpanded(true) else {
      return false
    }

    guard let revealed = waitForRevealedSlot(item, scan: scan) else {
      return false
    }
    return openAndWait(revealed, restorePointer: restorePointer)
  }

  private func waitForRevealedSlot(_ item: MenuBarItem, scan: () -> [MenuBarItem]) -> Slot? {
    for _ in 0..<6 {
      let items = scan()
      let slots = items.compactMap(slot(for:))
      if let slot = matchingSlot(for: item, in: slots) { return slot }
      Thread.sleep(forTimeInterval: 0.10)
    }
    return nil
  }

  private func matchingSlot(for item: MenuBarItem, in slots: [Slot]) -> Slot? {
    if let exact = slots.first(where: { $0.item.id == item.id || CFEqual($0.item.element, item.element) }) {
      return exact
    }
    guard item.pid != agentPID else { return nil }
    let matches = slots.filter { $0.item.pid == item.pid }
    return matches.count == 1 ? matches.first : nil
  }

  private func control() -> Control? {
    let windows = MenuBarCatalog.attribute(agent, kAXWindowsAttribute) as? [AXUIElement] ?? []
    let menuBars = [kAXMenuBarAttribute, "AXExtrasMenuBar"].compactMap {
      MenuBarCatalog.elementAttribute(agent, $0)
    }

    var candidate: Control?
    for root in windows + menuBars {
      var pending: [(element: AXUIElement, slotFrame: CGRect?, depth: Int)] = [(root, nil, 0)]
      while let node = pending.popLast() {
        let elementFrame = MenuBarCatalog.frame(of: node.element)
        let frame = [elementFrame, node.slotFrame].compactMap { $0 }.first {
          (2...100).contains($0.width) && !$0.isEmpty && belongsToBar($0)
        }
        if let expanded = Self.overflowState(node.element), let frame
        {
          if let hit = MenuBarCatalog.element(at: frame.center),
            let liveState = Self.overflowState(hit)
          {
            return Control(element: hit, frame: MenuBarCatalog.frame(of: hit) ?? frame, expanded: liveState)
          }
          if candidate == nil {
            candidate = Control(element: node.element, frame: frame, expanded: expanded)
          }
        }

        if node.depth < 6 {
          let children = MenuBarCatalog.children(of: node.element)
          // A MenuBarAgent slot can expose the geometry on its container and the
          // accessibility label on the child that represents the overflow button.
          let inheritedFrame = children.count == 1 ? frame : nil
          pending.append(contentsOf: children.map { ($0, inheritedFrame, node.depth + 1) })
        }
      }
    }
    return candidate
  }

  private static let overflowBundle = Bundle(path: "/System/Library/CoreServices/MenuBarAgent.app")

  private static func overflowState(_ element: AXUIElement) -> Bool? {
    let identifier = MenuBarCatalog.attribute(element, kAXIdentifierAttribute) as? String
    if identifier == "menu-bar-overflow-indicator-expanded" { return true }
    let labels = [kAXDescriptionAttribute, kAXTitleAttribute, "AXLabel", kAXHelpAttribute].compactMap {
      MenuBarCatalog.attribute(element, $0) as? String
    }
    for (key, english, expanded) in [
      ("menuBar.hideOverflowItemsAccessibilityLabel", "Hide Menu Bar Items", true),
      ("menuBar.showOverflowItemsAccessibilityLabel", "Show Hidden Menu Bar Items", false)
    ] {
      let localized = overflowBundle?.localizedString(forKey: key, value: english, table: "MenuBarCore")
      if labels.contains(english) || localized.map(labels.contains) == true { return expanded }
    }
    return identifier == "menu-bar-overflow-indicator" ? false : nil
  }

  private func setExpanded(_ expanded: Bool) -> Bool {
    guard let button = control() else { return !expanded }
    if button.expanded == expanded { return true }

    var actionNames: CFArray?
    if AXUIElementCopyActionNames(button.element, &actionNames) == .success,
      (actionNames as? [String])?.contains(kAXPressAction) == true,
      AXUIElementPerformAction(button.element, kAXPressAction as CFString) == .success,
      waitForExpansion(expanded)
    {
      return true
    }

    guard CGPreflightPostEventAccess(),
      let current = control()
    else { return false }
    if current.expanded == expanded { return true }

    // AX hit testing can report the hosting slot or window instead of the
    // button. Its live frame from MenuBarAgent already identifies the target.
    guard click(current.frame.center) else { return false }
    return waitForExpansion(expanded)
  }

  private func waitForExpansion(_ expanded: Bool) -> Bool {
    for _ in 0..<12 {
      Thread.sleep(forTimeInterval: 0.045)
      if let state = control()?.expanded, state == expanded { return true }
    }
    return false
  }

  private func slot(for item: MenuBarItem) -> Slot? {
    guard let frame = MenuBarCatalog.frame(of: item.element),
      belongsToBar(frame), frame.width > 2,
      MenuBarCatalog.isHit(item.element, at: frame.center)
    else { return nil }
    return Slot(item: item, frame: frame)
  }

  private func belongsToBar(_ frame: CGRect) -> Bool {
    display.minX <= frame.midX && frame.midX < display.maxX
      && display.minY <= frame.midY && frame.midY < display.minY + 55
  }

  private func openAndWait(_ slot: Slot, restorePointer: () -> Void) -> Bool {
    var owners: Set<pid_t> = [slot.item.pid, agentPID]
    if slot.item.pid == agentPID,
      let controlCenter = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").first
    {
      owners.insert(controlCenter.processIdentifier)
    }
    let baseline = transientWindows(near: slot, ownedBy: owners)
    let menuWasVisible = hasOpenMenu(slot.item)
    guard slot.frame == self.slot(for: slot.item)?.frame, click(slot.frame.center) else { return false }

    let clock = ContinuousClock()
    let start = clock.now
    var lastOpen: ContinuousClock.Instant?
    // Window Server can report the popover while the app's accessibility server is busy handling the click.
    while true {
      if !transientWindows(near: slot, ownedBy: owners).isSubset(of: baseline) {
        lastOpen = clock.now
        break
      }
      if start.duration(to: clock.now) >= .milliseconds(150) { break }
      Thread.sleep(forTimeInterval: 0.015)
    }
    restorePointer()

    while true {
      Thread.sleep(forTimeInterval: 0.09)
      let open = !transientWindows(near: slot, ownedBy: owners).isSubset(of: baseline)
        || (!menuWasVisible && hasOpenMenu(slot.item))
      let now = clock.now
      if open {
        lastOpen = now
      } else if let lastOpen {
        if lastOpen.duration(to: now) > .milliseconds(240) { break }
      } else if start.duration(to: now) > .milliseconds(750) {
        let pointer = CGEvent(source: nil)?.location ?? originalPointer
        let moved = hypot(pointer.x - originalPointer.x, pointer.y - originalPointer.y) > 10
        let escaped = CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(kVK_Escape))
        if escaped || moved || start.duration(to: now) > .seconds(3) { break }
      }
    }
    return true
  }

  private func hasOpenMenu(_ item: MenuBarItem) -> Bool {
    if MenuBarCatalog.elementAttribute(item.element, kAXShownMenuUIElementAttribute) != nil {
      return true
    }
    return MenuBarCatalog.children(of: item.element).contains { element in
      MenuBarCatalog.attribute(element, kAXRoleAttribute) as? String == kAXMenuRole
        && (MenuBarCatalog.frame(of: element)?.height ?? 0) > 0
    }
  }

  private func transientWindows(near slot: Slot, ownedBy owners: Set<pid_t>) -> Set<CGWindowID> {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
      as? [[String: Any]] ?? []
    return Set(windows.compactMap { window in
      guard let owner = window[kCGWindowOwnerPID as String] as? pid_t,
        owners.contains(owner),
        let level = window[kCGWindowLayer as String] as? Int,
        level > 0,
        let bounds = window[kCGWindowBounds as String] as? NSDictionary,
        let frame = CGRect(dictionaryRepresentation: bounds),
        frame.minY >= display.minY, frame.minY < display.minY + 125,
        frame.height > 25,
        frame.minX - 60 <= slot.frame.midX, slot.frame.midX <= frame.maxX + 60
      else { return nil }
      return window[kCGWindowNumber as String] as? CGWindowID
    })
  }

  private func click(_ point: CGPoint) -> Bool {
    guard let down = event(.leftMouseDown, at: point),
      let up = event(.leftMouseUp, at: point)
    else { return false }
    down.setIntegerValueField(.mouseEventClickState, value: 1)
    up.setIntegerValueField(.mouseEventClickState, value: 1)
    event(.mouseMoved, at: point)?.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.025)
    down.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.035)
    up.post(tap: .cghidEventTap)
    return true
  }

  private func event(_ type: CGEventType, at point: CGPoint) -> CGEvent? {
    let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
    event?.flags = []
    return event
  }

  private static func displayBounds(at point: CGPoint) -> CGRect? {
    var displayID = CGMainDisplayID()
    var count: UInt32 = 0
    guard CGGetDisplaysWithPoint(point, 1, &displayID, &count) == .success, count == 1 else { return nil }
    return CGDisplayBounds(displayID)
  }
}

private extension CGRect {
  var center: CGPoint { CGPoint(x: midX, y: midY) }
}
