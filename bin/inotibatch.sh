#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

shopt -s nocaseglob    # Globs should be case-insensitive
shopt -s nullglob      # Non-existent glob matches are empty

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
CONFIG_DIR="${CONFIG_DIR:-$SCRIPT_DIR/../config}"

CONFIG_FILE="${CONFIG_DIR}/$1.conf"
[[ -f "$CONFIG_FILE" ]] || { echo "Config $1.conf not found in $CONFIG_DIR!" >&2; exit 1; }

# Load configuration
set -a
# shellcheck source=config/default.conf.example
source "$CONFIG_FILE"
set +a

CONFIG_NAME="$1"
CONFIG_PATH="$CONFIG_FILE"
export CONFIG_NAME CONFIG_PATH

# Required variables (defined and/or non-empty)
MUST_BE_DEFINED=(
  "PRE_HOOK_DIR"
  "POST_HOOK_DIR"
  "TARGET_OWNER"
  "MAIL_ON_ERROR"
  "POST_HOOK_BATCH_SIZE"
  "POST_HOOK_IDLE_TIMEOUT"
)
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

# Paths
PROCESSED_FILE="/var/log/inotibatch/$CONFIG_NAME.processed"
ERRORED_FILE="/var/log/inotibatch/$CONFIG_NAME.errored"
LOGFILE="/var/log/inotibatch/$CONFIG_NAME.log"
PROCESS_LOG="/var/log/inotibatch/$CONFIG_NAME.process.log"
SPOOL_DIR="/var/spool/inotibatch"
BATCH_FILE="$SPOOL_DIR/$CONFIG_NAME.batch"
BATCH_LOCK="$SPOOL_DIR/$CONFIG_NAME.lock"

mkdir -p "$(dirname "$LOGFILE")" "$SPOOL_DIR"
touch "$LOGFILE" "$PROCESS_LOG" "$BATCH_FILE"
rm -f "$BATCH_LOCK" || true
touch "$BATCH_LOCK"

# --- Open FD 200 for persistent lock ---
exec 200<>"$BATCH_LOCK"

ilog() {
  local level msg timestamp
  timestamp="$(date +'%F %T')"

  case "${1:-}" in
    INFO|DEBUG|WARN|ERROR)
      level="$1";
      shift
      ;;
    *)
      level="INFO"
      ;;
  esac
  msg="$*"

  # Only log debug messages if DEBUG=true
  if [[ "$level" == "DEBUG" && "${DEBUG:-false}" != "true" ]]; then
    return 0
  fi

  if [[ -n "${LOG_PREFIX:-}" ]]; then
    echo "[$timestamp] [$level] [$LOG_PREFIX] $msg" >> "$LOGFILE"
  else
    echo "[$timestamp] [$level] $msg" >> "$LOGFILE"
  fi
}

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
    printf "%s" "[$timestamp] [$level] [$LOG_PREFIX] $msg"
  else
    printf "%s" "[$timestamp] [$level] $msg"
  fi
}
export -f log

# ---- Skip file check ----
should_skip_file() {
  local filename
  filename="$1"

  for pattern in "${EXCLUDE_PATTERNS[@]}"; do
      # shellcheck disable=SC2053
      if [[ $filename == $pattern ]]; then
          return 0  # skip
      fi
  done
  return 1
}

# ---- Execute action script ----
run_action_script() {
  local src dest
  src="$1"
  dest="$2"

  LOG_PREFIX="run_action_script" ilog "DEBUG" "Executing action script $ACTION_SCRIPT with src=$src dest=$dest"
  if [[ -x "$ACTION_SCRIPT" ]]; then
    LOG_PREFIX="ACTION" "$ACTION_SCRIPT" "$CONFIG_NAME" "$src" "$dest" >>"$PROCESS_LOG" 2>&1
  else
    LOG_PREFIX="run_action_script" ilog "ERROR" "Action script $ACTION_SCRIPT not found or not executable!"
  fi
}

