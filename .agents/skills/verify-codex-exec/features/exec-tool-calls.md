# Tool calls round trip

The model asks for shell commands (`exec_command` function calls). Codex runs them in the working directory and sends their output back in the next request. The turn ends with the model's final message.

## Sub-features

- Several function calls in one model response.
- Tool output returned as `function_call_output` items on the follow-up request.
- Final message printed after the tool round.

## How to get to it (user POV)

Any `codex exec` prompt that makes the model run commands. With `--dangerously-bypass-approvals-and-sandbox`, commands run without prompts.

## Driving it with drive.sh

```bash
run="$(.agents/skills/verify-codex-exec/scripts/drive.sh tool-calls | tail -1)"
cat "$run/exit_code"                                         # 0
grep -x 'verify-codex-exec: tool calls finished' "$run/stdout.txt"
grep 'outputs=2' "$run/mock.log"                             # second request carried both results
grep '^OUTPUT .*verify-tool-marker' "$run/mock.log"          # echo output reached the model
grep -l 'execve("/usr/bin/echo"\|execve("/bin/bash"' "$run"/strace/trace.* | head -1   # a shell was spawned
```

## Gotchas

- The mock chooses its response by counting tool outputs in the request, so a scenario step with N calls is answered only after all N outputs come back.
- Commands run in `scratch/cwd`, which cleanup deletes; copy anything you need out of it before cleanup.
