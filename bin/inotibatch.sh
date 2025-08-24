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

SPOOL_DIR="/var/spool/inotibatch"
mkdir -p "$SPOOL_DIR"
BATCH_FILE="${SPOOL_DIR}/${CONFIG_NAME}.batch"
BATCH_LOCK="${SPOOL_DIR}/${CONFIG_NAME}.lock"
touch "$BATCH_FILE"
touch "$BATCH_LOCK"

log() {
  local level msg timestamp
  timestamp="$(date +'%F %T')"

  case "${1:-}" in
    INFO|DEBUG|WARN|ERROR)
      level="$1"
      shift
      ;;
    *)
      level="INFO"
      ;;
  esac
  msg="$*"

  # Debug logs only when DEBUG is enabled
  if [[ "$level" == "DEBUG" && "${DEBUG:-false}" != "true" ]]; then
    return 0
  fi

  if [[ -n "${LOG_PREFIX:-}" ]]; then
    echo "[$timestamp] [$level] [$LOG_PREFIX] $msg"
  else
    echo "[$timestamp] [$level] $msg"
  fi
}
export -f log

sanitize_filename() {
  local name
  name="$1"

  log "DEBUG" "Sanitizing filename: $name"
  echo "$name" | tr '[:upper:]' '[:lower:]' \
               | sed 's/ /_/g' \
               | sed 's/[^a-z0-9._-]/-/g' \
               | sed 's/--*/-/g'
}

should_skip_file() {
  local filename
  filename="$1"

  for pattern in "${EXCLUDE_PATTERNS[@]}"; do
      # shellcheck disable=SC2053
      if [[ $filename == $pattern ]]; then
          log "DEBUG" "Skipping file $filename due to pattern $pattern"
          return 0  # match found -> skip
      fi
  done
  return 1  # no match
}

run_action_script() {
  local src dest
  src="$1"
  dest="$2"

  log "DEBUG" "Executing action script $ACTION_SCRIPT with src=$src dest=$dest"
  if [[ -x "$ACTION_SCRIPT" ]]; then
    LOG_PREFIX="ACTION" "$ACTION_SCRIPT" "$CONFIG_NAME" "$src" "$dest" >>"$PROCESS_LOG" 2>&1
  else
    log "ERROR" "Action script $ACTION_SCRIPT not found or not executable!" >&2
  fi
}

