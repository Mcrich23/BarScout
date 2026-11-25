import AppKit
import ApplicationServices
import Observation

@MainActor
@Observable
final class PaletteModel {
  var query = "" {
    didSet {
      filter()
      selection = results.first?.id
    }
  }
  var isPresented = false
  private(set) var hasAccess = AXIsProcessTrusted()
  private(set) var isLoading = false
  private(set) var isOpening = false
  private(set) var results: [MenuBarItem] = []
  private(set) var selection: MenuBarItem.ID?
  private(set) var session = 0
  private(set) var error: String?

  @ObservationIgnored private var search = MenuBarSearch()
  @ObservationIgnored private let worker = DispatchQueue(label: "BarScout Accessibility", qos: .userInitiated)

  var hasSearchQuery: Bool {
    query.contains { !$0.isWhitespace }
  }

  var selectedItem: MenuBarItem? {
    results.first { $0.id == selection }
  }

  func reset() {
    query = ""
    error = nil
    session += 1
  }

  func refresh() {
    hasAccess = AXIsProcessTrusted()
    guard hasAccess else {
      search = MenuBarSearch()
      filter()
      return
    }
    guard !isLoading, !isOpening else { return }

    isLoading = true
    worker.async { [weak self] in
      let apps = NSWorkspace.shared.runningApplications
      let ownPID = ProcessInfo.processInfo.processIdentifier
      let items = MenuBarCatalog.scan(apps).filter { $0.pid != ownPID }
      let search = MenuBarSearch(items)
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.search = search
        self.filter()
        if self.selectedItem == nil { self.selection = self.results.first?.id }
        self.isLoading = false
      }
    }
  }

  func checkAccess() {
    if hasAccess != AXIsProcessTrusted() { refresh() }
  }

  func requestAccess() {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    if AXIsProcessTrustedWithOptions(options) {
      refresh()
    } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
      NSWorkspace.shared.open(url)
    }
  }

  func moveSelection(by offset: Int) {
    guard !results.isEmpty else { return }
    let current = results.firstIndex { $0.id == selection } ?? 0
    selection = results[min(max(current + offset, 0), results.count - 1)].id
  }

  func open(_ item: MenuBarItem, completion: @escaping @MainActor (Bool) -> Void) {
    guard !isOpening else { return }
    isOpening = true
    let apps = NSWorkspace.shared.runningApplications.filter { $0.processIdentifier == item.pid }
    let agentPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").first?.processIdentifier
    let pointer = CGEvent(source: nil)?.location
    worker.async { [weak self] in
      let opened: Bool
      if #available(macOS 27.0, *), let agentPID, let pointer,
        let overflow = NativeMenuBarOverflow(agentPID: agentPID, at: pointer)
      {
        opened = overflow.open(item) { MenuBarCatalog.scan(apps) }
      } else {
        opened = MenuBarCatalog.open(item)
      }

      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.isOpening = false
        self.error = opened ? nil : String(localized: "Couldn’t open \(item.title).")
        completion(opened)
      }
    }
  }

  private func filter() {
    results = search.results(for: query)
  }
}
