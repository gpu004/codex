#!/usr/bin/env bash
# Read-only: is this checkout/binary worth driving?
set -uo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
codex_bin="${CODEX_BIN:-$repo/codex-rs/target/release/codex}"
evidence_root="${VERIFY_CODEX_EVIDENCE:-${XDG_STATE_HOME:-$HOME/.local/state}/verify-codex-exec}"
status=0
check() { if eval "$2" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; status=1; fi; }
check "linux host (OS discovery feature is Linux-only)" '[ "$(uname -s)" = Linux ]'
check "codex binary at $codex_bin" '[ -x "$codex_bin" ]'
check "codex binary runs (--version)" '"$codex_bin" --version'
check "python3 for the mock Responses server" 'command -v python3'
check "strace for subprocess evidence" 'command -v strace'
check "timeout (coreutils)" 'command -v timeout'
[ -x "$codex_bin" ] && echo "info binary: $("$codex_bin" --version 2>/dev/null) built $(date -r "$codex_bin" '+%F %T')"
[ -x "$codex_bin" ] && [ -d "$repo/codex-rs" ] && [ -n "$(find "$repo/codex-rs" -name '*.rs' -newer "$codex_bin" -not -path '*/target/*' -print -quit)" ] \
  && echo "warn sources changed after the binary was built; rebuild before trusting results"
for pidfile in "$evidence_root"/*/scratch/mock.pid; do
  [ -f "$pidfile" ] || continue
  pid="$(cat "$pidfile")"
  if kill -0 "$pid" 2>/dev/null; then echo "warn stale mock server pid $pid from ${pidfile%/scratch/mock.pid}; run cleanup.sh"; fi
done
exit "$status"
