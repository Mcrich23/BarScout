import AppKit
import SwiftUI

struct PaletteDragArea: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    DragView()
  }

  func updateNSView(_ view: NSView, context: Context) {}

  private final class DragView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
      addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
      window?.performDrag(with: event)
    }
  }
}
