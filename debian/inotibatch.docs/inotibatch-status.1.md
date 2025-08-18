% INOTIBATCH-STATUS(1) User Commands
% cgoIT
% August 2025

# NAME

inotibatch-status — show the status of inotibatch instances

# SYNOPSIS

inotibatch-status

# DESCRIPTION

inotibatch-status lists all inotibatch instances found in the configuration directory and prints their current status, the number of processed files, the number of errored files, and the timestamp of the last processed file.

The script expects configuration files with .conf extension located in /etc/inotibatch or in a fallback configuration directory under the script path.

# CONFIGURATION

By default, the script uses:
- CONFIG_DIR: /etc/inotibatch if it exists, otherwise config directory under the script path.
- LOG_DIR: /var/log/inotibatch
-	SERVICE_PREFIX: inotibatch@

For each configuration file named NAME.conf, the script checks the status of the systemd service inotibatch@NAME.service.

# OUTPUT

The output is a table with the following columns:

| Column           | Description                                                                                 |
|-----------------|---------------------------------------------------------------------------------------------|
| Instance         | The base name of the configuration file (without .conf)                                     |
| Status           | Current systemd status of the instance (running or stopped)                                 |
| Processed Files  | Number of successfully processed files recorded in the instance’s .processed log           |
| Errored Files    | Number of files with errors recorded in the instance’s .errored log                         |
| Last Processed   | Timestamp of the last processed file from the .process.log                                   |

## Example output:

| Instance            | Status    | Processed Files | Errored Files  | Last Processed |
| --------------------|-----------|-----------------|----------------|---------------|
| example1            | running   | 120             | 2              | 2025-08-15 14:22:10 |
| example2            | stopped   | 75              | 0              | 2025-08-14 18:10:05 |

# OPERATION

For each configuration file in CONFIG_DIR:
1.	Extract the instance name by removing .conf.
2.	Construct the service name using SERVICE_PREFIX and the instance name.
3.	Check whether the service is active using systemctl is-active.
4.	Read log files in LOG_DIR to count processed and errored files.
5.	Determine the timestamp of the last processed file.
6.	Print the information in a formatted table.

# EXIT STATUS

-	0: All instances processed successfully.
-	Non-zero: if an error occurs while reading logs or systemd status.

# EXAMPLES

Show the status of all inotibatch instances:

```bash
sudo inotibatch-status
```

# SEE ALSO

inotibatch(1) — the main script of iontibatch.

inotibatch(2) — information about configuration variables

inotibatch-create-services(1) — to create and start instances.
