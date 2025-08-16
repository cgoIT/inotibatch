#!/bin/bash

set -euo pipefail

# Package metadata
ARCH="all"
PKG="inotibatch"
DIST="noble"
URGENCY="medium"
MAINTAINER="cgoIT <info@cgo-it.de>"

get_version() {
    if [[ $# -ge 1 && -n "$1" ]]; then
        echo "$1"
    elif [[ -n "${GITHUB_REF_NAME:-}" ]]; then
        echo "${GITHUB_REF_NAME#v}"
    else
        echo "0.0.0-dev"
    fi
}

prepare_build_dirs() {
    local PKG_DIR="$1"
    local BUILD_DIR="$2"
    rm -rf "$BUILD_DIR"
#    mkdir -p "${PKG_DIR}" \
#             "${PKG_DIR}/DEBIAN" \
#             "${PKG_DIR}/usr/local/bin" \
#             "${PKG_DIR}/opt/$PKG/bin" \
#             "${PKG_DIR}/etc/$PKG" \
#             "${PKG_DIR}/var/log/$PKG" \
#             "${PKG_DIR}/usr/share/doc/$PKG"
    mkdir -p "${BUILD_DIR}/${PKG_DIR}/debian"
}

write_control_file() {
    local PKG_DIR="$1"
    local VERSION="$2"

    cat > "${PKG_DIR}/debian/control" <<EOF
Source: ${PKG}
Section: utils
Priority: optional
Maintainer: Carsten Goetzinger <carsten@cgo-it.de>
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
}

generate_debian_changelog() {
  local changelog_out="${1:-changelog}"
  local changelog_md="${2:-CHANGELOG.md}"

  if [[ "$(uname)" == "Darwin" ]]; then
      if command -v gawk >/dev/null 2>&1; then
          AWK="gawk"
      else
          echo "Fehler: gawk ist auf macOS nicht installiert. Installiere mit:"
          echo "  brew install gawk"
          return 1
      fi
      if command -v gdate >/dev/null 2>&1; then
          DATE="gdate"
      else
          echo "Fehler: gdate ist auf macOS nicht installiert. Installiere mit:"
          echo "  brew install gdate"
          return 1
      fi
  else
      AWK="awk"
      DATE="date"
  fi
  export DATE

  $AWK -v pkg="$PKG" -v dist="$DIST" -v urg="$URGENCY" -v maint="$MAINTAINER" '
  function flush_entry() {
      if (entry_started) {
          print ""
          print " -- " maint "  " entry_date
      }
  }

  BEGIN {
      entry_started = 0
      first_entry = 1
      first_feature = 1
  }

  /^## \[/ {
      flush_entry()
      first_feature = 1
      match($0, /\[?([0-9]+\.[0-9]+\.[0-9]+)\]?.*\(([0-9]{4}-[0-9]{2}-[0-9]{2})\)/, m)
      ver = m[1]
      date_iso = m[2]
      if (first_entry) {
          # First changelog entry → Date and time 12:00:00
          cmd = "date -d \"" date_iso " 12:00:00\" \"+%a, %d %b %Y %H:%M:%S %z\""
          first_entry = 0
      } else {
          cmd = "date -d \"" date_iso "\" \"+%a, %d %b %Y %H:%M:%S %z\""
          print ""
      }
      cmd | getline entry_date
      close(cmd)
      print pkg " (" ver ") " dist "; urgency=" urg
      print ""
      entry_started = 1
      next
  }

  /^### / {
      if (first_feature) {
          first_feature = 0
      } else {
          print ""
      }
      sub(/^###[ ]*/, "", $0)
      print "  [ " $0 " ]"
      next
  }

  /^\* / {
      sub(/^\* /, "", $0)
      match($0, /^(\*\*.*:\*\* )?(.*)\((.*)\(/, m)
      change=m[2]
      rev=m[3]
      print "  * " change " " rev
      next
  }

  /^$/ {
      next
  }

  END {
      flush_entry()
  }
  ' "$changelog_md" > "$changelog_out"

  #gzip -9 -f "$changelog_out"
  #mv "${changelog_out}.gz" "${changelog_out}.Debian.gz"
}

  copy_files() {
    local PKG_DIR="$1"
    #cp deb/debian/* "${PKG_DIR}/DEBIAN/"
    #cp -r status.sh bin actions hooks tools systemd logrotate "${PKG_DIR}/opt/$PKG/"
    #cp -r config/* "${PKG_DIR}/etc/$PKG/"
    #cp deb/copyright README.md "${PKG_DIR}/usr/share/doc/$PKG"
    #ln -s "/opt/$PKG/bin/inotibatch.sh" "${PKG_DIR}/usr/local/bin/inotibatch"
    #ln -s "/opt/$PKG/status.sh" "${PKG_DIR}/usr/local/bin/inotibatch-status"
    #ln -s "/opt/$PKG/tools/create-systemd-services.sh" "${PKG_DIR}/usr/local/bin/inotibatch-create-services"

    # copy sources
    mkdir -p "${PKG_DIR}/src"
    EXCLUDE_FILE=""
    if [[ -f ".gitignore" ]]; then
      # rsync cannot ignore comments directly, so we filter them out
      EXCLUDE_FILE=$(mktemp)
      grep -v -E '^\s*#|^\s*$' ".gitignore" > "$EXCLUDE_FILE"
    fi
    rsync -a --exclude-from="$EXCLUDE_FILE" ./ "${PKG_DIR}/src/"
    [[ -f "$EXCLUDE_FILE" ]] && rm "$EXCLUDE_FILE"

    mv "${PKG_DIR}/src/debian" "${PKG_DIR}"
}

build_package() {
    local PKG_DIR="$1"
    local BUILD_DIR="$2"
    local VERSION="$3"
    dpkg-deb --build "${PKG_DIR}" "$BUILD_DIR/${PKG}_${VERSION}_${ARCH}.deb"
    echo "📦 Built: ${PKG}_${VERSION}_${ARCH}.deb"
}

main() {
    local VERSION
    VERSION="$(get_version "$@")"
    local BUILD_DIR="${2:-build}"
    local PKG_DIR
    PKG_DIR="${PKG}-${VERSION}"

    echo "📦 Building inotibatch v${VERSION}"
    echo "📂 Build directory: ${BUILD_DIR}"

    prepare_build_dirs "$PKG_DIR" "$BUILD_DIR"
    copy_files "$BUILD_DIR/$PKG_DIR"
    write_control_file "$BUILD_DIR/$PKG_DIR" "$VERSION"
    generate_debian_changelog "$BUILD_DIR/$PKG_DIR/debian/changelog"
#    build_package "$PKG_DIR" "$BUILD_DIR" "$VERSION"
}

main "$@"