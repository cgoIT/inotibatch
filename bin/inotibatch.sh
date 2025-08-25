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
exec 1>/dev/null 2>&1
exec 3>&1 # for function return values

# Log file for hook & action script output
PROCESS_LOG="/var/log/inotibatch/${CONFIG_NAME}.process.log"
touch "$PROCESS_LOG"

SPOOL_DIR="/var/spool/inotibatch"
mkdir -p "$SPOOL_DIR"
BATCH_FILE="${SPOOL_DIR}/${CONFIG_NAME}.batch"
BATCH_LOCK="${SPOOL_DIR}/${CONFIG_NAME}.lock"
touch "$BATCH_FILE"
rm -f "${BATCH_LOCK}" || true
touch "$BATCH_LOCK"

ilog() {
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
    echo "[$timestamp] [$level] [$LOG_PREFIX] $msg"
  else
    echo "[$timestamp] [$level] $msg"
  fi
}
export -f log

should_skip_file() {
  local filename
  filename="$1"

  for pattern in "${EXCLUDE_PATTERNS[@]}"; do
      # shellcheck disable=SC2053
      if [[ $filename == $pattern ]]; then
          return 0  # match found -> skip
      fi
  done
  return 1  # no match
}

run_action_script() {
  local src dest
  src="$1"
  dest="$2"

  ilog "DEBUG" "Executing action script $ACTION_SCRIPT with src=$src dest=$dest"
  if [[ -x "$ACTION_SCRIPT" ]]; then
    LOG_PREFIX="ACTION" "$ACTION_SCRIPT" "$CONFIG_NAME" "$src" "$dest" >>"$PROCESS_LOG" 2>&1
  else
    ilog "ERROR" "Action script $ACTION_SCRIPT not found or not executable!" >&2
  fi
}

