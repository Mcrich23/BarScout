import SwiftUI

struct ContentView: View {
  static let windowSize = CGSize(width: 620, height: 360)

  @Bindable var model: PaletteModel
  var shortcuts: ShortcutSettings
  var open: (MenuBarItem) -> Void
  var showSettings: () -> Void
  var quit: () -> Void
  @FocusState private var searchFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 0) {
        Capsule()
          .fill(.secondary.opacity(0.32))
          .frame(width: 30, height: 3)
          .frame(maxWidth: .infinity)
          .frame(height: 18)
          .overlay { PaletteDragArea() }
          .accessibilityHidden(true)
          .help("Drag to move the search window")

        HStack(spacing: 13) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 23, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 27)
            .overlay { PaletteDragArea() }
            .accessibilityHidden(true)

          TextField("Search the menu bar…", text: $model.query)
            .textFieldStyle(.plain)
            .font(.system(size: 27))
            .focused($searchFocused)
            .accessibilityLabel("Search menu bar items")

          if shortcuts.isRegistered && !model.hasSearchQuery {
            KeyCap(value: shortcuts.shortcut.displayName, label: LocalizedStringKey(shortcuts.shortcut.displayName))
          }
        }
        .padding(.horizontal, 21)
        .frame(height: 48)
      }
      .padding(.bottom, 7)

      Divider().opacity(0.55).padding(.horizontal, 17)
      content.frame(maxWidth: .infinity, maxHeight: .infinity)
      Divider().opacity(0.55).padding(.horizontal, 17)

      HStack(spacing: 14) {
        if let error = model.error {
          Text(error).foregroundStyle(.red)
        } else if !shortcuts.isRegistered {
          Text("Shortcut unavailable")
        } else if !model.results.isEmpty {
          hint("↑ ↓", label: "Select", keyLabel: "Up and Down")
          hint("↵", label: "Open", keyLabel: "Return")
        }

        Spacer()

        HStack(spacing: 4) {
          Button("Settings…", systemImage: "gearshape", action: showSettings)
            .help("Settings")
            .keyboardShortcut(",", modifiers: .command)
          Button("Quit BarScout", systemImage: "power", action: quit)
            .help("Quit BarScout")
            .keyboardShortcut("q", modifiers: .command)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .controlSize(.small)
        .fixedSize()
      }
      .font(.system(size: 11))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 17)
      .frame(height: 42)
    }
    .frame(width: Self.windowSize.width, height: Self.windowSize.height)
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
      Text(model.hasSearchQuery ? "Matches" : "Menu Bar Items")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 22)
        .padding(.top, 12)
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
          if let systemIcon = item.systemIcon {
            switch systemIcon {
            case .symbol(let symbol):
              Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.tint)
            case .bluetooth:
              BluetoothGlyph()
                .stroke(.tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: 16, height: 16)
            }
          } else if let icon = item.icon {
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
            .font(.system(size: 14, weight: .medium))
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
            .fill(.tint.opacity(contrast == .increased ? 0.36 : 0.18))
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

private struct BluetoothGlyph: Shape {
  func path(in rect: CGRect) -> Path {
    let center = rect.midX
    let left = rect.minX + rect.width * 0.22
    let right = rect.maxX - rect.width * 0.22
    return Path { path in
      path.move(to: CGPoint(x: left, y: rect.minY + rect.height * 0.24))
      path.addLine(to: CGPoint(x: right, y: rect.minY + rect.height * 0.73))
      path.addLine(to: CGPoint(x: center, y: rect.maxY))
      path.addLine(to: CGPoint(x: center, y: rect.minY))
      path.addLine(to: CGPoint(x: right, y: rect.minY + rect.height * 0.27))
      path.addLine(to: CGPoint(x: left, y: rect.minY + rect.height * 0.76))
    }
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
