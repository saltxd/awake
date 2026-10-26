import Foundation
import IOKit.ps

/// Tells Awake when the Mac switches between power adapter and battery.
@MainActor
final class PowerSourceMonitor {
    private var source: CFRunLoopSource?
    private let onChange: @MainActor (Bool) -> Void

    init(onChange: @escaping @MainActor (Bool) -> Void) {
        self.onChange = onChange
    }

    /// True on the power adapter (and on Macs without a battery).
    nonisolated static func isOnPower() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return true }
        return (type as String) == kIOPMACPowerKey
    }

    /// Fires on every power-source change (battery percentage included); the controller ignores the ones that
    /// don't switch between adapter and battery. The run-loop source lives on the main run loop, so the C callback
    /// already runs on the main thread.
    func start() {
        guard source == nil else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let created = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            MainActor.assumeIsolated {
                let monitor = Unmanaged<PowerSourceMonitor>.fromOpaque(context).takeUnretainedValue()
                monitor.onChange(PowerSourceMonitor.isOnPower())
            }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), created, .defaultMode)
        source = created
    }
}
