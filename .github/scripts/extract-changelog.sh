#!/bin/bash
# Extracts release notes from CHANGELOG.md for a given version

set -e

if [ "$1" = "--skip-header" ]; then
  SKIP_HEADER=1
  shift
else
  SKIP_HEADER=0
fi

[ $# -lt 2 ] && echo "Usage: $0 [--skip-header] <changelog-path> <version>" && exit 1

CHANGELOG="$1"
VERSION="$2"

[ ! -f "$CHANGELOG" ] && echo "Error: CHANGELOG not found at $CHANGELOG" && exit 1

awk -v version="$VERSION" -v skip="$SKIP_HEADER" '
  /^## / {
    if (in_section) exit
    if ($2 == version) {
      in_section = 1
      if (skip) next
    }
  }
  in_section { print }
' "$CHANGELOG" | sed '/^$/d; s/^[ \t]*//'
