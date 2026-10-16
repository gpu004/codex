# OS discovery runs once per process

On Linux, `os_info::get()` spawns `lsb_release` (which runs `dpkg-query`) and `getconf`. Codex needs OS metadata for the HTTP user agent (`codex-login`), analytics runtime metadata (`codex-analytics`), and OTel resource attributes (`codex-otel`). All of them must read the single process-wide cache in `codex-utils-os-info`, so each binary is spawned exactly once per `codex exec` process. See gpu004/codex#1.

## Sub-features

- User agent, analytics metadata, and OTel metrics share one cache.
- No direct `os_info::get()` calls: `clippy.toml` disallows it outside `codex-utils-os-info`.

## How to get to it (user POV)

This runs implicitly on every `codex exec` startup and first request. It is visible only as subprocesses, plus startup latency on slow hosts.

## Driving it with drive.sh

```bash
run="$(.agents/skills/verify-codex-exec/scripts/drive.sh final-message | tail -1)"
cat "$run/os-discovery.txt"     # expected: lsb_release 1 / dpkg-query 1 / getconf 1
```

Before/after, with a build from before the shared cache:

```bash
CODEX_BIN=/path/to/stock/codex .agents/skills/verify-codex-exec/scripts/drive.sh final-message   # lsb_release 3 / dpkg-query 3 / getconf 3
```

Unit-level check, which isolates `PATH` with fake `lsb_release` and `getconf` and calls from 8 threads:

```bash
cd codex-rs && cargo test -p codex-utils-os-info
```

## Gotchas

- Linux only. Hosts without `lsb_release` show `0` for it and `dpkg-query`; check `os-discovery.txt` against what the host has installed (`command -v lsb_release`).
- Counts come from successful `execve` only. PATH lookups that fail with `ENOENT` are not counted.
- A tool command in the scenario that itself runs one of these binaries would inflate the count. The `final-message` scenario runs no tools.
