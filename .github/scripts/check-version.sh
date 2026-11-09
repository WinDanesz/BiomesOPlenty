#!/bin/sh
# Fails unless every non-merge commit after the given base raises the version in build.properties.
set -eu

base="${1:-}"

version_at() {
    git show "$1:build.properties" | tr -d '\r' | awk -F= '
        $1 == "mod_version" { mod = $2 }
        $1 == "build_number" { build = $2 }
        END { print mod (build == "" ? "" : "." build) }'
}

# Manual runs and new branches have no base, and a force-push leaves one that no longer exists.
if [ -z "$base" ] || ! git cat-file -e "$base^{commit}" 2>/dev/null; then
    echo "No base commit to compare against, skipping the version check"
    exit 0
fi

previous="$(version_at "$base")"
for commit in $(git rev-list --reverse --topo-order --no-merges "$base..HEAD"); do
    current="$(version_at "$commit")"
    highest="$(printf '%s\n%s\n' "$previous" "$current" | sort -V | tail -n 1)"
    if [ "$current" = "$previous" ] || [ "$highest" != "$current" ]; then
        echo "::error::Commit $commit must raise build_number in build.properties (previous version $previous, this commit $current)"
        exit 1
    fi
    previous="$current"
done

echo "Version check passed: $previous"
