import Foundation

struct MenuBarSearch {
  private var entries: [Entry]

  init(_ items: [MenuBarItem] = []) {
    entries = items.map { item in
      Entry(
        item: item,
        title: Self.words(in: item.title).joined(),
        appName: Self.words(in: item.appName).joined()
      )
    }
  }

  func results(for query: String) -> [MenuBarItem] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return entries.map(\.item) }

    let terms = Self.words(in: trimmed)
    guard !terms.isEmpty else {
      return entries.map(\.item).filter {
        $0.title.localizedStandardContains(trimmed) || $0.appName.localizedStandardContains(trimmed)
      }
    }

    let phrase = terms.joined()
    return entries.compactMap { entry -> (item: MenuBarItem, match: Match)? in
      guard let match = entry.match(phrase: phrase, terms: terms) else { return nil }
      return (entry.item, match)
    }
    .sorted { $0.match.rawValue < $1.match.rawValue }
    .map(\.item)
  }

  private static func words(in value: String) -> [Substring] {
    value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
      .split { !$0.isLetter && !$0.isNumber }
  }

  private enum Match: Int {
    case exactTitle, exactApp, titlePrefix, appPrefix, titleContains, appContains, combined, allTerms
  }

  private struct Entry {
    var item: MenuBarItem
    var title: String
    var appName: String

    func match(phrase: String, terms: [Substring]) -> Match? {
      if title == phrase { return .exactTitle }
      if appName == phrase { return .exactApp }
      if title.hasPrefix(phrase) { return .titlePrefix }
      if appName.hasPrefix(phrase) { return .appPrefix }
      if title.contains(phrase) { return .titleContains }
      if appName.contains(phrase) { return .appContains }
      if (title + appName).contains(phrase) || (appName + title).contains(phrase) { return .combined }
      if terms.count > 1 && terms.allSatisfy({ title.contains($0) || appName.contains($0) }) {
        return .allTerms
      }
      return nil
    }
  }
}
