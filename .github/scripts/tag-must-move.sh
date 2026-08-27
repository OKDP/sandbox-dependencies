#!/usr/bin/env bash
#
# The published version is a literal in each package manifest, and the publish
# job skips any tag that already exists. So a package edited without a tag bump
# is never published: git has the change, the registry does not, and nothing
# says so.
#
# This fails the pull request instead.
#
# Interim guard: once release-please owns the tag, the version comes from the
# commit type and this script must be removed.
#
# Usage: tag-must-move.sh <base-ref> <changed-file>...
set -uo pipefail

base="$1"; shift
changed=("$@")
[[ ${#changed[@]} -eq 0 ]] && exit 0

status=0

# Package directories touched by files that can affect the built artifact.
# README and docs cannot, so they never require a bump.
dirs=$(printf '%s\n' "${changed[@]}" \
       | grep -E '^packages/.*\.ya?ml$' \
       | grep -viE '/README\.md$|^packages/.*/docs/' \
       | xargs -r -n1 dirname | sort -u)

for dir in ${dirs}
do
  manifest=$(find "${dir}" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" \) -exec grep -l '^modules:' {} \;)
  [[ -z "${manifest}" ]] && continue

  new=$(grep -m1 -E '^tag:' "${manifest}" | sed 's/^tag: *//')
  old=$(git show "${base}:${manifest}" 2>/dev/null | grep -m1 -E '^tag:' | sed 's/^tag: *//')

  if [[ -z "${old}" ]]; then
    echo "ok   ${manifest} is new, nothing to compare"
  elif [[ "${old}" == "${new}" ]]; then
    echo "::error title=Tag did not move::${dir} changed but tag: is still ${new}. The publish job skips tags that already exist, so this change would never reach the registry. Bump the tag, or add [no-publish] to the pull request body if the change cannot affect the built package."
    status=1
  else
    echo "ok   ${dir}: ${old} -> ${new}"
  fi
done

exit ${status}