# ---- Run hooks in a directory ----
run_hooks() {
  local hook_dir
  hook_dir="$1"
  shift

  if [[ -n "$hook_dir" ]]; then
    LOG_PREFIX="$hook_dir"
    for script in "$hook_dir"/*; do
      [[ -x "$script" ]] || continue
      ilog "DEBUG" "Preparing to run hook $script with args: $*"
      LOG_PREFIX="$(basename "$hook_dir")"
      ilog "INFO" "Running hook: $script"
      LOG_PREFIX="$(basename "$script")" "$script" "$CONFIG_NAME" "$@" >>"$PROCESS_LOG" 2>&1
    done
    LOG_PREFIX=
  fi
}

# ---- Queue a file for batch processing ----
queue_file_for_batch() {
  local file
  file="$1"

  # Acquire exclusive lock on lock
  if ! flock -x 200; then
    LOG_PREFIX="queue_file_for_batch" ilog "ERROR" "Failed to acquire lock in queue_file_for_batch"
    return 1
  fi

  LOG_PREFIX="queue_file_for_batch" ilog "DEBUG" "Queueing file $file for post processing batch"
  if ! echo "$file" >> "$BATCH_FILE"; then
    LOG_PREFIX="queue_file_for_batch" ilog "ERROR" "Failed to write to batch file"
    flock -u 200
    return 1
  fi

  flock -u 200
}

# ---- Flush batch ----
flush_batch() {
  local batch_file processed_file errored_file post_hook_dir tmp_batch files
  batch_file="$1"
  processed_file="$2"
  errored_file="$3"
  post_hook_dir="$4"

  # Acquire exclusive lock and copy batch to tmp file
  if ! flock -x 200; then
    LOG_PREFIX="flush_batch" ilog "ERROR" "Failed to acquire lock in flush_batch"
    return 1
  fi

  [[ -s "$batch_file" ]] || { LOG_PREFIX="flush_batch" ilog "DEBUG" "No files to flush, batch empty"; flock -u 200; return 0; }

  tmp_batch=$(mktemp "$(dirname "$batch_file")/batch-XXXX.processing")
  if ! cp "$batch_file" "$tmp_batch"; then
    LOG_PREFIX="flush_batch" ilog "ERROR" "Failed to copy batch file"
    flock -u 200
    rm -f "$tmp_batch"
    return 2
  fi

  : > "$batch_file"

  # Release lock early
  flock -u 200
  LOG_PREFIX="flush_batch" ilog "DEBUG" "Released batch lock"

  mapfile -t files < "$tmp_batch" || { LOG_PREFIX="flush_batch" ilog "ERROR" "Failed to read tmp batch"; rm -f "$tmp_batch"; return 2; }

  LOG_PREFIX="flush_batch" ilog "INFO" "Post-Hook for ${#files[@]} files"

  if run_hooks "$post_hook_dir" "${files[@]}"; then
    for f in "${files[@]}"; do printf "%s" "$(date +'%F %T') $f\n" >> "$processed_file"; done
  else
    for f in "${files[@]}"; do printf "%s" "$(date +'%F %T') $f\n" >> "$errored_file"; done
    LOG_PREFIX="flush_batch" ilog "ERROR" "Post-hook failed"
    rm -f "$tmp_batch"
    return 1
  fi

  rm -f "$tmp_batch"

  return 0
}

# ---- Watch batch ----
watch_post_process_batch() {
  local batch_file processed_file errored_file post_hook_dir batch_size idle_timeout last_flush now queued rc
  batch_file="$1"
  processed_file="$2"
  errored_file="$3"
  post_hook_dir="$4"
  batch_size="$5"
  idle_timeout="$6"
  last_flush=$(date +%s)

  LOG_PREFIX="watch_post_process_batch" ilog "DEBUG" "Starting watch_post_process_batch: batch_size=$batch_size, idle_timeout=$idle_timeout"

  while true; do
    sleep 5
    now=$(date +%s)

    if flock -s 200; then
      [[ -f "$batch_file" ]] && queued=$(grep -c '' "$batch_file" 2>/dev/null) || queued=0
      flock -u 200
    else
      LOG_PREFIX="watch_post_process_batch" ilog "ERROR" "Failed to acquire shared lock"
      continue
    fi

    LOG_PREFIX="watch_post_process_batch" ilog "DEBUG" "queued=$queued, elapsed=$((now - last_flush))s"
    [[ $queued -ge $batch_size ]] || (( now - last_flush >= idle_timeout )) || continue

    LOG_PREFIX="watch_post_process_batch" ilog "INFO" "Triggering flush: queued=$queued"
    flush_batch "$batch_file" "$processed_file" "$errored_file" "$post_hook_dir"
    rc=$?

    LOG_PREFIX="watch_post_process_batch"
    case $rc in
      0) ilog "DEBUG" "flush_batch completed";;
      1) ilog "ERROR" "Post-hook failed";;
      2) ilog "ERROR" "Error reading tmp batch";;
      *) ilog "ERROR" "Unknown flush_batch rc=$rc";;
    esac
    LOG_PREFIX=

    last_flush=$(date +%s)
  done
}

# ---- Process a file ----
process_file() {
  local event src rel_path dir_part base_name target_base dest
  event="$1"
  src="$2"

  rel_path="${src#$SOURCE_DIR/}"
  dir_part=$(dirname "$rel_path")
  base_name=$(basename "$rel_path")
  target_base="$base_name"

  if [[ "$SANITIZE_FILENAMES" == "true" ]]; then
    target_base=$(printf '%s' "$base_name" \
                        | tr '[:upper:]' '[:lower:]' \
                        | sed 's/ /_/g' \
                        | sed 's/[^a-z0-9._-]/-/g' \
                        | sed 's/--*/-/g')
  fi

  dest="$(realpath -m "$TARGET_DIR/$dir_part/$target_base")"

  LOG_PREFIX="process_file" ilog "INFO" "Processing event=$event, src=$src, dest=$dest"

  run_hooks "$PRE_HOOK_DIR" "$src" "$dest"
  run_action_script "$src" "$dest"
  if [[ -n "$POST_HOOK_DIR" ]]; then
    queue_file_for_batch "$dest"
  else
    LOG_PREFIX="process_file" ilog "DEBUG" "No POST_HOOK_DIR set. Not queuing file $dest for post processing."
    printf "%s" "$(date +'%F %T') $dest" >> "$PROCESSED_FILE"
  fi

  LOG_PREFIX="process_file" ilog "INFO" "File queued for post-hook: $dest"
}

