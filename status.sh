#!/usr/bin/env bash
set -euo pipefail

SERVICE_PREFIX="inotibatch@"
LOG_DIR="/var/log/inotibatch"
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

if [[ -d "/etc/inotibatch" ]]; then
  CONFIG_DIR="/etc/inotibatch"
else
  CONFIG_DIR="${CONFIG_DIR:-$SCRIPT_DIR/config}"
fi

printf "%-20s %-10s %-17s %-15s %-25s\n" "Instance" "Status" "Processed Files" "Errored Files" "Last Processed"
printf -- "-------------------------------------------------------------------------------------\n"

for conf_file in "$CONFIG_DIR"/*.conf; do
    instance_name="$(basename "$conf_file" .conf)"
    service="${SERVICE_PREFIX}${instance_name}"

    # Systemd status
    if systemctl is-active --quiet "$service"; then
        status="running"
    else
        status="stopped"
    fi

    # Number of files processed (post-hook counter, e.g. using wc -l in process.log or batch log)
    log="$LOG_DIR/${instance_name}.process.log"
    if [[ -f "$log" ]]; then
        last_ts=$(stat -c '%y' "$log" | cut -d'.' -f1)
    else
        last_ts="–"
    fi

    processed_file="$LOG_DIR/${instance_name}.processed"
    if [[ -f "$processed_file" ]]; then
        countProcessed=$(wc -l < "$processed_file" || echo "0")
    else
        countProcessed="0"
    fi

    errored_file="$LOG_DIR/${instance_name}.errored"
    if [[ -f "$errored_file" ]]; then
        countErrored=$(wc -l < "$errored_file" || echo "0")
    else
        countErrored="0"
    fi

    printf "%-20s %-10s %-17s %-15s %-25s\n" "$instance_name" "$status" "$countProcessed" "$countErrored" "$last_ts"
done
