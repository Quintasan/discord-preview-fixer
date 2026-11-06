#!/usr/bin/env bash
# Upstream lookups for the release-update skill that actions-up and bundler do not cover.
set -euo pipefail

usage() {
  cat >&2 <<'TXT'
usage: upstream.sh ruby-patch <minor>

  ruby-patch <minor>  newest stable patch for a Ruby minor (e.g. 4.0)
TXT
  exit 64
}

case "${1:-}" in
  ruby-patch)
    [ $# -eq 2 ] || usage
    minor="${2//./\\.}"
    mise ls-remote ruby | grep -E "^${minor}\.[0-9]+$" | sort -V | tail -1
    ;;
  *)
    usage
    ;;
esac
