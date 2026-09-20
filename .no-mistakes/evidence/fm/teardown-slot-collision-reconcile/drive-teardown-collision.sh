#!/usr/bin/env bash
set -u
ROOT=/home/jamaro/.no-mistakes/worktrees/81fdadc68898/01M2ZA30SZ50GYHS18H1NMK3MA
TEARDOWN="$ROOT/bin/fm-teardown.sh"
BASE=$(mktemp -d /tmp/fm-manual.XXXXXX)

make_case() {
  local d="$BASE/$1"
  mkdir -p "$d/home/state" "$d/home/data" "$d/home/config" "$d/fakebin" "$d/project"
  git init -q "$d/project"
  : > "$d/runtime.log"
  for t in tmux treehouse; do
    cat > "$d/fakebin/$t" <<SH
#!/usr/bin/env bash
printf '$t' >> "\${FM_RUNTIME_LOG:?}"
printf ' <%s>' "\$@" >> "\${FM_RUNTIME_LOG:?}"
printf '\n' >> "\${FM_RUNTIME_LOG:?}"
exit 0
SH
    chmod +x "$d/fakebin/$t"
  done
  mkdir -p "$d/pool/1"
  git -C "$d/project" -c user.name=t -c user.email=t@e.invalid commit --allow-empty -qm fixture
  git -C "$d/project" worktree add -q --detach "$d/pool/1/project"
  ln -s "pool/1/project" "$d/worktree"
  printf '{"worktrees":[{"name":"1","path":"%s"}]}\n' "$d/pool/1/project" > "$d/pool/treehouse-state.json"
  : > "$d/worktree/sentinel"
  printf '%s\n' "$d"
}
meta() { # dir id
  printf 'window=firstmate:fm-%s\nendpoint_task_id=%s\nworktree=%s/worktree\nproject=%s/project\nkind=scout\n' \
    "$2" "$2" "$1" "$1" > "$1/home/state/$2.meta"
}
run() { # dir id
  FM_HOME="$1/home" FM_ROOT_OVERRIDE="$ROOT" FM_RUNTIME_LOG="$1/runtime.log" \
    PATH="$1/fakebin:$PATH" FM_GATE_REFUSE_BYPASS=1 "$TEARDOWN" "$2" --force
}

banner() { echo; echo "############ $* ############"; }

# ---------- S1 + S4 ----------
banner "S1: two finished records name one slot; claim names the newer task"
d=$(make_case s1); meta "$d" stale-task; meta "$d" claimant-task
printf 'task=claimant-task\nhome=%s/other-home\n' "$d" > "$d/pool/1/.fm-slot-owner"
( cd "$d/worktree" && exec sleep 45 ) & worker=$!
echo "--- fm-teardown.sh stale-task --force"
run "$d" stale-task; echo "exit=$?"
echo "--- records after:"; ls "$d/home/state" | sed 's/^/    /'
echo "--- claimant worker alive: $(kill -0 $worker 2>/dev/null && echo yes || echo NO)"
echo "--- claim file after:"; sed 's/^/    /' "$d/pool/1/.fm-slot-owner"
echo "--- claimant worktree sentinel: $([ -e "$d/worktree/sentinel" ] && echo present || echo GONE)"
echo "--- runtime calls:"; sed 's/^/    /' "$d/runtime.log"

banner "S4: the claimant's own teardown now returns the slot normally"
echo "--- fm-teardown.sh claimant-task --force"
run "$d" claimant-task; echo "exit=$?"
kill $worker 2>/dev/null; wait $worker 2>/dev/null
echo "--- records after:"; ls -A "$d/home/state" | sed 's/^/    /'
echo "--- runtime calls:"; sed 's/^/    /' "$d/runtime.log"

# ---------- S2 adversarial ----------
banner "S2 (adversarial): two live records, NO owner claim -> must still refuse"
d=$(make_case s2); meta "$d" task-a; meta "$d" task-b
echo "--- fm-teardown.sh task-a --force"
run "$d" task-a; echo "exit=$?"
echo "--- records after:"; ls "$d/home/state" | sed 's/^/    /'
echo "--- sentinel: $([ -e "$d/worktree/sentinel" ] && echo present || echo GONE)"
echo "--- runtime calls: [$(cat "$d/runtime.log")]"

# ---------- S3 adversarial ----------
banner "S3 (adversarial): two live records + UNREADABLE claim -> refuse before the scan"
d=$(make_case s3); meta "$d" task-a; meta "$d" task-b
mkdir -p "$d/pool/1/.fm-slot-owner"   # a directory cannot be read as a claim
echo "--- fm-teardown.sh task-a --force"
run "$d" task-a; echo "exit=$?"
echo "--- records after:"; ls "$d/home/state" | sed 's/^/    /'
echo "--- runtime calls: [$(cat "$d/runtime.log")]"

# ---------- S5 ----------
banner "S5: claim names THIS task -> ordinary teardown returns the slot"
d=$(make_case s5); meta "$d" mine
printf 'task=mine\nhome=%s/home\n' "$d" > "$d/pool/1/.fm-slot-owner"
echo "--- fm-teardown.sh mine --force"
run "$d" mine; echo "exit=$?"
echo "--- records after:"; ls -A "$d/home/state" | sed 's/^/    /'
echo "--- claim file: $([ -e "$d/pool/1/.fm-slot-owner" ] && echo present || echo dropped)"
echo "--- runtime calls:"; sed 's/^/    /' "$d/runtime.log"
echo; echo "BASE=$BASE"
