import AppKit
import IOKit.pwr_mgt
import Observation

/// Drives the two independent "stay awake" mechanisms and exposes a single tri-state.
///
/// Two layers, because neither alone does the whole job:
///   1. An IOPMAssertion (`PreventUserIdleSystemSleep`) blocks the *idle* sleep timer.
///   2. `pmset disablesleep 1` (root) blocks *lid-close* sleep — the assertion can't.
/// When layer 2 fails (no sudoers rule) we sit in `.degraded`: idle sleep is blocked, but closing
/// the lid will still sleep — and we say so rather than silently under-delivering.
///
/// MainActor-bound and synchronous on purpose: pmset returns in a fraction of a second, so a
/// blocking `Process` on the main thread keeps the control flow simple and dodges Sendable-capture
/// warnings. Correctness of the normal on/off/restore paths matters more than shaving that latency.
@MainActor
@Observable
final class PowerController {
    enum AwakeState { case off, on, degraded }

    private(set) var state: AwakeState = .off

    /// The held idle-sleep assertion, or nil when none is active. Mirrored into a static
    /// (`emergencyAssertionID`) so a signal handler — which can't reach the main actor — can still
    /// release it on the way out.
    private var assertionID: IOPMAssertionID?

    /// One NSAlert per app run explaining degraded mode; the panel's "Fix…" row can re-show it.
    private var alertShown = false

    // MARK: Control

    func setAwake(_ on: Bool) {
        if on { turnOn() } else { restore() }
    }

    private func turnOn() {
        acquireAssertion()
        if runPmset(disable: true) {
            state = .on
        } else {
            // Keep the assertion (idle sleep stays blocked) but flag that lid-close isn't covered.
            state = .degraded
            NSLog("[Awake] pmset disablesleep 1 failed — degraded (lid-close will still sleep)")
            showDegradedAlert()
        }
    }

    /// Idempotent teardown, safe to call from any path (toggle-off, quit, error, or repeatedly):
    /// releases the assertion if held and always clears the root sleep-disable flag.
    func restore() {
        releaseAssertion()
        _ = runPmset(disable: false)
        state = .off
    }

    /// Run once at launch: clear any leftover `disablesleep 1` from a crash or power-loss that
    /// skipped our normal teardown, then start clean. Silent — if the sudoers rule is missing we
    /// could not have set the flag in the first place, so there is nothing to undo.
    func selfHealAtLaunch() {
        _ = runPmset(disable: false)
        state = .off
    }

    /// Explain degraded mode once per run and offer the one-click fix. Re-shown on demand.
    func showDegradedAlert(force: Bool = false) {
        guard force || !alertShown else { return }
        alertShown = true
        NSApp.activate(ignoringOtherApps: true)
        defer { NSApplication.shared.deactivate() }
        let alert = NSAlert()
        alert.messageText = "Lid-close sleep isn’t blocked yet"
        alert.informativeText = """
            Awake is keeping your Mac awake while the lid is open, but closing the lid will still \
            put it to sleep.

            Blocking lid-close sleep needs a one-time system rule. Click Enable and macOS will ask \
            for your password once. The rule allows exactly two commands — pmset disablesleep 1 \
            and 0 — and nothing else. (Prefer to see it first? Run ./install.sh from the repo.)
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Enable…")
        alert.addButton(withTitle: "Not Now")
        if alert.runModal() == .alertFirstButtonReturn {
            enableLidClose()
        }
    }

    /// One-time, in-app install of the scoped sudoers rule through the native macOS admin-password
    /// prompt — the download-only user has no repo checkout and no Terminal habit, so this is their
    /// path to full mode. Writes the same visudo-validated rule as install.sh; a cancelled prompt
    /// just leaves us degraded. On success the pending intent completes: degraded promotes to on.
    func enableLidClose() {
        let rule = "\(NSUserName()) ALL=(root) NOPASSWD: "
            + "/usr/bin/pmset disablesleep 1, /usr/bin/pmset disablesleep 0"
        let cmd = "TMP=$(/usr/bin/mktemp) && /bin/echo '\(rule)' > \"$TMP\" "
            + "&& /usr/sbin/visudo -cf \"$TMP\" "
            + "&& /usr/bin/install -m 0440 -o root -g wheel \"$TMP\" /etc/sudoers.d/awake "
            + "&& /bin/rm -f \"$TMP\""
        let escaped = cmd
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        NSApp.activate(ignoringOtherApps: true)
        var error: NSDictionary?
        let ok = NSAppleScript(source: source)?.executeAndReturnError(&error) != nil
        if ok {
            if state == .degraded, runPmset(disable: true) { state = .on }
        } else if let error, (error[NSAppleScript.errorNumber] as? Int) != -128 {   // -128 = user cancelled
            NSLog("[Awake] lid-close setup failed: \(error)")
        }
    }

    // MARK: IOKit assertion

    private func acquireAssertion() {
        guard assertionID == nil else { return }
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Awake — keep system awake" as CFString,
            &id)
        if result == kIOReturnSuccess {
            assertionID = id
            PowerController.emergencyAssertionID = id
        } else {
            NSLog("[Awake] IOPMAssertionCreateWithName failed: \(result)")
        }
    }

    private func releaseAssertion() {
        guard let id = assertionID else { return }
        IOPMAssertionRelease(id)
        assertionID = nil
        PowerController.emergencyAssertionID = nil
    }

    // MARK: pmset

    /// Toggle the root lid-close sleep block. `-n` (non-interactive) makes a missing sudoers rule
    /// fail immediately instead of prompting or hanging. Returns whether pmset exited 0. A launch
    /// failure is caught and logged so a broken Process can never crash the app.
    @discardableResult
    private func runPmset(disable: Bool) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", "/usr/bin/pmset", "disablesleep", disable ? "1" : "0"]
        // sudo -n prints to stderr when the rule is missing; swallow it to keep Console quiet.
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            NSLog("[Awake] launching pmset failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: Emergency (signal-handler) restore
    //
    // Signal handlers run outside the main actor and can't touch instance state or Swift
    // concurrency, so we mirror the live assertion ID into this static. A blocking Process and
    // IOKit release aren't strictly async-signal-safe, but this path only runs as we tear down
    // toward exit() — the pragmatic tradeoff the design accepts. A hard SIGKILL can't be hooked at
    // all; the launch self-heal covers that case on the next start.

    /// nonisolated(unsafe): a signal handler needs plain global access to the current assertion ID;
    /// the only writers are `acquire`/`releaseAssertion` on the main actor, so races don't arise.
    nonisolated(unsafe) static var emergencyAssertionID: IOPMAssertionID?

    nonisolated static func emergencyRestore() {
        if let id = emergencyAssertionID {
            IOPMAssertionRelease(id)
            emergencyAssertionID = nil
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", "/usr/bin/pmset", "disablesleep", "0"]
        if (try? process.run()) != nil {
            process.waitUntilExit()
        }
    }
}
