#!/bin/bash

set -euo pipefail

cat > "debian/control" <<EOF
Source: ${PKG}
Section: utils
Priority: optional
Maintainer: ${MAINTAINER}
Homepage: https://github.com/cgoIT/inotibatch
Build-Depends: debhelper (>= 13)
Standards-Version: 4.5.0

Package: ${PKG}
Architecture: all
Depends: \${shlibs:Depends}, \${misc:Depends}, inotify-tools, mailutils
Description: Configurable file-based sync and hook system using inotify
 A flexible bash-based file synchronization tool using inotifywait,
 with systemd integration, batch processing, logging, and hook support.
EOF
