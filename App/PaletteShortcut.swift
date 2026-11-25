import AppKit
import Carbon.HIToolbox

struct PaletteShortcut: Codable, Equatable {
  var keyCode: UInt32
  var modifierMask: UInt
  var keyEquivalent: String

  static let standard = PaletteShortcut(
    keyCode: UInt32(kVK_Space), modifierMask: NSEvent.ModifierFlags.option.rawValue, keyEquivalent: " "
  )

  private static let supportedModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

  init(keyCode: UInt32, modifierMask: UInt, keyEquivalent: String) {
    self.keyCode = keyCode
    self.modifierMask = modifierMask
    self.keyEquivalent = keyEquivalent
  }

  init?(event: NSEvent) {
    let modifiers = event.modifierFlags.intersection(Self.supportedModifiers)
    guard !modifiers.intersection([.control, .option, .command]).isEmpty,
      let character = event.characters(byApplyingModifiers: [])?.lowercased(),
      character.unicodeScalars.count == 1,
      character != "\u{1b}"
    else { return nil }

    self.init(keyCode: UInt32(event.keyCode), modifierMask: modifiers.rawValue, keyEquivalent: character)
  }

  var modifiers: NSEvent.ModifierFlags {
    NSEvent.ModifierFlags(rawValue: modifierMask).intersection(Self.supportedModifiers)
  }

  var carbonModifiers: UInt32 {
    var flags = 0
    if modifiers.contains(.control) { flags |= controlKey }
    if modifiers.contains(.option) { flags |= optionKey }
    if modifiers.contains(.shift) { flags |= shiftKey }
    if modifiers.contains(.command) { flags |= cmdKey }
    return UInt32(flags)
  }

  var displayName: String {
    let symbols: [(NSEvent.ModifierFlags, String)] = [
      (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")
    ]
    return (symbols.filter { modifiers.contains($0.0) }.map(\.1) + [keyName]).joined(separator: " ")
  }

  private var keyName: String {
    switch keyEquivalent {
    case " ": String(localized: "Space")
    case "\r", "\u{3}": "↩"
    case "\t", "\u{19}": "⇥"
    case "\u{7f}": "⌫"
    case "\u{f728}": "⌦"
    case "\u{f700}": "↑"
    case "\u{f701}": "↓"
    case "\u{f702}": "←"
    case "\u{f703}": "→"
    case "\u{f729}": String(localized: "Home")
    case "\u{f72b}": String(localized: "End")
    case "\u{f72c}": String(localized: "Page Up")
    case "\u{f72d}": String(localized: "Page Down")
    default:
      if let scalar = keyEquivalent.unicodeScalars.first, (0xF704...0xF726).contains(scalar.value) {
        "F\(scalar.value - 0xF703)"
      } else {
        keyEquivalent.uppercased()
      }
    }
  }
}
