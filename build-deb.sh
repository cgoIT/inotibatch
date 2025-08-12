#!/bin/bash

set -euo pipefail

# Package metadata
if [[ $# -ge 1 && -n "$1" ]]; then
    VERSION="$1"
else
    # Tag von GitHub Actions (z.B. "v1.2.3") oder Fallback
    if [[ -n "${GITHUB_REF_NAME:-}" ]]; then
        VERSION="${GITHUB_REF_NAME#v}"
    else
        VERSION="0.0.0-dev"
    fi
fi

ARCH="all"
PKG="inotibatch"
BUILD_DIR="${2:-build}"
PKG_DIR="$(pwd)/${BUILD_DIR}/${PKG}_${VERSION}_${ARCH}"

echo "📦 Building inotibatch v${VERSION}"
echo "📂 Build directory: ${BUILD_DIR}"

# Cleanup and prepare build directories
rm -rf "$BUILD_DIR"
mkdir -p "${PKG_DIR}" \
         "${PKG_DIR}/DEBIAN" \
         "${PKG_DIR}/usr/local/bin" \
         "${PKG_DIR}/opt/$PKG/bin" \
         "${PKG_DIR}/etc/$PKG" \
         "${PKG_DIR}/var/log/$PKG"

# Copy debian control files
cp -r deb/debian/* "${PKG_DIR}/DEBIAN/"

# Control file
cat > "${PKG_DIR}/DEBIAN/control" <<EOF
Source: inotibatch
Section: utils
Priority: optional
Maintainer: Carsten Goetzinger <carsten@cgo-it.de>
Homepage: https://github.com/cgoIT/inotibatch
Package: inotibatch
Version: ${VERSION}
Architecture: all
Depends: bash, inotify-tools, mailutils
Description: Configurable file-based sync and hook system using inotify
 A flexible bash-based file synchronization tool using inotifywait,
 with systemd integration, batch processing, logging, and hook support.
EOF

# Changelog file
VERSION_HEADER_REGEX="^##[ ]*\[?v?${VERSION//./\\.}"

# Extract relevant changelog section
SECTION=$(awk "
  BEGIN { capture=0 }
  /^##[ ]*\[?v?[0-9]+\.[0-9]+\.[0-9]+/ {
    if (match(\$0, /${VERSION_HEADER_REGEX}/)) {
      capture=1; next
    } else if (capture == 1) {
      exit
    }
  }
  capture==1 { print }
" CHANGELOG.md)

if [ -z "$SECTION" ]; then
  echo "WARN: Kein Changelog Abschnitt für Version $VERSION gefunden. Gesamtes CHANGELOG verwenden."
  SECTION="$(cat CHANGELOG.md)"
fi

# Extract bullet points from the section
# Remove headings (e.g., ### Features), leave only lines beginning with "* ", convert to "  * "
CHANGELOG_ENTRIES=$(echo "$SECTION" | sed -n '/^### /d; /^[[:space:]]*\*/!d; s/\*\*//g; s/^[[:space:]]*\*[[:space:]]*/  * /p')

if [ -z "$CHANGELOG_ENTRIES" ]; then
  CHANGELOG_ENTRIES="  * No changes documented"
fi

# Generate debian/changelog output
{
  echo "inotibatch (${VERSION}) stable; urgency=medium"
  echo
  echo "$CHANGELOG_ENTRIES"
  echo
  echo " -- cgoIT <info@cgo-it.de>  $(date -R)"
} > "${PKG_DIR}/DEBIAN/changelog"

echo "Debian changelog for version $VERSION generated in ${PKG_DIR}/DEBIAN/changelog"

# Copy main script and subfolders
cp -r status.sh bin actions hooks tools systemd logrotate "${PKG_DIR}/opt/$PKG/"
cp -r config/* "${PKG_DIR}/etc/$PKG/"
ln -s "/opt/$PKG/bin/inotibatch.sh" "${PKG_DIR}/usr/local/bin/inotibatch"
ln -s "/opt/$PKG/status.sh" "${PKG_DIR}/usr/local/bin/inotibatch-status"
ln -s "/opt/$PKG/tools/create-systemd-services.sh" "${PKG_DIR}/usr/local/bin/inotibatch-create-services"

# Build the package
dpkg-deb --build "${PKG_DIR}" "$BUILD_DIR/${PKG}_${VERSION}_${ARCH}.deb"
echo "📦 Built: ${PKG}_${VERSION}_${ARCH}.deb"
