import AppKit

final class PaletteGlassView: NSView {
  private static let shadowInset: CGFloat = 18
  private static let cornerRadius: CGFloat = 24
  private let glass: NSGlassEffectView

  init(content: NSView, size: NSSize) {
    let inset = Self.shadowInset
    let glassFrame = NSRect(origin: NSPoint(x: inset, y: inset), size: size)
    glass = NSGlassEffectView(frame: glassFrame)
    super.init(frame: NSRect(origin: .zero, size: glassFrame.insetBy(dx: -inset, dy: -inset).size))

    glass.cornerRadius = Self.cornerRadius
    glass.style = .regular
    glass.contentView = content
    glass.autoresizingMask = [.width, .height]
    addSubview(glass)
  }

  required init?(coder: NSCoder) {
    return nil
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    guard let context = NSGraphicsContext.current?.cgContext else { return }

    let radius = Self.cornerRadius
    let outline = CGPath(roundedRect: glass.frame, cornerWidth: radius, cornerHeight: radius, transform: nil)

    context.saveGState()
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    context.setShadow(offset: CGSize(width: 0, height: -3), blur: 7, color: NSColor.black.withAlphaComponent(0.24).cgColor)
    context.setFillColor(NSColor.black.cgColor)
    context.addPath(outline)
    context.fillPath()

    context.setShadow(offset: .zero, blur: 0, color: nil)
    context.setBlendMode(.clear)
    context.addPath(outline)
    context.fillPath()
    context.endTransparencyLayer()
    context.restoreGState()
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    guard glass.frame.contains(convert(point, from: superview)) else { return nil }
    return super.hitTest(point)
  }
}
