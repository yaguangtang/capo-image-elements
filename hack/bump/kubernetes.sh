# Copyright (c) 2025 VEXXHOST, Inc.
# SPDX-License-Identifier: Apache-2.0

set -e

# Fetch the latest stable patch release for every supported minor version.
MINOR_VERSIONS=(1.28 1.29 1.30)
VERSIONS=()
for minor in "${MINOR_VERSIONS[@]}"; do
    version=$(curl -fsSL "https://dl.k8s.io/release/stable-${minor}.txt")
    case "$version" in
        v${minor}.*) VERSIONS+=("${version#v}") ;;
        *)
            echo "Expected a stable ${minor}.x release, received: ${version}" >&2
            exit 1
            ;;
    esac
done

# Update the CI workflow only after awk has rendered it successfully.
WORKFLOW=.github/workflows/ci.yaml
VERSION_FILE=$(mktemp)
WORKFLOW_TMP=$(mktemp "${WORKFLOW}.XXXXXX")
trap 'rm -f "$VERSION_FILE" "$WORKFLOW_TMP"' EXIT

for version in "${VERSIONS[@]}"; do
    printf '          - %s\n' "$version" >> "$VERSION_FILE"
done

awk '
FNR == NR {
    versions = versions $0 ORS
    next
}
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
' "$VERSION_FILE" "$WORKFLOW" > "$WORKFLOW_TMP"
chmod 0644 "$WORKFLOW_TMP"
mv "$WORKFLOW_TMP" "$WORKFLOW"

echo "Updated Kubernetes versions in CI workflow to:"
printf '%s\n' "${VERSIONS[@]}"
