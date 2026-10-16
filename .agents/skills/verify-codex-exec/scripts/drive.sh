#!/usr/bin/env bash
# usage: drive.sh <scenario>   (scenario = file name in ../scenarios without .json)
# Runs one isolated `codex exec` turn against the local mock Responses server under strace.
# Prints the run directory on the last line of stdout.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill="$(dirname "$here")"
repo="$(cd "$skill/../../.." && pwd)"
scenario="${1:?usage: drive.sh <final-message|tool-calls>}"
scenario_file="$skill/scenarios/$scenario.json"
[ -f "$scenario_file" ] || { echo "no scenario $scenario_file" >&2; exit 2; }
codex_bin="${CODEX_BIN:-$repo/codex-rs/target/release/codex}"
evidence_root="${VERIFY_CODEX_EVIDENCE:-${XDG_STATE_HOME:-$HOME/.local/state}/verify-codex-exec}"
run="$evidence_root/$scenario-$(date +%Y%m%dT%H%M%S)-$$"
scratch="$run/scratch"
mkdir -p "$scratch/codex-home" "$scratch/cwd" "$run/strace"
cp "$scenario_file" "$run/scenario.json"
"$codex_bin" --version > "$run/codex-version.txt"

SCENARIO="$scenario_file" MOCK_LOG="$run/mock.log" MOCK_PORT_FILE="$scratch/mock.port" \
  python3 "$here/mock_responses.py" > "$run/mock.stderr" 2>&1 &
echo $! > "$scratch/mock.pid"
trap 'kill "$(cat "$scratch/mock.pid")" 2>/dev/null || true' EXIT
for _ in $(seq 50); do [ -s "$scratch/mock.port" ] && break; sleep 0.1; done
port="$(cat "$scratch/mock.port")"

set +e
(cd "$scratch/cwd" && CODEX_HOME="$scratch/codex-home" CODEX_API_KEY=verify-dummy \
  timeout 180 strace -ff -qq -e trace=execve -o "$run/strace/trace" \
  "$codex_bin" exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox \
  -c model_provider='"mock"' \
  -c "model_providers.mock={name=\"mock\",base_url=\"http://127.0.0.1:$port/v1\",wire_api=\"responses\",requires_openai_auth=false,supports_websockets=false}" \
  "verify-codex-exec $scenario" > "$run/stdout.txt" 2> "$run/stderr.txt")
echo $? > "$run/exit_code"
set -e
"$here/count-os-discovery.sh" "$run" > "$run/os-discovery.txt"
echo "exit_code $(cat "$run/exit_code")"
cat "$run/os-discovery.txt"
echo "$run"
