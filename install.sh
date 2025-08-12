#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Installing InotiBatch..."

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/system/inotibatch@.service"
INSTALL_TARGET="/etc/systemd/system/inotibatch@.service"
MAIN_SCRIPT="$SCRIPT_DIR/bin/inotibatch.sh"
LOG_DIR="/var/log/inotibatch"
CONFIG_DIR="/etc/inotibatch"
LOGROTATE_SOURCE="$SCRIPT_DIR/logrotate/inotibatch"
LOGROTATE_TARGET="/etc/logrotate.d/inotibatch"

REQUIRED_BINARIES=("inotifywait" "mail" "flock" "stat")

# --- Check prerequisites ---
echo "🔍 Checking requirements..."
for bin in "${REQUIRED_BINARIES[@]}"; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "❌ Required command not found: $bin"
    exit 1
  fi
done

# --- Check main script ---
if [[ ! -x "$MAIN_SCRIPT" ]]; then
  echo "❌ Main script not found or not executable: $MAIN_SCRIPT"
  exit 1
fi

# --- Check template ---
if [[ ! -f "$TEMPLATE" ]]; then
  echo "❌ Service template not found: $TEMPLATE"
  exit 1
fi

# --- Install systemd service ---
echo "📝 Installing systemd service template..."
sed "s|/path/to/inotibatch.sh|$MAIN_SCRIPT|g" "$TEMPLATE" > "$INSTALL_TARGET"
chmod 644 "$INSTALL_TARGET"

# --- Prepare config directory ---
mkdir -p "$CONFIG_DIR"
chmod 755 "$CONFIG_DIR"

# --- Prepare log directory ---
mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

# --- Install logrotate config ---
if [[ -f "$LOGROTATE_SOURCE" ]]; then
  echo "🌀 Installing logrotate config..."
  cp "$LOGROTATE_SOURCE" "$LOGROTATE_TARGET"
  chmod 644 "$LOGROTATE_TARGET"
else
  echo "⚠️  Logrotate config not found: $LOGROTATE_SOURCE"
fi

# --- Reload systemd ---
echo "🔄 Reloading systemd..."
systemctl daemon-reexec
systemctl daemon-reload

echo "✅ InotiBatch installed successfully!"
echo "ℹ️  You can now enable services like: systemctl enable --now inotibatch@<name>"