run_hooks() {
  local hook_dir
  hook_dir="$1"
  shift

  if [[ -n "${hook_dir}" ]]; then
    for script in "$hook_dir"/*; do
      [[ -x "$script" ]] || continue
      log "DEBUG" "Preparing to run hook $script with args: $*"
      LOG_PREFIX="$(basename "$hook_dir")"
      log "INFO" "Running hook: $script"
      LOG_PREFIX="$(basename "$script")" "$script" "$CONFIG_NAME" "$@" >>"$PROCESS_LOG" 2>&1
    done
  fi
}

queue_file_for_batch() {
  {
    flock -x 200 || { log "ERROR" "Failed to acquire lock in queue_file_for_batch" >&2; return 1; }
    log "DEBUG" "Queueing file for batch: $1"
    if ! echo "$1" >> "$BATCH_FILE"; then
      log "ERROR" "Failed to write to batch file" >&2
      return 1
    fi
  } 200>"$BATCH_LOCK"
}

flush_batch() {
  {
    flock -x 200 || { log "ERROR" "Failed to acquire lock in flush_batch" >&2; return 1; }

    if [[ ! -s "$BATCH_FILE" ]]; then
      log "DEBUG" "No files to flush, batch file empty"
      return 0
    fi

    TMP_BATCH="${BATCH_FILE}.processing"

    log "DEBUG" "Copying batch file to $TMP_BATCH"
    if ! cp "$BATCH_FILE" "$TMP_BATCH"; then
      log "ERROR" "Failed to copy batch file" >&2
      return 1
    fi

    if ! mapfile -t files < "$TMP_BATCH"; then
      log "ERROR" "Failed to read files from temporary batch file" >&2
      rm -f "$TMP_BATCH"
      return 1
    fi

    : > "$BATCH_FILE"
    log "DEBUG" "Emptied batch file after copying"

    log "DEBUG" "Loaded ${#files[@]} files from $TMP_BATCH"
    LOG_PREFIX="$POST_HOOK_DIR"
    log "INFO" "Post-Hook for ${#files[@]} files"

    if run_hooks "$POST_HOOK_DIR" "${files[@]}"; then
      for f in "${files[@]}"; do
        log "DEBUG" "Marking file as processed: $f"
        echo "$(date +'%F %T') $f" >> "${PROCESSED_FILE}"
      done
    else
      for f in "${files[@]}"; do
        log "DEBUG" "Marking file as errored: $f"
        echo "$(date +'%F %T') $f" >> "${ERRORED_FILE}"
      done
      log "ERROR" "Post-hook execution failed" >&2
      rm -f "$TMP_BATCH"
      return 1
    fi

    rm -f "$TMP_BATCH"
    log "DEBUG" "Removed temporary batch file $TMP_BATCH"
  } 200>"$BATCH_LOCK"
}

watch_batch_timeout() {
  local batch_size idle_timeout last_flush now queued

  batch_size="${1}"
  idle_timeout="${2}"
  last_flush=$(date +%s)

  log "DEBUG" "Starting watch_batch_timeout with batch_size=$batch_size, idle_timeout=$idle_timeout"

  while true; do
    sleep 5
    now=$(date +%s)
    queued=0

    {
      flock -s 200 || { log "ERROR" "Failed to acquire shared lock in watch_batch_timeout" >&2; continue; }
      if [[ -f "$BATCH_FILE" ]]; then
        queued=$(grep -c '' "$BATCH_FILE" 2>/dev/null)
      fi
    } 200<"$BATCH_LOCK"

    log "DEBUG" "queued=$queued, now=$now, last_flush=$last_flush, age=$(( now - last_flush )), batch_size=$batch_size, idle_timeout=$idle_timeout"

    if (( queued >= batch_size )) || { (( now - last_flush >= idle_timeout )) && (( queued > 0 )); }; then
      log "INFO" "Flush batched files for post processing. queued=$queued, last_run=$last_flush"
      last_flush=$(date +%s)
      flush_batch || log "ERROR" "flush_batch failed in watch_batch_timeout" >&2
    fi
  done
}

process_file() {
  local event src rel_path dir_part base_name target_base dest

  event="$1"
  src="$2"
  rel_path="${src#$SOURCE_DIR/}"
  dir_part=$(dirname "$rel_path")
  base_name="$(basename "$rel_path")"
  target_base="$base_name"

  [[ "$SANITIZE_FILENAMES" == "true" ]] && target_base=$(sanitize_filename "$base_name")

  dest="$(realpath -m "$TARGET_DIR/$dir_part/$target_base")"

  log "INFO" "Processing event=$event, src=$src, dest=$dest"

  run_hooks "$PRE_HOOK_DIR" "$src" "$dest"
  run_action_script "$src" "$dest"
  queue_file_for_batch "$dest"

  log "INFO" "File queued for post-hook: src=$src dest=$dest"
}

inotifywait_loop() {
  local args skip
  # shellcheck disable=SC2054
  args=(-m -e close_write,create,modify --format '%w%f|%e')
  [[ "$RECURSIVE" == "true" ]] && args+=(-r)

  LOG_PREFIX="inotifywait"
  log "DEBUG" "Starting inotifywait with args: ${args[*]} on $SOURCE_DIR"

  inotifywait "${args[@]}" "$SOURCE_DIR" | while IFS=$'|' read -r file event; do
    log "DEBUG" "inotify event: $event for file $file"
    if [[ "$file" = /* ]]; then
      skip=false
      if should_skip_file "$file"; then
        skip=true
      fi
      $skip || process_file "$event" "$file" < /dev/null
    fi
  done
}

trap_error() {
  local msg
  msg="$1"

  log "ERROR" "$msg"
  if [[ -n "$EMAIL_ON_ERROR" ]]; then
    echo "$msg" | mail -s "File Sync Error in Instance $1" "$EMAIL_ON_ERROR"
  fi
}

main() {
  log "INFO" "Start inotibatch, instance: $1"

  # Start background task in monitoring loop
  (
    while true; do
      watch_batch_timeout "${POST_HOOK_BATCH_SIZE}" "${POST_HOOK_IDLE_TIMEOUT}"
      log "ERROR" "watch_batch_timeout has ended — Restart"
      sleep 1  # Wait briefly to avoid starting an endless loop too quickly.
    done
  ) &

  inotifywait_loop || trap_error "inotifywait failed for instance $1"
}

main "$1"
