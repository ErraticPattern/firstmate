#!/usr/bin/env bash
# Resolve and validate explicit local-only landing targets.
#
# Configuration: config/local-landing-targets is an optional regular file with
# one `project<TAB>branch` mapping per non-comment line. Project names are clone
# basenames. A project may appear once. The file is local, gitignored, and a
# missing file preserves the default-branch behavior. docs/configuration.md
# "Local landing targets" owns the operator-facing contract; bin/fm-spawn.sh and
# bin/fm-promote.sh resolve and record, bin/fm-merge-local.sh and
# bin/fm-teardown.sh read the record back.
#
# fm_landing_target_resolve <config-dir> <project-dir> <explicit-target>
# Prints the resolved target or nothing. An explicit target and configured
# target must agree. Invalid, unreadable, unsafe, or duplicate configuration
# refuses rather than guessing. Callers record a non-empty result in task meta.
#
# fm_landing_target_from_meta <meta-file>
# Prints the recorded landing_target= value, or nothing when the task records
# none. Refuses a record carrying the key more than once, an empty value, or an
# invalid branch name rather than choosing one reading of it.
#
# fm_landing_target_require_branch <project-dir> <target>
# Refuses unless target is a valid branch name and an existing local branch in
# project-dir. Callers address the target as refs/heads/<target> so a tag or
# remote-tracking ref of the same name can never stand in for it.
#
# fm_landing_target_reject_default <project-dir> <target>
# Refuses when target names the project's default branch (origin/HEAD, else a
# local main or master), or when that default cannot be determined.

# A pure syntax check: never `check-ref-format --branch`, which expands @{-N}
# against whatever repository the caller happens to be standing in.
fm_landing_target_valid() {
  case ${1:-} in '' | -* | @) return 1 ;; esac
  git check-ref-format "refs/heads/$1" >/dev/null 2>&1
}

fm_landing_target_resolve() {
  local config=$1 project=$2 explicit=${3:-} file name mapped_name mapped_target remainder found=
  file="$config/local-landing-targets"
  name=$(basename "$project") || return 1

  if [ -n "$explicit" ] && ! fm_landing_target_valid "$explicit"; then
    echo "error: invalid landing target '$explicit'" >&2
    return 1
  fi
  [ -e "$file" ] || [ -L "$file" ] || {
    printf '%s\n' "$explicit"
    return 0
  }
  if [ ! -f "$file" ] || [ -L "$file" ] || [ ! -r "$file" ]; then
    echo "error: cannot read local landing-target configuration at $file" >&2
    return 1
  fi
  while IFS=$'\t' read -r mapped_name mapped_target remainder || [ -n "$mapped_name$mapped_target$remainder" ]; do
    case "$mapped_name" in ''|'#'*) continue ;; esac
    if [ -z "$mapped_target" ] || [ -n "$remainder" ] || ! fm_landing_target_valid "$mapped_target"; then
      echo "error: invalid local landing-target configuration at $file" >&2
      return 1
    fi
    [ "$mapped_name" = "$name" ] || continue
    if [ -n "$found" ]; then
      echo "error: contradictory local landing-target configuration for $name at $file" >&2
      return 1
    fi
    found=$mapped_target
  done < "$file"
  if [ -n "$explicit" ] && [ -n "$found" ] && [ "$explicit" != "$found" ]; then
    echo "error: explicit landing target '$explicit' contradicts configured target '$found' for $name" >&2
    return 1
  fi
  printf '%s\n' "${explicit:-$found}"
}

fm_landing_target_from_meta() {
  local meta=$1 line value='' count=0
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in
    landing_target=*)
      count=$((count + 1))
      value=${line#landing_target=}
      ;;
    esac
  done < "$meta" || {
    echo "error: cannot read landing target from $meta" >&2
    return 1
  }
  [ "$count" -ne 0 ] || return 0
  if [ "$count" -ne 1 ] || ! fm_landing_target_valid "$value"; then
    echo "error: $meta records an ambiguous or invalid landing target" >&2
    return 1
  fi
  printf '%s\n' "$value"
}

fm_landing_target_require_branch() {
  local project=$1 target=$2
  fm_landing_target_valid "$target" || {
    echo "error: recorded landing target '$target' is not a valid branch name" >&2
    return 1
  }
  git -C "$project" rev-parse --verify --quiet "refs/heads/$target" >/dev/null || {
    echo "error: recorded landing target '$target' does not exist in $project" >&2
    return 1
  }
}

fm_landing_target_reject_default() {
  local project=$1 target=$2 ref branch default=
  ref=$(git -C "$project" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  if [ -n "$ref" ]; then
    default=${ref#origin/}
  else
    for branch in main master; do
      if git -C "$project" show-ref --verify --quiet "refs/heads/$branch"; then
        default=$branch
        break
      fi
    done
  fi
  [ -n "$default" ] || {
    echo "error: cannot determine default branch for $project; expected origin/HEAD, main, or master" >&2
    return 1
  }
  [ "$target" != "$default" ] || {
    echo "error: recorded landing target '$target' is the default branch; omit it to use default behavior" >&2
    return 1
  }
}
