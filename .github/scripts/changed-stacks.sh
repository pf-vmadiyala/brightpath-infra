#!/usr/bin/env bash
# Prints a JSON array of Terraform root modules (folders containing backend.tf)
# affected by the changes between two commits.
#   usage: changed-stacks.sh <base-sha> <head-sha>
#
# - A file under live/ maps to the nearest parent folder with a backend.tf.
# - A change under modules/<name>/ includes only the stacks whose .tf files
#   call that module (source = ".../modules/<name>"). Modules here don't call
#   other modules; if one ever does, include its callers' callers too.
set -euo pipefail

base="$1"
head="$2"
changed="$(git diff --name-only "$base" "$head")"
stacks=()

while IFS= read -r module; do
  while IFS= read -r f; do
    stacks+=("$(dirname "$f")")
  done < <(grep -rlE --include='*.tf' --exclude-dir=.terraform \
    "source[[:space:]]*=[[:space:]]*\"[./]*modules/${module}\"" live || true)
done < <(grep '^modules/' <<<"$changed" | cut -d/ -f2 | sort -u || true)

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