run_hooks() {
  local hook_dir
  hook_dir="$1"
  shift

  if [[ -n "${hook_dir}" ]]; then
    for script in "$hook_dir"/*; do
      [[ -x "$script" ]] || continue
      ilog "DEBUG" "Preparing to run hook $script with args: $*"
      LOG_PREFIX="$(basename "$hook_dir")"
      ilog "INFO" "Running hook: $script"
      LOG_PREFIX="$(basename "$script")" "$script" "$CONFIG_NAME" "$@" >>"$PROCESS_LOG" 2>&1
    done
  fi
}

queue_file_for_batch() {
  local file="$1"

  # Acquire exclusive lock for appending
  if flock -x "$BATCH_LOCK"; then
    ilog "DEBUG" "Queueing file $file for batch"
    if ! echo "$file" >> "$BATCH_FILE"; then
      ilog "ERROR" "Failed to write to batch file" >&2
      flock -u "$BATCH_LOCK"   # release lock before return
      return 1
    fi
    flock -u "$BATCH_LOCK"     # release lock after success
  else
    ilog "ERROR" "Failed to acquire exclusive lock in queue_file_for_batch" >&2
    return 1
  fi
}

flush_batch() {
  local batch_file batch_lock processed_file errored_file post_hook_dir tmp_batch tmp_batch_dir files

  batch_file="${1}"
  batch_lock="${2}"
  processed_file="${3}"
  errored_file="${4}"
  post_hook_dir="${5}"

  # Acquire exclusive lock
  if ! flock -x "$batch_lock"; then
    ilog "ERROR" "Failed to acquire exclusive lock in flush_batch"
    return 1
  fi

  if [[ ! -s "$batch_file" ]]; then
    ilog "DEBUG" "No files to flush, batch file empty"
    flock -u "$batch_lock"
    return 0
  fi

  # Use a temporary processing file with unique name
  tmp_batch_dir=$(dirname $batch_lock)
  tmp_batch="$(mktemp "$tmp_batch_dir/batch-XXXX.processing")"

  # Copy and clear batch file under lock
  if ! cp "$batch_file" "$tmp_batch"; then
    ilog "ERROR" "Failed to copy batch file"
    flock -u "$batch_lock"
    rm -f "$tmp_batch"
    return 1
  fi

  : > "$batch_file"
  ilog "DEBUG" "Emptied batch file after copying"

  # Release lock early
  flock -u "$batch_lock"
  ilog "DEBUG" "Released batch lock"

  # Read temp file and process
  if ! mapfile -t files < "$tmp_batch"; then
    ilog "ERROR" "Failed to read files from temporary batch file"
    rm -f "$tmp_batch"
    return 1
  fi

  LOG_PREFIX="$post_hook_dir"
  ilog "INFO" "Post-Hook for ${#files[@]} files"

  if run_hooks "$post_hook_dir" "${files[@]}"; then
    for f in "${files[@]}"; do
      ilog "DEBUG" "Marking file as processed: $f"
      echo "$(date +'%F %T') $f" >> "$processed_file"
    done
  else
    for f in "${files[@]}"; do
      ilog "DEBUG" "Marking file as errored: $f"
      echo "$(date +'%F %T') $f" >> "$errored_file"
    done
    ilog "ERROR" "Post-hook execution failed"
    rm -f "$tmp_batch"
    return 1
  fi

  rm -f "$tmp_batch"
  ilog "DEBUG" "Removed temporary batch file $tmp_batch"
}

watch_batch_timeout() {
  local batch_file batch_lock processed_file errored_file post_hook_dir batch_size idle_timeout last_flush now queued rc

  batch_file="$1"
  batch_lock="$2"
  processed_file="$3"
  errored_file="$4"
  post_hook_dir="$5"
  batch_size="$6"
  idle_timeout="$7"
  last_flush=$(date +%s)

  ilog "DEBUG" "Starting watch_batch_timeout with batch_size=$batch_size, idle_timeout=$idle_timeout"

  while true; do
    sleep 5
    now=$(date +%s)

    # Count how many files are in the batch
    {
      flock -s "$batch_lock" || {
        ilog "ERROR" "Failed to acquire shared lock for counting batch"
        continue
      }
      if [[ -f "$batch_file" ]]; then
        queued=$(grep -c '' "$batch_file" 2>/dev/null)
      else
        queued=0
      fi
    }

    ilog "DEBUG" "queued=$queued, elapsed=$(( now - last_flush )), batch_size=$batch_size, idle_timeout=$idle_timeout"

    if (( queued >= batch_size )) || { (( now - last_flush >= idle_timeout )) && (( queued > 0 )); }; then
      ilog "INFO" "Triggering flush: queued=$queued"
      flush_batch "$batch_file" "$batch_lock" "$processed_file" "$errored_file" "$post_hook_dir"
      rc=$?

      case $rc in
        0)
          ilog "DEBUG" "flush_batch completed successfully"
          ;;
        1)
          ilog "ERROR" "flush_batch: Post-Hook failed"
          ;;
        2)
          ilog "ERROR" "flush_batch: Error reading or processing batch file"
          ;;
        *)
          ilog "ERROR" "flush_batch: Unknown error rc=$rc"
          ;;
      esac

      last_flush=$(date +%s)
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

  if [[ "$SANITIZE_FILENAMES" == "true" ]]; then
    target_base=$(printf '%s' "$base_name" \
                        | tr '[:upper:]' '[:lower:]' \
                        | sed 's/ /_/g' \
                        | sed 's/[^a-z0-9._-]/-/g' \
                        | sed 's/--*/-/g')
  fi

  dest="$(realpath -m "$TARGET_DIR/$dir_part/$target_base")"

  ilog "INFO" "Processing event=$event, src=$src, dest=$dest"

  run_hooks "$PRE_HOOK_DIR" "$src" "$dest"
  run_action_script "$src" "$dest"
  queue_file_for_batch "$dest"

  ilog "INFO" "File queued for post-hook: src=$src dest=$dest"
}

inotifywait_loop() {
  local args skip
  # shellcheck disable=SC2054
  args=(-m -e close_write,create,modify --format '%w%f|%e')
  [[ "$RECURSIVE" == "true" ]] && args+=(-r)

  LOG_PREFIX="inotifywait"
  ilog "DEBUG" "Starting inotifywait with args: ${args[*]} on $SOURCE_DIR"

  inotifywait "${args[@]}" "$SOURCE_DIR" | while IFS=$'|' read -r file event; do
    ilog "DEBUG" "inotify event: $event for file $file"
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

  ilog "ERROR" "$msg"
  if [[ -n "$EMAIL_ON_ERROR" ]]; then
    echo "$msg" | mail -s "File Sync Error in Instance $1" "$EMAIL_ON_ERROR"
  fi
}

main() {
  local watch_params

  ilog "INFO" "Start inotibatch, instance: $1"

  watch_params=(
    "${BATCH_FILE}"
    "${BATCH_LOCK}"
    "${PROCESSED_FILE}"
    "${ERRORED_FILE}"
    "${POST_HOOK_DIR}"
    "${POST_HOOK_BATCH_SIZE}"
    "${POST_HOOK_IDLE_TIMEOUT}"
  )

  # Start background task in monitoring loop
  (
    while true; do
      # batch_file batch_lock processed_file errored_file post_hook_dir batch_size idle_timeout
      watch_batch_timeout "${watch_params[@]}"
      ilog "ERROR" "watch_batch_timeout has ended — Restart"
      sleep 1  # Wait briefly to avoid starting an endless loop too quickly.
    done
  ) &

  inotifywait_loop || trap_error "inotifywait failed for instance $1"
}

main "$1"
