#!/bin/bash
#
# Formats Swift sources with the SwiftFormat version pinned in the Mintfile.
#
#   ./swiftformat.sh                 format SpeedTest, SpeedTestPackage and SpeedTestUITests
#   ./swiftformat.sh --lint          report what would change and fail instead of rewriting (CI)
#   ./swiftformat.sh [--lint] paths  only the given paths
#

set -eo pipefail
cd "$(dirname "$0")"

mode=()
if [[ "$1" == "--lint" ]]; then
    mode=(--lint)
    shift
fi

targets=("$@")
if [[ ${#targets[@]} -eq 0 ]]; then
    for path in SpeedTest SpeedTestPackage SpeedTestUITests; do
        if [[ -e "$path" ]]; then
            targets+=("$path")
        fi
    done
fi

mint run swiftformat "${targets[@]}" "${mode[@]}" \
    --exclude "**/.build,**/.swiftpm,**/DerivedData" \
    --swiftversion 6.3 \
    --languagemode 6 \
    --disable redundantSelf \
    --trailing-commas never \
    --maxwidth 120 \
    --disable andOperator \
    --disable redundantSwiftTestingSuite,swiftTestingTestCaseNames,blankLinesBetweenImports \
    --enable sortSwitchCases,blankLineAfterSwitchCase
