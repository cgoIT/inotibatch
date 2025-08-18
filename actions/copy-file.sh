#!/bin/bash
# usage: copy-file.sh <instance-name> <src> <dest>
#
# Available environment variables (from config):
#
#  CONFIG_NAME               Name of the configuration file without extension (e.g. "galerie")
#  CONFIG_PATH               Absolute path to the loaded config file
#
#  SOURCE_DIR                Directory being watched for incoming files
#  TARGET_DIR                Destination directory where files should be copied to
#  TARGET_OWNER              Owner:group that should be applied to target files (optional)
#
#  EVENTS                    Comma-separated inotify events to watch for (e.g. "moved_to,create")
#  RECURSIVE                 Whether to watch SOURCE_DIR recursively ("true"/"false")
#  EXCLUDE_PATTERNS          Array of filename patterns to ignore (e.g. ("*.tmp" "*.part"))
#  SANITIZE_FILENAMES        Whether to sanitize filenames (e.g. remove special characters)
#
#  ACTION_SCRIPT             Path to the main action script that processes each file
#  PRE_HOOK_DIR              Directory containing scripts to run before the action
#  POST_HOOK_DIR             Directory containing scripts to run after the action
#
#  POST_HOOK_BATCH_SIZE      Max number of files to batch before triggering post-hooks
#  POST_HOOK_IDLE_TIMEOUT    Max idle time in seconds before triggering post-hooks
#
#  MAIL_ON_ERROR             Email address to notify in case of processing errors
#
# Available functions:
#
# log                        Logs a given statement to the correct logfile(s). Adds a correct
#                            timestamp to each log entry.
#
# These variables and functions are available to all action and hook scripts and can be used directly.

conf="$1"
src="$2"
dest="$3"

mkdir -p "$(dirname "$dest")"
cp -u "$src" "$dest"
chown www-data:www-data "$dest"
