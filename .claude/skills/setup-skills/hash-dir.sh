#!/usr/bin/env bash
# Deterministic recursive hash of a directory's file contents.
#
# Hashes relative paths, not absolute ones, so two directories with
# identical contents hash identically regardless of where they live on
# disk (needed to compare a project's copied skill against the library
# source it was copied from).
#
# Usage: hash-dir.sh <directory>
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: hash-dir.sh <directory>" >&2
  exit 1
fi

dir="$1"
if [ ! -d "$dir" ]; then
  echo "Not a directory: $dir" >&2
  exit 1
fi

(cd "$dir" && find . -type f -print0 | sort -z | xargs -0 -r sha256sum) | sha256sum | awk '{print $1}'
