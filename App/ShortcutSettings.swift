import AppKit
import Carbon.HIToolbox
import Observation

@MainActor
@Observable
final class ShortcutSettings {
  private static let defaultsKey = "paletteShortcut"
  private(set) var shortcut: PaletteShortcut
  private(set) var isRegistered = false
  private(set) var isRecording = false
  private(set) var message: String?

  var feedback: String? {
    message ?? (isRecording ? String(localized: "Press your shortcut. Esc cancels.") : nil)
  }

  @ObservationIgnored var onPress: (() -> Void)?
  @ObservationIgnored var onChange: (() -> Void)?
  @ObservationIgnored private var registration: EventHotKeyRef?
  @ObservationIgnored private var handler: EventHandlerRef?
  @ObservationIgnored private var registrationID: UInt32 = 0

  init() {
    if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
      let saved = try? JSONDecoder().decode(PaletteShortcut.self, from: data)
    {
      shortcut = saved
    } else {
      shortcut = .standard
    }
  }

  func start() {
    var type = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)
    )
    let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
      guard let event, let context else { return OSStatus(eventNotHandledErr) }
      var identifier = EventHotKeyID()
      guard GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
        nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier
      ) == noErr, identifier.signature == 0x42534354 else { return OSStatus(eventNotHandledErr) }

      let settings = Unmanaged<ShortcutSettings>.fromOpaque(context).takeUnretainedValue()
      let id = identifier.id
      DispatchQueue.main.async {
        guard id == settings.registrationID, !settings.isRecording else { return }
        settings.onPress?()
      }
      return noErr
    }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)

    if status == noErr {
      isRegistered = register(shortcut)
    }
    if !isRegistered {
      message = String(localized: "This shortcut is unavailable. Try another.")
    }
    onChange?()
  }

  func stop() {
    if let registration { UnregisterEventHotKey(registration) }
    if let handler { RemoveEventHandler(handler) }
  }

  func toggleRecording() {
    isRecording.toggle()
    if isRecording { message = nil }
  }

  func cancelRecording() {
    isRecording = false
  }

  func record(_ event: NSEvent) -> Bool {
    guard isRecording else { return false }
    guard !event.isARepeat else { return true }
    if Int(event.keyCode) == kVK_Escape {
      cancelRecording()
    } else if let shortcut = PaletteShortcut(event: event) {
      apply(shortcut)
    } else {
      message = String(localized: "Hold Command, Option, or Control and press another key.")
    }
    return true
  }

  func restoreDefault() {
    apply(.standard)
  }

  private func apply(_ candidate: PaletteShortcut) {
    isRecording = false
    if candidate == shortcut && isRegistered {
      message = nil
      return
    }

    guard register(candidate) else {
      message = String(localized: "\(candidate.displayName) is unavailable. Try another.")
      return
    }

    shortcut = candidate
    isRegistered = true
    message = nil
    if let data = try? JSONEncoder().encode(candidate) {
      UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }
    onChange?()
  }

  private func register(_ candidate: PaletteShortcut) -> Bool {
    guard handler != nil else { return false }
    let nextID = registrationID &+ 1
    var newRegistration: EventHotKeyRef?
    let status = RegisterEventHotKey(
      candidate.keyCode, candidate.carbonModifiers,
      EventHotKeyID(signature: 0x42534354, id: nextID),
      GetApplicationEventTarget(), UInt32(kEventHotKeyExclusive), &newRegistration
    )

    guard status == noErr, let newRegistration else { return false }
    if let registration { UnregisterEventHotKey(registration) }
    registration = newRegistration
    registrationID = nextID
    return true
  }
}
