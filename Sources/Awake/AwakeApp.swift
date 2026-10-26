import SwiftUI
import AppKit

@main
struct AwakeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            AwakePanel(controller: delegate.controller, loginItem: delegate.loginItem)
        } label: {
            AwakeLabel(controller: delegate.controller)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The menu-bar glyph — a template sun that fills when awake and gains a warning badge when
/// degraded. A dedicated view that reads the observed `state` *inside* its body so Observation
/// re-renders it the instant the toggle flips.
private struct AwakeLabel: View {
    let controller: PowerController
    var body: some View {
        Image(nsImage: MenuBarIcon.make(state: controller.state))
            .renderingMode(.template)
    }
}

/// Owns app-lifetime concerns: the single PowerController and the launch/quit/crash safety rails.
/// Keeping teardown here (not in the SwiftUI graph) guarantees we always release the assertion and
/// clear the root sleep-disable flag, even if the panel was never opened.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = PowerController()
    let loginItem = LoginItem()
    private lazy var powerMonitor = PowerSourceMonitor { [controller] onPower in
        controller.powerSourceChanged(onPower: onPower)
    }

    /// Before any event arrives: recover from a prior crash/power-loss that may have left `disablesleep 1` set, then
    /// take `awake://` links. (An `awake://on` that launched Awake can be delivered before didFinishLaunching, so
    /// the self-heal has to come first or it would undo the link.)
    func applicationWillFinishLaunching(_ notification: Notification) {
        controller.selfHealAtLaunch()
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Install the signal rails so an orderly kill still restores normal sleep.
        installSignalHandlers()
        powerMonitor.start()
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let text = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: text), let command = AwakeCommand(url: url) else { return }
        controller.perform(command)
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.restore()
    }

    /// SIGTERM/SIGINT/SIGHUP restore power state then exit. The handlers are closures with no
    /// captures so they convert to C function pointers; they only call the nonisolated
    /// `emergencyRestore`. A hard SIGKILL can't be hooked — the launch self-heal covers that.
    private func installSignalHandlers() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig) { received in
                PowerController.emergencyRestore()
                exit(128 + received)
            }
        }
    }
}
