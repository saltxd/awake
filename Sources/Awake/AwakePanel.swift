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
            keepAwakeCard.padding(.top, 16)
            if controller.state == .degraded {
                degradedNotice.padding(.top, 8)
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
        .animation(.spring(duration: 0.3), value: controller.state)
    }

    // MARK: Hero

    /// Glyph → big state word → tracked caption: the same hierarchy as Streak Tracker's
    /// flame → count → label, so the two apps read as siblings. The hero flips day/night with the
    /// toggle — an amber sun with a soft glow when Awake holds the Mac awake, a cool moonlight moon
    /// (matching the menu bar glyph) when sleep is back to normal — state you can read from across
    /// the room.
    private var hero: some View {
        let awake = controller.state != .off
        let degraded = controller.state == .degraded
        return VStack(spacing: 2) {
            Image(systemName: heroSymbol)
                .font(.system(size: 38, weight: awake ? .semibold : .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(degraded ? AnyShapeStyle(Color.orange)
                                 : awake ? AnyShapeStyle(amber) : AnyShapeStyle(moonlight))
                .shadow(color: awake && !degraded ? warmAccent.opacity(0.45) : .clear, radius: 12)
                .contentTransition(.symbolEffect(.replace))

            Text(stateWord)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(degraded ? AnyShapeStyle(Color.orange)
                                 : awake ? AnyShapeStyle(amber) : AnyShapeStyle(moonlight))
                .padding(.top, 2)

            Text(stateCaption)
                .font(.caption.weight(.medium))
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    private var heroSymbol: String {
        switch controller.state {
        case .on:       return "sun.max.fill"
        case .degraded: return "sun.max.trianglebadge.exclamationmark"
        case .off:      return "moon.zzz.fill"   // same glyph the menu bar shows when off
        }
    }

    private var stateWord: String {
        switch controller.state {
        case .on:       return "Awake"
        case .degraded: return "Limited"
        case .off:      return "Off"
        }
    }

    private var stateCaption: String {
        switch controller.state {
        case .on:       return "EVEN WITH THE LID CLOSED"
        case .degraded: return "LID-CLOSE WILL STILL SLEEP"
        case .off:      return "NORMAL SLEEP"
        }
    }

    // MARK: Centerpiece control

    private var keepAwake: Binding<Bool> {
        Binding(get: { controller.state != .off },
                set: { controller.setAwake($0) })
    }

    /// The one control that matters, shaped like a Control Center tile: a full-width card you can
    /// tap anywhere (the switch keeps its own hit area and wins where they overlap).
    private var keepAwakeCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.max")
                .frame(width: 16)
                .foregroundStyle(controller.state != .off ? AnyShapeStyle(warmAccent)
                                                          : AnyShapeStyle(.secondary))
            Text("Keep Awake")
                .font(.body.weight(.semibold))
            Spacer()
            Toggle("Keep Awake", isOn: keepAwake)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(cardHovering ? 0.09 : 0.06))
        )
        .onHover { cardHovering = $0 }
        .onTapGesture { keepAwake.wrappedValue.toggle() }
    }

    @State private var cardHovering = false

    // MARK: Degraded affordance

    private var degradedNotice: some View {
        PanelRow(title: "Enable lid-close blocking…", systemImage: "lock.open",
                 tint: warmAccent) {
            controller.enableLidClose()
        }
    }

    // MARK: Login

    /// Full-width utility row: label leading, switch trailing — anchored to the panel edges like
    /// every other row instead of hugging its content in the middle.
    private var loginRow: some View {
        HStack(spacing: 8) {
            Label("Launch at login", systemImage: "arrow.up.forward.app")
                .labelStyle(PanelLabelStyle())
            Spacer()
            Toggle("Launch at login", isOn: Binding(get: { loginItem.isEnabled },
                                                    set: { loginItem.setEnabled($0) }))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
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

    /// The off state's cool counterpart to `amber` — a muted periwinkle→indigo so the hero flips
    /// day/night with the toggle. Deliberately quieter than the amber: "on" stays the loud state.
    private var moonlight: LinearGradient {
        let stops: [Color] = scheme == .dark
            ? [Color(red: 0.65, green: 0.70, blue: 1.00), Color(red: 0.44, green: 0.45, blue: 0.92)]
            : [Color(red: 0.46, green: 0.50, blue: 0.92), Color(red: 0.31, green: 0.32, blue: 0.74)]
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
