#!/bin/bash
#
# Lints the app, the package and the UI tests with the SwiftLint version pinned in the Mintfile.
# Strict: any warning fails. Run from anywhere; it works from the repo root.
#

set -eo pipefail
cd "$(dirname "$0")"

mint run swiftlint lint --strict --config .swiftlint.yml
