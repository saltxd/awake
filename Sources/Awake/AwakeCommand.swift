import Foundation

/// What an `awake://` link asks for: `awake://on`, `awake://off` or `awake://toggle`. Lets another app (or a phone,
/// through a helper on this Mac) flip Awake without going around it, so the menu bar always tells the truth.
enum AwakeCommand: Equatable {
    case on, off, toggle

    init?(url: URL) {
        guard url.scheme?.lowercased() == "awake" else { return nil }
        switch url.host()?.lowercased() {
        case "on": self = .on
        case "off": self = .off
        case "toggle": self = .toggle
        default: return nil
        }
    }
}

/// When to actually hold the Mac awake. Awake blocks lid-close sleep, so a Mac left "on" and slipped into a bag
/// would stay awake and run hot; by default it pauses on battery and picks back up once plugged in.
enum AwakePolicy {
    enum Target: Equatable {
        case hold, pause, release
    }

    static func target(wantsAwake: Bool, pauseOnBattery: Bool, onPower: Bool) -> Target {
        guard wantsAwake else { return .release }
        return pauseOnBattery && !onPower ? .pause : .hold
    }
}
