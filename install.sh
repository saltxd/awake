#!/usr/bin/env bash
# Install the scoped sudoers rule that lets Awake block lid-close sleep without a password.
#
# Awake runs `sudo -n /usr/bin/pmset disablesleep {0,1}`. Without this rule that call fails and the
# app runs "degraded" (idle sleep blocked, but closing the lid still sleeps). This grants exactly
# those two commands NOPASSWD — nothing else. Run it once:  ./install.sh
set -euo pipefail

RULE_FILE="/etc/sudoers.d/awake"

# The human who should get the grant. When run via `sudo ./install.sh`, SUDO_USER is that human;
# run plainly, it's whoami (the script sudo's for itself below).
TARGET_USER="${SUDO_USER:-$(whoami)}"
if [[ "$TARGET_USER" == "root" ]]; then
  echo "Refusing to grant the rule to root. Run ./install.sh as your normal user." >&2
  exit 1
fi

RULE="$TARGET_USER ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 1, /usr/bin/pmset disablesleep 0"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
printf '%s\n' "$RULE" > "$TMP"

echo "▶ Validating sudoers rule…"
if ! visudo -cf "$TMP"; then
  echo "✗ Generated rule failed validation — not installing." >&2
  exit 1
fi

echo "▶ Installing $RULE_FILE (you may be prompted for your password)…"
sudo install -m 0440 -o root -g wheel "$TMP" "$RULE_FILE"

echo ""
echo "✅ Installed. Verify with:"
echo "     sudo -n /usr/bin/pmset disablesleep 0 && echo OK"
echo ""
echo "Then toggle Keep Awake in the menu bar — the degraded warning should be gone."
