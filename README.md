# InotiBatch

**InotiBatch** is a configurable file synchronization and processing tool for Linux servers.  
It watches a source directory (e.g. from SFTP uploads) and copies newly added or modified files to a target directory.  
Optionally, post-processing hooks and batching logic can be configured.

---

## Features

- Watches directories using `inotifywait`
- Configurable source and target directories
- Preserves subdirectory structure
- Sanitizes filenames for safe web/filesystem use
- Pre- and post-hooks per file or batch
- Batch-based post-processing: trigger after N files or T seconds of inactivity
- Supports multiple parallel sync jobs via config files and systemd instances
- Logging and error mail notification
- Status overview of all running sync jobs
- Log rotation and separation of service vs. process output

---

## Requirements

- Bash (>= 4.0)
- `inotify-tools` (provides `inotifywait`)
- `mail` (e.g. from `mailutils` or `bsd-mailx`)
- `flock`, `stat`, `systemd`

---

## Installation

### Via apt

You can install `inotibatch` via apt.

```bash
# Import the public signing key
curl -fsSL https://cgoit.github.io/inotibatch/public.key \
  | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/inotibatch.gpg

# Add the APT source (distribution: noble, component: main)
echo "deb [signed-by=/etc/apt/trusted.gpg.d/inotibatch.gpg] https://cgoit.github.io/inotibatch/ noble main" \
  | sudo tee /etc/apt/sources.list.d/inotibatch.list

# Optional: include source packages
echo "deb-src [signed-by=/etc/apt/trusted.gpg.d/inotibatch.gpg] https://cgoit.github.io/inotibatch/ noble main" \
  | sudo tee -a /etc/apt/sources.list.d/inotibatch.list

# Update package lists
sudo apt update

# Install the package
sudo apt install inotibatch

# After you've created the config files at /etc/inotibatch, install the systemd services
sudo inotibatch-create-services
```

### Manual installation

1. Clone or extract the repository:
   ```bash
   git clone https://github.com/cgoIT/inotibatch.git
   cd inotibatch
   ```

2. Run the install script:
   ```bash
   sudo ./install.sh
   ```
   This will:
   - Check for required tools
   - Copy the systemd unit template to `/etc/systemd/system/inotibatch@.service`
   - Offer to enable services for existing configs
   - Set up logrotate for `/var/log/inotibatch/*.log`

   After you've created the config files at /etc/inotibatch install the systemd services

   ```bash
   sudo ./tools/create-systemd-services.sh
   ```


---

## Configuration

Create a config file in `config/<name>.conf`. Example:

```bash
# Directories and ownership settings
SOURCE_DIR=/var/sftp/galerie/galerie
TARGET_DIR=/var/www/vhosts/example.com/files/galerie
TARGET_OWNER="www-data:www-data"

# Watch options
EVENTS=moved_to,close_write,create
RECURSIVE=true
EXCLUDE_PATTERNS=("*.tmp" "*.part" "~*")
SANITIZE_FILENAMES=true

# Script and hook configuration
ACTION_SCRIPT=actions/default-action.sh
PRE_HOOK_DIR=hooks/pre-copy.d
POST_HOOK_DIR=hooks/post-copy.d
POST_HOOK_BATCH_SIZE=20
POST_HOOK_IDLE_TIMEOUT=30

# Notification settings
MAIL_ON_ERROR=admin@example.com

# Enable/Disable debug logging
DEBUG=false
```

---

## Hooks and Action Script

Each **hook** or **action script** is a regular executable shell script that will receive all config variables as environment variables. Additionally, `$1` is the instance name.

At the top of your hook/action script, you can include this comment:

```bash
#!/bin/bash
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
#  DEBUG                     Enables DEBUG logging (true) or not (false or empty/not set at all)
#
# Available functions:
#
# log                        Logs a given statement to the correct logfile(s). Adds a correct
#                            timestamp to each log entry.
#
# These variables and functions are available to all action and hook scripts and can be used directly.
```

### Example action script

```bash
#!/bin/bash
log() { echo "[ACTION] $*" >&2; }
log "Copying $2 → $3"
cp -a "$2" "$3"
chown "$TARGET_OWNER" "$3"
```

---

## Usage with systemd

### Enable and start a service:
```bash
sudo systemctl enable --now inotibatch@galerie.service
```

### Stop a service:
```bash
sudo systemctl stop inotibatch@galerie.service
```

### Show logs:
```bash
journalctl -u inotibatch@galerie
```

---

## Logs

| File                                         | Purpose                            |
|----------------------------------------------|------------------------------------|
| `/var/log/inotibatch/<name>.log`             | Main service log (started, errors) |
| `/var/log/inotibatch/<name>.process.log`     | Output from hooks & action scripts |

Log rotation is configured via:  
`logrotate/inotibatch` → `/etc/logrotate.d/inotibatch`

---

## Status Overview

Use the `status.sh` helper to view the state of all configured services:

```bash
./status.sh
```

Example output:

```
Instance             Status     Processed Files     Errored Files      Last Processed            
--------------------------------------------------------------------------------------
galerie             running     42                  4                  2025-08-01 21:22:08       
upload_backup       stopped     5                   0                  2025-07-31 18:14:33       
```

---

## License

MIT License  
See [LICENSE](LICENSE)

---
