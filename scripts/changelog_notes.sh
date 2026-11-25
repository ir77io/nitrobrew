#!/bin/bash
#
# Prints the CHANGELOG.md section for one version (the lines under "## X.Y.Z").
# Exits 1 if the version has no entry. Used by the release workflow.
#
set -euo pipefail
VERSION="${1:?usage: changelog_notes.sh X.Y.Z}"
cd "$(dirname "$0")/.."
NOTES=$(awk -v v="$VERSION" '
    $0 == "## " v { found = 1; next }
    found && /^## / { exit }
    found { print }
' CHANGELOG.md | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')
if [[ -z "$(echo "$NOTES" | tr -d '[:space:]')" ]]; then
    echo "CHANGELOG.md has no entry for version $VERSION." >&2
    exit 1
fi
echo "$NOTES"
