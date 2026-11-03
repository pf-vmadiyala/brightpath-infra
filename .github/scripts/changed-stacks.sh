#!/usr/bin/env bash
# Prints a JSON array of Terraform root modules (folders containing backend.tf)
# affected by the changes between two commits.
#   usage: changed-stacks.sh <base-sha> <head-sha>
#
# - A file under live/ maps to the nearest parent folder with a backend.tf.
# - A change under modules/ can affect any stack, so every stack is included.
set -euo pipefail

base="$1"
head="$2"
changed="$(git diff --name-only "$base" "$head")"
stacks=()

if grep -q '^modules/' <<<"$changed"; then
  while IFS= read -r f; do
    stacks+=("$(dirname "$f")")
  done < <(find live -name backend.tf -not -path '*/.terraform/*')
fi

while IFS= read -r f; do
  d="$(dirname "$f")"
  while [[ "$d" == live/* && ! -f "$d/backend.tf" ]]; do
    d="$(dirname "$d")"
  done
  if [[ -f "$d/backend.tf" ]]; then
    stacks+=("$d")
  fi
done < <(grep '^live/' <<<"$changed" || true)

printf '%s\n' "${stacks[@]}" | sed '/^$/d' | sort -u | jq -R . | jq -sc .