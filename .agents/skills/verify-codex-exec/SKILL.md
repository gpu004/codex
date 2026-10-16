---
name: verify-codex-exec
description: Drive the real `codex exec` CLI end to end against a local mock Responses API, with an isolated CODEX_HOME and strace subprocess evidence. Use to prove `codex exec` turns, tool calls, or process-level side effects (for example OS discovery running once per process) on Linux.
---

# Verify `codex exec`

Primary surface: the `codex exec` CLI (`codex-rs/exec`). Other surfaces (TUI, `codex app-server`, IDE clients) are not covered here. `codex exec` hosts the same in-process app-server, so startup work such as login user-agent, analytics, and OTel metadata runs on this path.

Each drive is one short-lived `codex exec` process in its own scratch `CODEX_HOME` and working directory. It talks to a local mock Responses server bound to an ephemeral port. Drives never touch `~/.codex`, and any number can run side by side.

## Launch

Build the binary once from `codex-rs/`:

```bash
cd codex-rs && cargo build --release --bin codex
```

The result is `codex-rs/target/release/codex`. To point at a different binary (for example a stock build for a before/after comparison), set `CODEX_BIN=/path/to/codex`. The mock server is started by `drive.sh`. It is ready when it writes its port to `scratch/mock.port`, which the script waits for. There is no long-lived instance to tear down.

## Doctor

Read-only. Run it first, and again after any failed drive:

```bash
.agents/skills/verify-codex-exec/scripts/doctor.sh
```

Every line must be `ok`. A `warn sources changed after the binary was built` line means the binary does not contain your edits, so rebuild it. This check compares file mtimes, so a binary copied after the build always looks fresh. A `warn stale mock server` line means a previous drive was interrupted, so run cleanup.

## Drive

```bash
.agents/skills/verify-codex-exec/scripts/drive.sh <scenario>
```

Scenarios live in `scenarios/*.json` and are served by `scripts/mock_responses.py`:

- `final-message`: one assistant message, no tools.
- `tool-calls`: two `exec_command` calls, then a final message.

`drive.sh` runs:

```bash
codex exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox -c model_provider='"mock"' -c 'model_providers.mock={...base_url="http://127.0.0.1:<port>/v1",wire_api="responses",requires_openai_auth=false,supports_websockets=false}' "verify-codex-exec <scenario>"
```

It runs under `strace -ff -e trace=execve` with `CODEX_API_KEY=verify-dummy`. It prints the exit code and the OS-discovery counts, and prints the run directory on the last line. The sandbox is bypassed so the result does not depend on host sandbox support; the cwd is a throwaway scratch dir.

## Evidence

Each run writes to `$VERIFY_CODEX_EVIDENCE/<scenario>-<timestamp>-<pid>/`. The default root is `${XDG_STATE_HOME:-~/.local/state}/verify-codex-exec`. A run directory contains:

- `stdout.txt` and `stderr.txt`: what the user sees. The final message is on stdout.
- `exit_code`
- `codex-version.txt`
- `scenario.json`
- `mock.log`: every request, how many tool outputs it carried (`outputs=N`), and `OUTPUT <call_id> <text>` lines with the tool results Codex sent back.
- `strace/trace.<pid>`: one file per process Codex spawned.
- `os-discovery.txt`: successful `execve` counts for `lsb_release`, `dpkg-query`, and `getconf`, produced by `scripts/count-os-discovery.sh <run-dir>`.

Proof standards:

- Drive the real `codex exec` binary. The mock replaces only the model provider, which is already a network boundary.
- Prove side effects from `mock.log` and `strace`, not only from stdout. A final message alone does not prove that a tool ran or that its output reached the model.
- For before/after claims, drive both binaries with the same scenario and keep both run directories.

## Cleanup

```bash
.agents/skills/verify-codex-exec/scripts/cleanup.sh            # every run under the evidence root
.agents/skills/verify-codex-exec/scripts/cleanup.sh <run-dir>  # one run
```

Cleanup stops the mock server by its recorded pid, but only if that pid is still `mock_responses.py`. It then deletes `scratch/` (the CODEX_HOME, cwd, and port/pid files). Everything else in the run directory is evidence and stays. `drive.sh` also stops its mock on exit.

## Helpers

All helpers live in `scripts/` and are executable:

- `doctor.sh`: preflight, see Doctor.
- `drive.sh <scenario>`: one isolated drive, see Drive.
- `count-os-discovery.sh <run-dir>`: recount OS-discovery subprocesses from a run's strace files.
- `cleanup.sh [run-dir ...]`: see Cleanup.
- `mock_responses.py`: the mock Responses server; started by `drive.sh`, not by hand. It needs `SCENARIO`, `MOCK_LOG`, and `MOCK_PORT_FILE`.

Feature map: [features/README.md](features/README.md).
