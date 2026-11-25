import Foundation

enum OnboardingPreferences {
  private static let shownKey = "didShowSetup"
  private static let legacyCompletedKey = "didCompleteSetup"

  static func wasShown(in defaults: UserDefaults = .standard) -> Bool {
    defaults.bool(forKey: shownKey) || defaults.bool(forKey: legacyCompletedKey)
  }

  static func markShown(in defaults: UserDefaults = .standard) {
    defaults.set(true, forKey: shownKey)
  }

  #if DEBUG
  static func reset(in defaults: UserDefaults = .standard) {
    defaults.removeObject(forKey: shownKey)
    defaults.removeObject(forKey: legacyCompletedKey)
  }
  #endif
}
