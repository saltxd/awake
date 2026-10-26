import AppKit

/// Builds the menu-bar glyph as a **template** `NSImage` — a pure alpha mask the system tints like
/// the native Wi-Fi/battery icons, adapting to light/dark menu bars and the open-menu highlight.
///
/// A filled sun means "awake" and a zzz-moon means "normal sleep" — different glyphs, not just
/// different weights, so on/off reads at a glance the way Wi-Fi's on/off does (a filled vs outline
/// sun was too subtle at menu-bar size). A warning-badged sun means "degraded" (idle blocked, but
/// lid-close will still sleep).
enum MenuBarIcon {

    static func make(state: PowerController.AwakeState) -> NSImage {
        let symbol: String
        let weight: NSFont.Weight
        switch state {
        case .on:       (symbol, weight) = ("sun.max.fill", .semibold)
        case .degraded: (symbol, weight) = ("sun.max.trianglebadge.exclamationmark", .regular)
        case .off, .paused: (symbol, weight) = ("moon.zzz", .regular)   // paused: the Mac can sleep again
        }

        // 13pt (systemFontSize) reads visibly smaller than the neighboring Wi-Fi/battery items;
        // 16pt matches their visual weight without clipping the status bar.
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: weight)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Awake")?
            .withSymbolConfiguration(config)
            ?? composite(state: state)
        image.isTemplate = true
        return image
    }

    /// Fallback for when a named SF Symbol isn't present on the running OS (the degraded
    /// `sun.max.trianglebadge.exclamationmark` variant is the uncertain one): draw a base sun and,
    /// for degraded, stamp a small warning triangle in the corner — mirrors how Streak Tracker
    /// composites its flame + number into one template image.
    private static func composite(state: PowerController.AwakeState) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let base = NSImage(systemSymbolName: state == .on ? "sun.max.fill" : "sun.max",
                           accessibilityDescription: "Awake")?
            .withSymbolConfiguration(config) ?? NSImage()

        guard state == .degraded,
              let badge = NSImage(systemSymbolName: "exclamationmark.triangle.fill",
                                  accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(
                    pointSize: 10, weight: .bold))
        else { return base }

        let size = base.size
        let badgeSize = badge.size
        // Drawing-handler constructor (not lockFocus) so the composite is resolution-independent.
        return NSImage(size: size, flipped: false) { _ in
            base.draw(in: NSRect(origin: .zero, size: size))
            badge.draw(in: NSRect(x: size.width - badgeSize.width, y: 0,
                                  width: badgeSize.width, height: badgeSize.height))
            return true
        }
    }
}
