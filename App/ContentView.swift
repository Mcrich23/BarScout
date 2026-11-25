import SwiftUI

struct ContentView: View {
  @Bindable var model: PaletteModel
  var shortcuts: ShortcutSettings
  var open: (MenuBarItem) -> Void
  var showSettings: () -> Void
  var quit: () -> Void
  @FocusState private var searchFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 15) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 23, weight: .medium))
          .foregroundStyle(.tint)
          .accessibilityHidden(true)

        TextField("Search the menu bar…", text: $model.query)
          .textFieldStyle(.plain)
          .font(.system(size: 25, weight: .medium))
          .focused($searchFocused)
          .accessibilityLabel("Search menu bar items")

        if shortcuts.isRegistered {
          KeyCap(value: shortcuts.shortcut.displayName, label: LocalizedStringKey(shortcuts.shortcut.displayName))
        }
      }
      .padding(.horizontal, 22)
      .frame(height: 74)

      Divider().padding(.horizontal, 14)
      content.frame(maxWidth: .infinity, maxHeight: .infinity)
      Divider().padding(.horizontal, 14)

      HStack(spacing: 14) {
        if let error = model.error {
          Text(error).foregroundStyle(.red)
        } else if !shortcuts.isRegistered {
          Text("Shortcut unavailable")
        } else {
          Text("BarScout").fontWeight(.semibold)
        }
        Spacer()
        if !model.results.isEmpty {
          hint("↑ ↓", label: "Move", keyLabel: "Up and Down")
          hint("↵", label: "Open", keyLabel: "Return")
        }
        hint("esc", label: "Close", keyLabel: "Escape")

        HStack(spacing: 4) {
          Button("Settings…", systemImage: "gearshape", action: showSettings)
            .help("Settings")
            .keyboardShortcut(",", modifiers: .command)
          Button("Quit BarScout", systemImage: "power", action: quit)
            .help("Quit BarScout")
            .keyboardShortcut("q", modifiers: .command)
        }
        .labelStyle(.iconOnly)
        .controlSize(.small)
      }
      .font(.system(size: 11))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 20)
      .frame(height: 46)
    }
    .frame(width: 590, height: 388)
    .background(.regularMaterial, in: .rect(cornerRadius: 25))
    .overlay {
      RoundedRectangle(cornerRadius: 25)
        .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
        .allowsHitTesting(false)
    }
    .onChange(of: model.session, initial: true) {
      searchFocused = true
    }
    .task(id: model.isPresented) {
      guard model.isPresented else { return }
      while !Task.isCancelled {
        do {
          try await Task.sleep(for: .seconds(1))
        } catch {
          return
        }
        model.checkAccess()
      }
    }
  }

  @ViewBuilder
  private var content: some View {
    if !model.hasAccess {
      VStack(spacing: 10) {
        Image(systemName: "hand.raised")
          .font(.system(size: 23, weight: .medium))
          .foregroundStyle(.tint)
          .frame(width: 48, height: 48)
          .background(.tint.opacity(0.13), in: .rect(cornerRadius: 14))
          .accessibilityHidden(true)
        Text("Allow Accessibility")
          .font(.system(size: 18, weight: .semibold))
          .accessibilityAddTraits(.isHeader)
        Text("BarScout uses Accessibility to find and open menu bar items.")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 290)
          .fixedSize(horizontal: false, vertical: true)
        Button("Open Accessibility Settings", action: model.requestAccess)
          .buttonStyle(.borderedProminent)
          .padding(.top, 6)
      }
    } else if model.results.isEmpty {
      if model.isLoading {
        ProgressView("Finding items…")
          .controlSize(.small)
      } else {
        VStack(spacing: 8) {
          Text(model.hasSearchQuery ? "No matches" : "No menu bar items found")
            .font(.system(size: 17, weight: .semibold))
          Text(model.hasSearchQuery ? "Try another item or app name." : "Open search again to rescan.")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
      }
    } else {
      ResultsView(model: model, open: open)
    }
  }

  private func hint(_ key: String, label: LocalizedStringKey, keyLabel: LocalizedStringKey) -> some View {
    HStack(spacing: 5) {
      KeyCap(value: key, label: keyLabel)
      Text(label)
    }
    .accessibilityElement(children: .combine)
  }
}

private struct ResultsView: View {
  var model: PaletteModel
  var open: (MenuBarItem) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(model.hasSearchQuery ? "Search Results" : "Menu Bar Items")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .accessibilityAddTraits(.isHeader)

      ScrollViewReader { scroll in
        ScrollView {
          LazyVStack(spacing: 2) {
            ForEach(model.results) { item in
              ResultRow(item: item, selected: model.selection == item.id) { open(item) }
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.horizontal, 12)
          .padding(.bottom, 6)
        }
        .onChange(of: model.selection) {
          if let selection = model.selection { scroll.scrollTo(selection) }
        }
      }
    }
  }
}

private struct ResultRow: View {
  @Environment(\.colorSchemeContrast) private var contrast
  var item: MenuBarItem
  var selected: Bool
  var open: () -> Void

  var body: some View {
    Button(action: open) {
      HStack(spacing: 11) {
        Group {
          if let icon = item.icon {
            Image(nsImage: icon).resizable().scaledToFit()
          } else {
            Image(systemName: "line.3.horizontal.decrease.circle")
              .foregroundStyle(.tint)
          }
        }
        .frame(width: 25, height: 25)
        .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 2) {
          Text(item.title)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
          if item.appName != item.title {
            Text(item.appName)
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
        Spacer()
        if selected {
          Image(systemName: "return")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.tint)
            .accessibilityHidden(true)
        }
      }
      .padding(.horizontal, 10)
      .frame(height: 42)
      .contentShape(.rect)
      .background {
        if selected {
          RoundedRectangle(cornerRadius: 9)
            .fill(.tint.opacity(contrast == .increased ? 0.36 : 0.20))
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

private struct KeyCap: View {
  var value: String
  var label: LocalizedStringKey

  var body: some View {
    Text(value)
      .font(.system(size: 11, weight: .medium, design: .monospaced))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(.primary.opacity(0.065), in: .rect(cornerRadius: 5))
      .accessibilityLabel(label)
  }
}
