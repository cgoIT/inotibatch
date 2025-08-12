#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
if [[ -d "/etc/inotibatch" ]]; then
  CONFIG_DIR="/etc/inotibatch"
else
  CONFIG_DIR="${CONFIG_DIR:-$SCRIPT_DIR/config}"
fi

SYSTEMD_DIR="/etc/systemd/system"

SERVICE_NAME_PREFIX="inotibatch@"
SERVICE_TEMPLATE_FILE="${SYSTEMD_DIR}/${SERVICE_NAME_PREFIX}.service"

if [[ ! -f "$SERVICE_TEMPLATE_FILE" ]]; then
  echo "❌ Service-Template nicht gefunden: $SERVICE_TEMPLATE_FILE"
  exit 1
fi

echo "🔍 Searching for config files in: $CONFIG_DIR"
for config_file in "$CONFIG_DIR"/*.conf; do
  [[ -e "$config_file" ]] || continue
  config_name="$(basename "$config_file" .conf)"
  service_name="${SERVICE_NAME_PREFIX}${config_name}.service"

  if systemctl status $service_name &>/dev/null; then
    echo "⚠️  Skipping existing service: $service_name"
    continue
  fi

  echo "🛠  Creating service for config: $config_name"

  # Interaktiv aktivieren/starten?
  read -rp "👉 Start and enable $service_name? [y/N] " reply
  if [[ "$reply" =~ ^[Yy]$ ]]; then
    systemctl enable --now "$service_name"
    echo "✅ Started and enabled $service_name"
  else
    systemctl enable "$service_name"
    echo "ℹ️  Created, but not started: $service_name"
  fi
done