# ---- inotifywait loop ----
inotifywait_loop() {
  local args skip

  # shellcheck disable=SC2054
  args=(-m -e close_write,create,modify --format '%w%f|%e')
  [[ "$RECURSIVE" == "true" ]] && args+=(-r)

  LOG_PREFIX="inotifywait" ilog "INFO" "Starting inotifywait with args: ${args[*]} on $SOURCE_DIR"

  inotifywait "${args[@]}" "$SOURCE_DIR" | while IFS='|' read -r file event; do
    LOG_PREFIX="inotifywait" ilog "DEBUG" "Event: $event for file $file"
    if [[ "$file" = /* ]]; then
      skip=false
      should_skip_file "$file" && skip=true
      $skip || process_file "$event" "$file" < /dev/null
    fi
  done
}

# ---- Error handler ----
trap_error() {
  local msg
  msg="$1"

  LOG_PREFIX="trap_error" ilog "ERROR" "$msg"
  if [[ -n "$EMAIL_ON_ERROR" ]]; then
    printf "%s" "$msg" | mail -s "File Sync Error in Instance $CONFIG_NAME" "$EMAIL_ON_ERROR"
  fi
}

# ---- Main ----
main() {
  local watch_params

  LOG_PREFIX="main" ilog "INFO" "Starting inotibatch, instance: $CONFIG_NAME"

  watch_params=(
    "$BATCH_FILE"
    "$PROCESSED_FILE"
    "$ERRORED_FILE"
    "$POST_HOOK_DIR"
    "$POST_HOOK_BATCH_SIZE"
    "$POST_HOOK_IDLE_TIMEOUT"
  )

  # Start batch watcher in background
  (
    while true; do
      watch_post_process_batch "${watch_params[@]}"
      LOG_PREFIX="watch_post_process_batch" ilog "ERROR" "watch_post_process_batch exited — restarting"
      sleep 1
    done
  ) &

  inotifywait_loop || trap_error "inotifywait failed for instance $CONFIG_NAME"
}

main "$CONFIG_NAME"
