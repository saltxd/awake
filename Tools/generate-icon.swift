import AppKit

// Generates AppIcon.iconset (an amber sun on a night-indigo rounded rect — the colorful
// Dock/app-icon counterpart to the monochrome menu-bar glyph, and the day/night motif
// of the panel: the sun that stays up all night). Regenerate with:
//
//   swiftc -o /tmp/genicon Tools/generate-icon.swift && /tmp/genicon
//   iconutil -c icns AppIcon.iconset -o AppIcon.icns

let outDir = FileManager.default.currentDirectoryPath + "/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

/// Tints a symbol image with a vertical gradient (drawn `sourceAtop`, so only the
/// glyph's opaque pixels take the color).
func gradientVersion(_ image: NSImage, top: NSColor, bottom: NSColor) -> NSImage {
    let out = NSImage(size: image.size)
    out.lockFocus()
    image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1)
    let gradImg = NSImage(size: image.size)
    gradImg.lockFocus()
    NSGradient(colors: [top, bottom])!.draw(in: NSRect(origin: .zero, size: image.size), angle: -90)
    gradImg.unlockFocus()
    gradImg.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .sourceAtop, fraction: 1)
    out.unlockFocus()
    return out
}

func renderPNG(px: CGFloat) -> Data {
    let img = NSImage(size: NSSize(width: px, height: px))
    img.lockFocus()
    let ctx = NSGraphicsContext.current!
    ctx.imageInterpolation = .high

    // Squircle: large rounded rect with a small transparent margin, plus a soft shadow.
    let margin = px * 0.085
    let rect = NSRect(x: margin, y: margin, width: px - 2 * margin, height: px - 2 * margin)
    let radius = rect.width * 0.2237
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowOffset = NSSize(width: 0, height: -px * 0.008)
    shadow.shadowBlurRadius = px * 0.03
    shadow.set()
    NSColor.black.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Night sky, top -> bottom: indigo dusk into near-black.
    let top = NSColor(calibratedRed: 0.20, green: 0.21, blue: 0.42, alpha: 1)   // dusk indigo
    let bottom = NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.18, alpha: 1) // night
    NSGradient(colors: [top, bottom])!.draw(in: path, angle: -90)

    // Subtle top sheen for a bit of glassy depth.
    let sheen = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.14),
        NSColor.white.withAlphaComponent(0.0),
    ])!
    path.addClip()
    sheen.draw(in: NSRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2), angle: -90)
    ctx.cgContext.resetClip()

    // The amber sun (the panel's "on" hero), centered, with a warm glow against the night.
    let cfg = NSImage.SymbolConfiguration(pointSize: rect.height * 0.52, weight: .semibold)
    if let sun = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let amber = gradientVersion(sun,
            top: NSColor(calibratedRed: 1.00, green: 0.80, blue: 0.42, alpha: 1),
            bottom: NSColor(calibratedRed: 1.00, green: 0.52, blue: 0.22, alpha: 1))
        let s = amber.size
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.24, alpha: 0.55)
        glow.shadowOffset = .zero
        glow.shadowBlurRadius = px * 0.06
        glow.set()
        amber.draw(in: NSRect(x: rect.midX - s.width / 2,
                              y: rect.midY - s.height / 2,
                              width: s.width, height: s.height))
        NSGraphicsContext.restoreGraphicsState()
    }

    img.unlockFocus()
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

let specs: [(String, CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in specs {
    try! renderPNG(px: px).write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
print("wrote \(specs.count) icon sizes to \(outDir)")
