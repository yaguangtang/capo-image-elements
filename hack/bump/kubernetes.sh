# Copyright (c) 2025 VEXXHOST, Inc.
# SPDX-License-Identifier: Apache-2.0

set -e

# Keep CI pinned to a single Kubernetes version.
VERSIONS=${VERSIONS:-"1.28.15"}

# Build the version list for YAML
VERSION_LINES=""
for version in $VERSIONS; do
    VERSION_LINES="${VERSION_LINES}          - ${version}\n"
done

# Update CI workflow in place using awk
awk -i inplace -v versions="$VERSION_LINES" '
/^        version:$/ {
    print
    printf "%s", versions
    in_version = 1
    next
}
in_version && /^          -/ {
    # Skip old version lines
    next
}
in_version && !/^          -/ {
    in_version = 0
}
!in_version {
    print
}
' .github/workflows/ci.yaml

echo "Updated Kubernetes versions in CI workflow to:"
echo "$VERSIONS"
