# Awake — design

*2026-07-11. Spec provided in full by saltxd; this doc records the decisions made
where the spec left room.*

## What it is

A menu-bar-only macOS utility (macOS 14+, `LSUIElement`) with one job: keep the
MacBook awake — including with the lid closed — via a single on/off toggle.
Visually it's a sibling of Streak Tracker: same `.window`-style `MenuBarExtra`
panel, same warm-amber accent family, same hover-row/toggle idioms.

## Architecture

Swift package mirroring streak-tracker's layout (no Xcode project; `build.sh`
assembles the `.app`; CI on `macos-15` builds and uploads the artifact because
local beta-macOS CLT can't build SwiftUI app targets).

| Path | Purpose |
|---|---|
| `Sources/Awake/AwakeApp.swift` | `@main` MenuBarExtra (`.window` style), `AppDelegate` lifecycle rails |
| `Sources/Awake/PowerController.swift` | `@Observable` state machine: `off` / `on` / `degraded`; IOKit assertion + `sudo -n pmset` |
| `Sources/Awake/AwakePanel.swift` | The styled panel (hero glyph + Keep Awake toggle + login + quit) |
| `Sources/Awake/MenuBarIcon.swift` | Template menu-bar glyph per state |
| `Sources/Awake/LoginItem.swift` | `SMAppService` wrapper (copied from streak-tracker) |
| `install.sh` | Installs the scoped sudoers rule via `visudo -cf` validation |
| `build.sh` | Builds + bundles `Awake.app`, ad-hoc signs |
| `.github/workflows/ci.yml` | macos-15 build + `.app` artifact |

## Power logic (two layers)

Toggle ON:
1. `IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep)` —
   blocks idle sleep.
2. `sudo -n /usr/bin/pmset disablesleep 1` via `Process` — blocks lid-close sleep.
   `-n` (non-interactive) so a missing sudoers rule fails fast instead of hanging.

Toggle OFF: release assertion, `sudo -n /usr/bin/pmset disablesleep 0`.

States: `off`, `on` (both layers active), `degraded` (assertion only — pmset
failed; lid-close will still sleep; warning glyph + explanatory text + one-time
`NSAlert` pointing at `install.sh`).

## Safety rails (priority over features)

- **Launch self-heal:** run `sudo -n pmset disablesleep 0` once on launch, always
  start in `off`. Recovers from a crash/power-loss that left `disablesleep 1` set.
  A failure here is silent (rule missing ⇒ we couldn't have set it via sudo either).
- **Quit restore:** `applicationWillTerminate` releases the assertion and runs
  `disablesleep 0`.
- **Crash-adjacent restore:** `SIGTERM`/`SIGINT`/`SIGHUP` handlers restore then exit.
  (A hard crash/SIGKILL can't be hooked — the launch self-heal covers that case.)
- Restore is idempotent and safe to call from multiple paths.

## Sudoers rule (`install.sh`)

```
<user> ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 1, /usr/bin/pmset disablesleep 0
```

Written to a temp file, validated with `visudo -cf`, installed as
`/etc/sudoers.d/awake` mode 0440. Scoped to exactly those two commands.

## Menu bar states

| State | Glyph |
|---|---|
| ON | `sun.max.fill` (template) |
| OFF | `sun.max` outline (template) |
| Degraded | sun + warning badge (`sun.max.trianglebadge.exclamationmark` or composite fallback) |

## Panel (mirrors Streak Tracker)

300 pt wide, 18/18/12 padding, `.window` MenuBarExtra. Hero: large sun glyph —
amber gradient when ON, `.tertiary` outline when OFF — over an uppercase tracked
caption and a status line. One prominent "Keep Awake" switch tinted with the
shared `warmAccent` (#FF9E3D dark / #E6731A light). Divider → "Launch at login"
switch row (same `PanelLabelStyle`) → divider → "Quit Awake" row with ⌘Q.
Degraded state adds a warning footnote + "Fix…" affordance re-showing the alert.

## Out of scope (YAGNI)

Timers/durations, battery-level guards, Sparkle updates, notarization, app icon
artwork, preferences window.
