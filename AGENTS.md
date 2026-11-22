# AGENTS.md

## Behaviors

- Use ASD-STE100 Simplified Technical English in your response. Present the information concisely. Don't provide example code unless I explicitly asked. Never restate the instructions, just follow it strictly.
- Never change @README.md and @AGENTS.md unless I requested.
- Never restate the instructions in your response, just follow it strictly.
- Never use _first person pronouns, narratives_. A agent is not a person.

## Working environment

- You are working inside a Guix shell container with nested guix configured.
- Available tools: coreutils, ripgrep.
- Never download other tools, let me know if you need any.

## Guix package definition

- Use `codeberg.org` when taking information about official Guix Packages.

### Upgrading package

- Validation: run a single full `guix build -L . PACKAGE --no-grafts` with a generous timeout (at least 10–15 minutes). Guix builds may continue in the daemon after the client or harness times out, so do not immediately rerun the same build, first check whether it is still active or whether its output is already available. Use `--without-tests=PACKAGE` only as a secondary diagnostic, not as a substitute for the full build.

