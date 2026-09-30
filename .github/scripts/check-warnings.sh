#!/bin/bash
#
# Fails when a build or test log contains a compiler warning in this repository's own sources.
# Warnings from dependencies are ignored: they live outside these folders.
#
# Usage: .github/scripts/check-warnings.sh <log file>
#

set -eo pipefail

log="$1"
root="${GITHUB_WORKSPACE:-$(git rev-parse --show-toplevel)}"
pattern="^${root}/(SpeedTest|SpeedTestUITests|SpeedTestPackage/Sources|SpeedTestPackage/Tests)/[^:]+:[0-9]+:[0-9]+: warning: "

if grep -E "$pattern" "$log" | sort -u; then
    echo "error: compiler warnings in this repository's sources (listed above)"
    exit 1
fi

echo "No warnings in this repository's sources."
