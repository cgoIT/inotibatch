#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

shopt -s nocaseglob    # globs should be case-insensitive
shopt -s nullglob      # ensures that non-existent matches are left empty

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
CONFIG_DIR="${CONFIG_DIR:-$SCRIPT_DIR/../config}"

CONFIG_FILE="${CONFIG_DIR}/$1.conf"
[[ -f "$CONFIG_FILE" ]] || { echo "Config $1.conf not found in $CONFIG_DIR!" >&2; exit 1; }

set -a
# shellcheck source=config/default.conf.example
source "$CONFIG_FILE"
set +a

CONFIG_NAME="$1"
CONFIG_PATH="$CONFIG_FILE"
export CONFIG_NAME CONFIG_PATH

# Vars that must be defined (even if empty)
MUST_BE_DEFINED=(
  "PRE_HOOK_DIR"
  "POST_HOOK_DIR"
  "TARGET_OWNER"
  "MAIL_ON_ERROR"
  "POST_HOOK_BATCH_SIZE"
  "POST_HOOK_IDLE_TIMEOUT"
)

# Vars that must be defined AND non-empty
MUST_BE_NON_EMPTY=(
  "SOURCE_DIR"
  "TARGET_DIR"
  "ACTION_SCRIPT"
)

MISSING=()

for var in "${MUST_BE_DEFINED[@]}"; do
  if ! declare -p "$var" &>/dev/null; then
    MISSING+=("$var (undefined)")
  fi
done

for var in "${MUST_BE_NON_EMPTY[@]}"; do
  if [[ -z "${!var+x}" ]]; then
    MISSING+=("$var (undefined)")
  elif [[ -z "${!var}" ]]; then
    MISSING+=("$var (empty)")
  fi
done

