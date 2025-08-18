# INOTIBATCH CONFIGURATION

This document provides a comprehensive guide to configuring **InotiBatch**, a configurable file synchronization and processing tool for Linux servers.

## CONFIGURATION VARIABLES

Below are the configuration variables available for **InotiBatch**. These variables should be set in a configuration file saved in the `config/` directory, using the naming convention `<name>.conf`.

### Directories and Ownership Settings
- **`SOURCE_DIR`**:  
  Specifies the directory to be monitored for new or modified files.  
  Example: `/var/sftp/galerie/galerie`

- **`TARGET_DIR`**:  
  Specifies the target directory where monitored files should be copied.  
  Example: `/var/www/vhosts/example.com/files/galerie`

- **`TARGET_OWNER`**:  
  Defines the ownership (user:group) to be applied to files in the target directory.  
  Example: `www-data:www-data`  
  *(Optional)*

### Watch Options
- **`EVENTS`**:  
  A comma-separated list of inotify events to monitor.  
  Example: `moved_to,close_write,create`

- **`RECURSIVE`**:  
  Indicates whether to watch subdirectories of the source directory.  
  Allowed values: `true` or `false`

- **`EXCLUDE_PATTERNS`**:  
  Specifies an array of filename patterns to exclude from monitoring.  
  Example: `("*.tmp" "*.part" "~*")`

- **`SANITIZE_FILENAMES`**:  
  Enables or disables filename sanitization to remove special characters.  
  Allowed values: `true` or `false`

### Action Script and Hooks
- **`ACTION_SCRIPT`**:  
  Path to the main action script used to process each file.  
  Example: `actions/default-action.sh`

- **`PRE_HOOK_DIR`**:  
  Directory containing scripts to be executed before processing each file.  
  Example: `hooks/pre-copy.d`

- **`POST_HOOK_DIR`**:  
  Directory containing scripts to be executed after processing each file.  
  Example: `hooks/post-copy.d`

- **`POST_HOOK_BATCH_SIZE`**:  
  Defines the maximum number of files to batch before triggering the post-hooks.  
  Example: `20`

- **`POST_HOOK_IDLE_TIMEOUT`**:  
  Specifies the maximum idle time (in seconds) before triggering post-hooks.  
  Example: `30`

### Notification Settings
- **`MAIL_ON_ERROR`**:  
  Email address to send failure notifications in case of errors.  
  Example: `admin@example.com`  
  *(Optional)*


## EXAMPLE CONFIGURATION FILE

Below is an example configuration file for **InotiBatch**:
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

# Action script and hooks
ACTION_SCRIPT=actions/default-action.sh
PRE_HOOK_DIR=hooks/pre-copy.d
POST_HOOK_DIR=hooks/post-copy.d
POST_HOOK_BATCH_SIZE=20
POST_HOOK_IDLE_TIMEOUT=30

# Notification settings
MAIL_ON_ERROR=admin@example.com
```


## NOTES
1. All configuration variables are case-sensitive.
2. The configuration filename (without the `.conf` extension) will determine the corresponding systemd service name. For example, a file named `galerie.conf` will correspond to the service `inotibatch@galerie.service`.
3. Hooks and scripts should be executable and are called with environment variables listed above.


## SEE ALSO

Refer to the following resources for further information:
- `inotibatch(1)` — Main usage guide.
- `inotibatch-status(1)` — Status overview of all configured services.
- `inotibatch-create-services(1)` — Tool for generating systemd services from configuration files.
