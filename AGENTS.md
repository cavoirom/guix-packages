# AGENTS.md

## Behaviors

- Never change @README.md and @AGENTS.md unless I requested.
- Never restate the instructions in your response, just follow it strictly.
- Use ASD-STE100 Simplified Technical English in plans and documentation.

## Working environment

- You are working inside a Guix shell container with nested guix configured.
- `busybox` is available. Be aware to adapt the options to BusyBox's commands.
- `deno` is available, use it with JavaScript / TypeScript as the `python` replacement when you do scripting.
- Never use `rg` because I blocked it, it will never be available.
- Never download other tools, let me know if you need any.

## Upgrading package

- Validation: run a single full `guix build -L . PACKAGE --no-grafts` with a generous timeout (at least 10–15 minutes). Guix builds may continue in the daemon after the client or harness times out, so do not immediately rerun the same build, first check whether it is still active or whether its output is already available. Use `--without-tests=PACKAGE` only as a secondary diagnostic, not as a substitute for the full build.

