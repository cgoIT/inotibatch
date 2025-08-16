#!/bin/bash

set -euo pipefail

if [[ "$(uname)" == "Darwin" ]]; then
    if command -v gawk >/dev/null 2>&1; then
        AWK="gawk"
    else
        echo "Fehler: gawk ist auf macOS nicht installiert. Installiere mit:"
        echo "  brew install gawk"
        return 1
    fi
else
    AWK="awk"
fi

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
' CHANGELOG.md > debian/changelog
