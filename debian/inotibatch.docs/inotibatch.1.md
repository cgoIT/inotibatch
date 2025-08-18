% INOTIBATCH(1) inotibatch 1.2.4
% cgoIT <info@cgo-it.de>
% August 2025

# NAME

inotibatch - watch directories and trigger actions on file events

# SYNOPSIS

**inotibatch**

# DESCRIPTION

**inotibatch** monitors specified directories and executes configured actions
whenever files change. It can handle multiple directories and supports
custom hooks, logging, and systemd integration.

# EXIT STATUS

0 if successful, non-zero on error.

# SEE ALSO

inotibatch(2) — information about configuration variables

inotibatch-status(1) — script to check the status of the configured jobs.

inotibatch-create-services(1) — to create and start instances.

# AUTHOR

cgoIT <info@cgo-it.de>
