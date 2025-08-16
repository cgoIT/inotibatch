% INOTIBATCH-CREATE-SERVICES(1) User Commands
% cgoIT
% August 2025

# NAME

inotibatch-create-services — Create and optionally start systemd services for inotibatch configurations

# SYNOPSIS

**inotibatch-create-services**

# DESCRIPTION

**inotibatch-create-services** searches for configuration files in the system-wide directory `/etc/inotibatch` or a fallback configuration directory under the installation path, and creates corresponding systemd service units for each configuration.

For each configuration file named `NAME.conf`, a systemd service unit `inotibatch@NAME.service` will be created, based on a service template located in `/etc/systemd/system/inotibatch@.service`.

If the service already exists, it will be skipped.

The user is prompted for each new service whether it should be started immediately. If the user declines, the service is enabled but not started.

# CONFIGURATION

By default, the script uses:

- **CONFIG_DIR**: `/etc/inotibatch` if it exists, otherwise `config` directory under the script installation path.
- **SYSTEMD_DIR**: `/etc/systemd/system`
- **SERVICE_NAME_PREFIX**: `inotibatch@`
- **SERVICE_TEMPLATE_FILE**: `${SYSTEMD_DIR}/inotibatch@.service`

# OPERATION

For each configuration file in the configuration directory:

1. Extract the base name of the config file (without `.conf`).
2. Construct the service name by appending the base name to the service prefix.
3. Check if the service already exists via `systemctl status`.
4. If the service does not exist:
  - Ask interactively whether to start the service immediately.
  - Enable the service via `systemctl enable`.
  - Optionally start the service if the user confirms.

# INTERACTIVE PROMPTS

The script prompts for each new service:

```bash
👉 Start and enable inotibatch@NAME.service? [y/N]
```
- `y` or `Y`: start and enable the service.
- Any other key (default): enable without starting.

# EXIT STATUS

- `0`: All services processed successfully.
- `1`: Service template not found or an error occurred while enabling/starting services.

# EXAMPLES

Create and optionally start services for all configuration files:

```bash
sudo inotibatch-create-services
```

# SEE ALSO

systemctl(1) — to manage systemd services manually.

inotibatch(1) — the main inotibatch script.

inotibatch-status(1) — script to check the status of the configured jobs.


# NOTES

-	The script requires root privileges to enable or start systemd services.
-	Service template inotibatch@.service must exist in /etc/systemd/system.
