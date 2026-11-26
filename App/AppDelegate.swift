import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  private let model = PaletteModel()
  private var statusItem: NSStatusItem?
  private var panel: SearchPanel?
  private let shortcuts = ShortcutSettings()
  private var preferencesWindow: NSWindow?
  private var showingOnboarding = false
  private var shortcutMonitor: Any?
  private var searchMenuItem: NSMenuItem?
  private var shouldQuit = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    item.button?.image = NSImage(
      systemSymbolName: "line.3.horizontal.decrease.circle",
      accessibilityDescription: "BarScout"
    )
    let menu = NSMenu()
    let open = NSMenuItem(
      title: "Search Menu Bar", action: #selector(showPalette), keyEquivalent: ""
    )
    open.target = self
    menu.addItem(open)
    searchMenuItem = open
    let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
    settings.target = self
    menu.addItem(settings)
    let setup = NSMenuItem(title: "Show Setup…", action: #selector(showSetup), keyEquivalent: "")
    setup.target = self
    menu.addItem(setup)
    menu.addItem(.separator())
    menu.addItem(withTitle: "Quit BarScout", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    item.menu = menu
    statusItem = item

    shortcuts.onPress = { [weak self] in self?.togglePalette() }
    shortcuts.onChange = { [weak self] in self?.updateShortcutMenuItem() }
    shortcuts.start()

    if OnboardingPreferences.wasShown() {
      showPalette()
    } else {
      showSetup()
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !OnboardingPreferences.wasShown() || (showingOnboarding && preferencesWindow != nil) {
      showSetup()
    } else {
      showPalette()
    }
    return false
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard model.isOpening else { return .terminateNow }
    shouldQuit = true
    return .terminateLater
  }

  func applicationWillTerminate(_ notification: Notification) {
    shortcuts.stop()
    if let shortcutMonitor { NSEvent.removeMonitor(shortcutMonitor) }
  }

  func windowDidResignKey(_ notification: Notification) {
    if let window = notification.object as? NSWindow, window === preferencesWindow {
      shortcuts.cancelRecording()
    } else {
      hidePalette()
    }
  }

  func windowWillClose(_ notification: Notification) {
    guard let window = notification.object as? NSWindow, window === preferencesWindow else { return }
    shortcuts.cancelRecording()
    preferencesWindow = nil
  }

  private func hidePalette() {
    model.isPresented = false
    if panel?.isVisible == true { panel?.orderOut(nil) }
  }

  private func updateShortcutMenuItem() {
    searchMenuItem?.keyEquivalent = shortcuts.isRegistered ? shortcuts.shortcut.keyEquivalent : ""
    searchMenuItem?.keyEquivalentModifierMask = shortcuts.shortcut.modifiers
  }

  @objc func showSettings() {
    showPreferences(onboarding: false)
  }

  @objc private func showSetup() {
    showPreferences(onboarding: true)
  }

  private func showPreferences(onboarding: Bool) {
    hidePalette()
    if let preferencesWindow {
      if showingOnboarding == onboarding {
        NSApp.activate()
        preferencesWindow.makeKeyAndOrderFront(nil)
        return
      }
      preferencesWindow.close()
    }

    showingOnboarding = onboarding
    let view = SetupView(
      shortcuts: shortcuts, isOnboarding: onboarding,
      requestAccess: { [weak self] in self?.model.requestAccess() },
      finish: { [weak self] openSearch in
        guard let self else { return }
        self.preferencesWindow?.close()
        if openSearch { self.showPalette() }
      }
    )
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 515, height: 1),
      styleMask: [.titled, .closable], backing: .buffered, defer: false
    )
    window.title = onboarding ? "BarScout Setup" : "BarScout Settings"
    window.isReleasedWhenClosed = false
    window.delegate = self
    let hosting = NSHostingView(rootView: view)
    window.contentView = hosting
    window.setContentSize(hosting.fittingSize)
    window.center()
    preferencesWindow = window

    if shortcutMonitor == nil {
      shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        guard let self, self.preferencesWindow?.isKeyWindow == true,
          self.shortcuts.record(event)
        else { return event }
        return nil
      }
    }

    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
    if onboarding && window.isVisible {
      OnboardingPreferences.markShown()
    }
  }

  private func togglePalette() {
    if panel?.isKeyWindow == true {
      hidePalette()
    } else {
      showPalette()
    }
  }

  @objc private func showPalette() {
    guard !model.isOpening else { return }
    model.reset()
    presentPalette()
    model.refresh()
  }

  private func presentPalette() {
    let panel = panel ?? makePanel()
    panel.makeKeyAndOrderFront(nil)
    model.isPresented = true
  }

  private func makePanel() -> SearchPanel {
    let hosting = NSHostingView(rootView: ContentView(
      model: model,
      shortcuts: shortcuts,
      open: { [weak self] item in self?.open(item) },
      showSettings: { [weak self] in self?.showSettings() },
      quit: { NSApp.terminate(nil) }
    ))
    let content = PaletteGlassView(content: hosting, size: ContentView.windowSize)
    let panelSize = content.frame.size
    let panel = SearchPanel(
      contentRect: NSRect(origin: .zero, size: panelSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.title = "BarScout"
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.level = .floating
    panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
    panel.delegate = self
    panel.contentView = content
    panel.handleKey = { [weak self] key in
      guard let self else { return false }
      switch Int(key) {
      case kVK_Escape:
        self.hidePalette()
      case kVK_UpArrow:
        self.model.moveSelection(by: -1)
      case kVK_DownArrow:
        self.model.moveSelection(by: 1)
      case kVK_Return, kVK_ANSI_KeypadEnter:
        guard let item = self.model.selectedItem else { return false }
        self.open(item)
      default:
        return false
      }
      return true
    }
    let frameName = "SearchPalette"
    if panel.setFrameUsingName(frameName) {
      let saved = panel.frame
      if saved.size != panelSize {
        panel.setFrame(NSRect(
          x: saved.midX - panelSize.width / 2,
          y: saved.midY - panelSize.height / 2,
          width: panelSize.width,
          height: panelSize.height
        ), display: false)
      }
    } else {
      let mouse = NSEvent.mouseLocation
      if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main {
        let area = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
          x: area.midX - panel.frame.width / 2,
          y: area.maxY - min(150, area.height * 0.16) - panel.frame.height
        ))
      }
    }
    panel.setFrameAutosaveName(frameName)
    self.panel = panel
    return panel
  }

  private func open(_ item: MenuBarItem) {
    hidePalette()
    model.open(item) { [weak self] opened in
      guard let self else { return }
      if self.shouldQuit {
        NSApp.reply(toApplicationShouldTerminate: true)
      } else if !opened, self.panel?.isVisible != true {
        self.presentPalette()
      }
    }
  }
}

private final class SearchPanel: NSPanel {
  var handleKey: ((UInt16) -> Bool)?

  override var canBecomeKey: Bool { true }

  override func sendEvent(_ event: NSEvent) {
    let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
    if event.type == .keyDown, modifiers.isEmpty,
      (firstResponder as? NSTextView)?.hasMarkedText() != true,
      handleKey?(event.keyCode) == true
    {
      return
    }
    super.sendEvent(event)
  }
}
