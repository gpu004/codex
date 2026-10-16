# Single turn with a final message

`codex exec "<prompt>"` sends one turn to the configured provider and prints the assistant's final message on stdout.

## Sub-features

- Provider configured purely through `-c model_provider=...` and `-c model_providers.<id>={...}` overrides.
- API-key auth through `CODEX_API_KEY`, with no login state in `CODEX_HOME`.
- Final message on stdout; logs and token usage on stderr.

## How to get to it (user POV)

Run `codex exec "<prompt>"` from a shell in any directory. `--skip-git-repo-check` is needed outside a git repo.

## Driving it with drive.sh

```bash
run="$(.agents/skills/verify-codex-exec/scripts/drive.sh final-message | tail -1)"
cat "$run/exit_code"                                    # 0
grep -x 'verify-codex-exec: final message' "$run/stdout.txt"
grep -c 'POST /v1/responses' "$run/mock.log"            # 1
```

## Gotchas

- The mock answers `GET` on any path with `{"models": []}`, so model-list refresh succeeds but returns no models.
- stderr contains `INFO` lines and `tokens used`; do not treat a non-empty stderr as failure.
