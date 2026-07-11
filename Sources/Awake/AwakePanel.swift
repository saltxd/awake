import SwiftUI
import AppKit

/// The `.window`-style popover shown when you click the menu bar sun.
///
/// Design mirrors Streak Tracker: a warm-amber hero (here a sun that lights up when awake), a
/// single prominent switch as the centerpiece, then quiet login/quit rows. The degraded warning
/// stays on the dependable AppKit `NSAlert` path (owned by the controller) rather than a SwiftUI
/// sheet, which is unreliable from a `.window` MenuBarExtra popover.
struct AwakePanel: View {
    let controller: PowerController
    let loginItem: LoginItem

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            hero
            keepAwakeToggle
            if controller.state == .degraded {
                degradedNotice
            }

            Divider().padding(.horizontal, 4).padding(.vertical, 12)

            loginRow

            Divider().padding(.horizontal, 4).padding(.vertical, 6)

            PanelRow(title: "Quit Awake", systemImage: "power",
                     showIcon: false, trailing: "⌘Q") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .frame(width: 300)
        .tint(warmAccent)   // drives the switch tint consistently on every Mac
        .animation(.easeInOut(duration: 0.25), value: controller.state)
    }

    // MARK: Hero

    private var hero: some View {
        let awake = controller.state != .off
        let degraded = controller.state == .degraded
        return VStack(spacing: 2) {
            Image(systemName: heroSymbol)
                .font(.system(size: 34, weight: awake ? .semibold : .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(degraded ? AnyShapeStyle(Color.orange)
                                 : awake ? AnyShapeStyle(amber) : AnyShapeStyle(.tertiary))

            Text(statusCaption)
                .font(.caption.weight(.medium))
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .padding(.top, 4)   // breathe between the glyph and its caption

            Text(statusDetail)
                .font(.caption)
                .foregroundStyle(.secondary)   // .tertiary can drop below legible on vibrancy
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    private var heroSymbol: String {
        switch controller.state {
        case .on:       return "sun.max.fill"
        case .degraded: return "sun.max.trianglebadge.exclamationmark"
        case .off:      return "sun.max"
        }
    }

    private var statusCaption: String {
        switch controller.state {
        case .on:       return "AWAKE"
        case .degraded: return "AWAKE — LIMITED"
        case .off:      return "SLEEP NORMALLY"
        }
    }

    private var statusDetail: String {
        switch controller.state {
        case .on:       return "Mac stays awake — even with the lid closed"
        case .degraded: return "Awake while the lid is open — lid-close will still sleep (pmset rule missing)"
        case .off:      return "Normal sleep behavior"
        }
    }

    // MARK: Centerpiece control

    /// The one control that matters — a prominent switch, semibold label, padded like a PanelRow so
    /// it sits flush with the rows below.
    private var keepAwakeToggle: some View {
        Toggle(isOn: Binding(get: { controller.state != .off },
                             set: { controller.setAwake($0) })) {
            Label("Keep Awake", systemImage: "sun.max")
                .font(.body.weight(.semibold))
                .labelStyle(PanelLabelStyle())
        }
        .toggleStyle(.switch)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .padding(.top, 14)   // set the centerpiece apart from the hero caption
    }

    // MARK: Degraded affordance

    private var degradedNotice: some View {
        VStack(spacing: 4) {
            Text("Lid-close sleep isn’t blocked yet — run ./install.sh once to enable it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.top, 6)
            PanelRow(title: "How to fix lid-close…", systemImage: "exclamationmark.triangle",
                     tint: .secondary, iconTint: .orange) {
                controller.showDegradedAlert(force: true)
            }
        }
    }

    // MARK: Login

    private var loginRow: some View {
        Toggle(isOn: Binding(get: { loginItem.isEnabled },
                             set: { loginItem.setEnabled($0) })) {
            Label("Launch at login", systemImage: "arrow.up.forward.app")
                .labelStyle(PanelLabelStyle())
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)   // match PanelRow's vertical padding so the column aligns
    }

    // MARK: Styling helpers

    private var amber: LinearGradient {
        let stops: [Color] = scheme == .dark
            ? [Color(red: 1.00, green: 0.80, blue: 0.42), Color(red: 1.00, green: 0.52, blue: 0.22)]
            : [Color(red: 1.00, green: 0.70, blue: 0.24), Color(red: 0.96, green: 0.38, blue: 0.13)]
        return LinearGradient(colors: stops, startPoint: .top, endPoint: .bottom)
    }

    /// UI accent in the amber family. Set app-wide (not the system accent) so interactive bits read
    /// as ours and look the same on every Mac, regardless of the user's macOS accent.
    private var warmAccent: Color {
        scheme == .dark
            ? Color(red: 1.00, green: 0.62, blue: 0.24)   // #FF9E3D — brighter on dark vibrancy
            : Color(red: 0.90, green: 0.45, blue: 0.10)   // #E6731A — deeper for AA on light
    }
}

/// A full-width tappable row with a native menu-style hover highlight — what makes a `.window`
/// popover (which has no free menu chrome) still feel like a menu. Trimmed from Streak Tracker's.
private struct PanelRow: View {
    let title: String
    var systemImage: String = ""
    var tint: Color = .primary
    var iconTint: Color? = nil          // overrides the resting icon color
    var showIcon: Bool = true
    var trailing: String? = nil
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if showIcon {
                    Image(systemName: systemImage)
                        .frame(width: 16)
                        .foregroundStyle(iconTint.map { AnyShapeStyle($0) }
                                         ?? (tint == .primary ? AnyShapeStyle(.secondary) : AnyShapeStyle(tint)))
                }
                Text(title)
                    .foregroundStyle(tint)
                Spacer()
                if let trailing {
                    Text(trailing).foregroundStyle(.tertiary)
                }
            }
            .font(.body)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(hovering ? Color.primary.opacity(0.07) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Label style that matches PanelRow spacing for the toggle rows.
private struct PanelLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.frame(width: 16).foregroundStyle(.secondary)
            configuration.title
        }
    }
}
