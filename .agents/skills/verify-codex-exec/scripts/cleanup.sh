#!/usr/bin/env bash
# usage: cleanup.sh [run-dir ...]   (no args = every run under the evidence root)
# Stops mock servers this skill started (by recorded pid) and deletes scratch state.
# Evidence (stdout, stderr, strace, mock.log, os-discovery.txt) is kept.
set -euo pipefail
evidence_root="${VERIFY_CODEX_EVIDENCE:-${XDG_STATE_HOME:-$HOME/.local/state}/verify-codex-exec}"
runs=("$@")
[ "${#runs[@]}" -gt 0 ] || runs=("$evidence_root"/*/)
for run in "${runs[@]}"; do
  run="${run%/}"
  [ -d "$run/scratch" ] || continue
  if [ -f "$run/scratch/mock.pid" ]; then
    pid="$(cat "$run/scratch/mock.pid")"
    if kill -0 "$pid" 2>/dev/null && grep -q mock_responses.py "/proc/$pid/cmdline" 2>/dev/null; then kill "$pid"; fi
  fi
  rm -rf "$run/scratch"
  echo "cleaned $run"
done