if (( ${#MISSING[@]} > 0 )); then
  echo "❌ Invalid configuration in $CONFIG_FILE:"
  for var in "${MISSING[@]}"; do
    echo "   - $var"
  done
  exit 1
fi

PROCESSED_FILE="/var/log/inotibatch/$1.processed"
ERRORED_FILE="/var/log/inotibatch/$1.errored"

LOGFILE="/var/log/inotibatch/$1.log"
mkdir -p "$(dirname "$LOGFILE")"
exec >>"$LOGFILE" 2>&1

# Log file for hook & action script output
PROCESS_LOG="/var/log/inotibatch/${CONFIG_NAME}.process.log"
touch "$PROCESS_LOG"

BATCH_FILE="/tmp/inotibatch-$1.batch"
touch "$BATCH_FILE"
touch "$BATCH_FILE.lock"

log() {
  local timestamp
  timestamp="$(date +'%F %T')"
  if [[ -n "${LOG_PREFIX:-}" ]]; then
    echo "[$timestamp] [$LOG_PREFIX] $*"
  else
    echo "[$timestamp] $*"
  fi
}
export -f log

sanitize_filename() {
  local name="$1"
  echo "$name" | tr '[:upper:]' '[:lower:]' \
               | sed 's/ /_/g' \
               | sed 's/[^a-z0-9._-]/-/g' \
               | sed 's/--*/-/g'
}

should_skip_file() {
  local filename="$1"
  for pattern in "${EXCLUDE_PATTERNS[@]}"; do
      if [[ $filename == $pattern ]]; then
          return 0  # match found -> skip
      fi
  done
  return 1  # no match
}

run_action_script() {
  local src="$1"
  local dest="$2"

  if [[ -x "$ACTION_SCRIPT" ]]; then
    LOG_PREFIX="ACTION" "$ACTION_SCRIPT" "$CONFIG_NAME" "$src" "$dest" >>"$PROCESS_LOG" 2>&1
  else
    log "ERROR" "Action script $ACTION_SCRIPT not found or not executable!" >&2
  fi
}

run_hooks() {
  local hook_dir="$1"
  shift
  for script in "$hook_dir"/*; do
    [[ -x "$script" ]] || continue
    LOG_PREFIX="$(basename "$hook_dir")"
    log "Running hook: $script"
    LOG_PREFIX="$(basename "$hook_dir")" "$script" "$CONFIG_NAME" "$@" >>"$PROCESS_LOG" 2>&1
  done
}

queue_file_for_batch() {
  (
    flock -x 200 || { log "Failed to acquire lock in queue_file_for_batch" >&2; exit 1; }
    if ! echo "$1" >> "$BATCH_FILE"; then
      log "Failed to write to batch file" >&2
      exit 1
    fi
  ) 200>"$BATCH_FILE.lock"
}

flush_batch() {
  (
    flock -x 200 || { log "Failed to acquire lock in flush_batch" >&2; exit 1; }

    # Check if batch file is empty
    if [[ ! -s "$BATCH_FILE" ]]; then
      return 0
    fi

    TMP_BATCH="${BATCH_FILE}.processing"

    if ! mv "$BATCH_FILE" "$TMP_BATCH"; then
      log "Failed to rename batch file" >&2
      exit 1
    fi

    # Create new empty batch file for further entries
    if ! touch "$BATCH_FILE"; then
      log "Failed to create new batch file" >&2
      # Try renaming TMP_BATCH so you don't lose anything.
      mv "$TMP_BATCH" "$BATCH_FILE" || log "Critical: Could not restore batch file!" >&2
      exit 1
    fi

    if ! mapfile -t files < "$TMP_BATCH"; then
      log "Failed to read files from temporary batch file" >&2
      # Try to delete temporary file, but do not exit, as it may be recoverable.
      rm -f "$TMP_BATCH"
      exit 1
    fi

    LOG_PREFIX="$POST_HOOK_DIR"
    log "Post-Hook for ${#files[@]} files"

    if run_hooks "$POST_HOOK_DIR" "${files[@]}"; then
      for f in "${files[@]}"; do
        echo "$(date +'%F %T') $f" >> "${PROCESSED_FILE}"
      done
    else
      echo "Post-hook execution failed" >&2
      for f in "${files[@]}"; do
        echo "$(date +'%F %T') $f" >> "${ERRORED_FILE}"
      done

      log "Post-hook execution failed" >&2
      rm -f "$TMP_BATCH"
      exit 1
    fi

    rm -f "$TMP_BATCH"
  ) 200>"$BATCH_FILE.lock"
}

watch_batch_timeout() {
  while true; do
    sleep 5

    local now=$(date +%s)
    local last_mod=0
    local queued=0

    (
      flock -s 200 || { log "Failed to acquire shared lock in watch_batch_timeout" >&2; continue; }
      if [[ -f "$BATCH_FILE" ]]; then
        last_mod=$(stat -c %Y "$BATCH_FILE" 2>/dev/null || echo 0)
        queued=$(wc -l < "$BATCH_FILE" 2>/dev/null || echo 0)
      fi
    ) 200<"$BATCH_FILE.lock"

    if (( queued >= POST_HOOK_BATCH_SIZE )) || (( now - last_mod >= POST_HOOK_IDLE_TIMEOUT )); then
      flush_batch || log "flush_batch failed in watch_batch_timeout" >&2
    fi
  done
}

process_file() {
  local event="$1"
  local src="$2"
  local rel_path="${src#$SOURCE_DIR/}"
  local dir_part
  dir_part=$(dirname "$rel_path")
  local base_name
  base_name="$(basename "$rel_path")"
  local target_base="$base_name"

  [[ "$SANITIZE_FILENAMES" == "true" ]] && target_base=$(sanitize_filename "$base_name")

  local dest="$(realpath -m "$TARGET_DIR/$dir_part/$target_base")"

  log "Processing: event=$event, src=$src, dest=$dest"

  if [[ -n "${PRE_HOOK_DIR}" ]]; then
    run_hooks "$PRE_HOOK_DIR" "$src" "$dest"
  fi

  run_action_script "$src" "$dest"

  if [[ -n "${POST_HOOK_DIR}" ]]; then
    queue_file_for_batch "$dest"
    log "Processed file and stored for post-hook: src=$src, dest=$dest"
  else
    log "Processed file: src=$src, dest=$dest"
  fi
}

inotifywait_loop() {
  local args=(-m -e close_write,create,modify --format '%w%f|%e')
  [[ "$RECURSIVE" == "true" ]] && args+=(-r)

  LOG_PREFIX="inotifywait"
  inotifywait "${args[@]}" "$SOURCE_DIR" | while IFS=$'|' read -r file event; do
    if [[ "$file" = /* ]]; then
      local skip=false
      if should_skip_file "$file"; then
        skip=true
      fi
      $skip || process_file "$event" "$file" < /dev/null
    fi
  done
}

trap_error() {
  local msg="$1"
  log "ERROR: $msg"
  if [[ -n "$EMAIL_ON_ERROR" ]]; then
    echo "$msg" | mail -s "File Sync Error in Instance $1" "$EMAIL_ON_ERROR"
  fi
}

main() {
  log "Start inotibatch, instance: $1"

  # Start background task in monitoring loop
  (
    while true; do
      watch_batch_timeout
      log "watch_batch_timeout has ended — Restart"
      sleep 1  # Wait briefly to avoid starting an endless loop too quickly.
    done
  ) &

  inotifywait_loop || trap_error "inotifywait failed for instance $1"
}

main "$1"
