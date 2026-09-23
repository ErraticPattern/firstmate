#!/usr/bin/env bash
# Resolve and validate explicit local-only landing targets.
#
# Configuration: config/local-landing-targets is an optional regular file with
# one `project<TAB>branch` mapping per non-comment line. Project names are clone
# basenames. A project may appear once. The file is local, gitignored, and a
# missing file preserves the default-branch behavior.
#
# fm_landing_target_resolve <config-dir> <project-dir> <explicit-target>
# Prints the resolved target or nothing. An explicit target and configured
# target must agree. Invalid, unreadable, unsafe, or duplicate configuration
# refuses rather than guessing. Callers record a non-empty result in task meta.
#
# fm_landing_target_require_branch <project-dir> <target>
# Refuses unless target is a local branch in project-dir.
#
# fm_landing_target_reject_default <project-dir> <target>
# Refuses when an explicit target names the project's detected default branch.

fm_landing_target_valid() {
  [ -n "${1:-}" ] && git check-ref-format --branch "$1" >/dev/null 2>&1
}

fm_landing_target_resolve() {
  local config=$1 project=$2 explicit=${3:-} file name mapped_name mapped_target found=
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

fm_landing_target_require_branch() {
  local project=$1 target=$2
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
