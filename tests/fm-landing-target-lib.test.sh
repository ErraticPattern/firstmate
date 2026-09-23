#!/usr/bin/env bash
# Behavior tests for bin/fm-landing-target-lib.sh: resolving a local-only task's
# landing branch from config/local-landing-targets and an explicit intake value,
# and reading the recorded landing_target= back from task metadata.
# Every case uses scratch repositories and a scratch config directory.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-landing-target-lib)
LIB="$ROOT/bin/fm-landing-target-lib.sh"

# run_lib <function> <args...>: call one library function in a fresh shell and
# print its combined output; the exit status is the function's.
run_lib() {
  bash -c '. "$1"; shift; "$@"' _ "$LIB" "$@" 2>&1
}

make_project() { # <name>: a scratch clone named <name> with a working branch
  local dir="$TMP_ROOT/projects/$1"
  fm_git_init_commit "$dir"
  git -C "$dir" branch sway-debian-stabilization main
  printf '%s\n' "$dir"
}

make_config() { # <name> [lines...]
  local dir="$TMP_ROOT/config-$1"
  shift
  mkdir -p "$dir"
  if [ "$#" -gt 0 ]; then
    printf '%s\n' "$@" > "$dir/local-landing-targets"
  fi
  printf '%s\n' "$dir"
}

test_absent_config_keeps_default_behavior() {
  local project config out rc
  project=$(make_project absent)
  config=$(make_config absent)
  out=$(run_lib fm_landing_target_resolve "$config" "$project" "")
  rc=$?
  expect_code 0 "$rc" "an absent configuration should resolve"
  assert_equals "" "$out" "an absent configuration resolved a target"
  out=$(run_lib fm_landing_target_resolve "$config" "$project" sway-debian-stabilization)
  assert_equals sway-debian-stabilization "$out" "an explicit target was not passed through"
  pass "an absent configuration resolves nothing unless a target is passed explicitly"
}

test_configured_mapping_resolves_only_its_project() {
  local project other config out
  project=$(make_project dotfiles)
  other=$(make_project unrelated)
  config=$(make_config mapped '# working branches' '' $'dotfiles\tsway-debian-stabilization')
  out=$(run_lib fm_landing_target_resolve "$config" "$project" "") \
    || fail "a valid mapping refused: $out"
  assert_equals sway-debian-stabilization "$out" "the mapped project did not resolve its target"
  out=$(run_lib fm_landing_target_resolve "$config" "$other" "") \
    || fail "an unmapped project refused: $out"
  assert_equals "" "$out" "an unmapped project inherited another project's target"
  out=$(run_lib fm_landing_target_resolve "$config" "$project" sway-debian-stabilization) \
    || fail "an agreeing explicit target refused: $out"
  assert_equals sway-debian-stabilization "$out" "an agreeing explicit target did not resolve"
  pass "a configured mapping resolves for its own project only"
}

test_ambiguous_configuration_refuses() {
  local project config out rc
  project=$(make_project ambiguous)
  for lines in \
    $'ambiguous\tsway-debian-stabilization\nambiguous\tother' \
    $'unrelated\tone\nunrelated\ttwo\nambiguous\tsway-debian-stabilization' \
    'ambiguous sway-debian-stabilization' \
    $'ambiguous\tsway-debian-stabilization\textra' \
    $'ambiguous\tbad..name' \
    $'unrelated\t-bad'; do
    config=$(make_config "bad-$RANDOM" "$lines")
    out=$(run_lib fm_landing_target_resolve "$config" "$project" "")
    rc=$?
    [ "$rc" -ne 0 ] || fail "configuration was accepted: $(printf '%q' "$lines")"
    assert_contains "$out" "local landing-target configuration" \
      "refusal did not name the configuration for $(printf '%q' "$lines")"
  done
  config=$(make_config contradict $'ambiguous\tsway-debian-stabilization')
  out=$(run_lib fm_landing_target_resolve "$config" "$project" other)
  rc=$?
  [ "$rc" -ne 0 ] || fail "a contradicting explicit target was accepted"
  assert_contains "$out" "contradicts configured target" "contradiction was not named"
  config="$TMP_ROOT/config-directory"
  mkdir -p "$config/local-landing-targets"
  out=$(run_lib fm_landing_target_resolve "$config" "$project" "")
  rc=$?
  [ "$rc" -ne 0 ] || fail "an unreadable configuration path was accepted"
  assert_contains "$out" "cannot read" "an unreadable configuration was not named"
  pass "duplicate, malformed, invalid, contradictory, and unreadable configuration refuses"
}

test_recorded_branch_must_exist_and_differ_from_default() {
  local project out rc
  project=$(make_project checks)
  run_lib fm_landing_target_require_branch "$project" sway-debian-stabilization >/dev/null \
    || fail "an existing branch was refused"
  out=$(run_lib fm_landing_target_require_branch "$project" missing)
  rc=$?
  [ "$rc" -ne 0 ] || fail "a missing branch was accepted"
  assert_contains "$out" "does not exist" "missing branch refusal was not explained"
  git -C "$project" tag tagged-only
  out=$(run_lib fm_landing_target_require_branch "$project" tagged-only)
  rc=$?
  [ "$rc" -ne 0 ] || fail "a tag was accepted as a landing branch"
  run_lib fm_landing_target_reject_default "$project" sway-debian-stabilization >/dev/null \
    || fail "a non-default branch was refused as the default"
  out=$(run_lib fm_landing_target_reject_default "$project" main)
  rc=$?
  [ "$rc" -ne 0 ] || fail "the default branch was accepted as a landing target"
  assert_contains "$out" "is the default branch" "default-branch refusal was not explained"
  pass "a recorded target must be an existing local branch other than the default"
}

test_meta_reader_refuses_ambiguous_records() {
  local meta out rc
  meta="$TMP_ROOT/task.meta"
  fm_write_meta "$meta" "kind=ship" "mode=local-only"
  out=$(run_lib fm_landing_target_from_meta "$meta") || fail "a record without a target refused: $out"
  assert_equals "" "$out" "a record without a target produced one"
  fm_write_meta "$meta" "kind=ship" "landing_target=sway-debian-stabilization"
  out=$(run_lib fm_landing_target_from_meta "$meta") || fail "a single target refused: $out"
  assert_equals sway-debian-stabilization "$out" "the recorded target was not read back"
  for bad in "landing_target=" "landing_target=a..b"; do
    fm_write_meta "$meta" "kind=ship" "$bad"
    out=$(run_lib fm_landing_target_from_meta "$meta")
    rc=$?
    [ "$rc" -ne 0 ] || fail "an invalid record was accepted: $bad"
  done
  fm_write_meta "$meta" "landing_target=one" "landing_target=two"
  out=$(run_lib fm_landing_target_from_meta "$meta")
  rc=$?
  [ "$rc" -ne 0 ] || fail "a record with two targets was accepted"
  assert_contains "$out" "ambiguous or invalid landing target" "ambiguity was not named"
  pass "the metadata reader returns one valid target and refuses anything ambiguous"
}

test_absent_config_keeps_default_behavior
test_configured_mapping_resolves_only_its_project
test_ambiguous_configuration_refuses
test_recorded_branch_must_exist_and_differ_from_default
test_meta_reader_refuses_ambiguous_records
