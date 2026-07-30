# CLI Checklist

Read after Step 2 of the core workflow, when the medium is cli.

## Arguments and flags

- Positional arguments are acceptable only for the one obvious subject of the command, and only when its meaning survives being read alone. Everything else takes a named flag.
- Every short flag has a long form. Scripts and docs use the long form; the short form is for typing.
- Short flags follow the ecosystem's existing meanings. Do not redefine -v, -f, -o, -h, -n to mean something novel.
- Booleans default to false and read as an action when set. Prefer --dry-run over --dry-run=true, and provide --no-X only when the default is on.
- Repeated values use a repeatable flag rather than a delimiter the shell will fight over.
- Never make the meaning of one argument depend on the position of another.

## Command structure

- Subcommands read as noun then verb, or verb then noun, but never both in the same tool.
- The same verb means the same thing everywhere in the tool. If "get" prints one and "list" prints many, that holds for every noun.
- Commands whose names differ only by a suffix usually want to be one command with a flag.
- One command, one job. A command that both mutates and reports cannot be composed safely.

## Help and discoverability

- Bare invocation with no arguments prints help and exits non-zero, rather than doing something.
- Help shows a working example for the most common task, not only a flag table. Most users copy the example.
- Help states the default value of every flag that has one.
- Error messages for bad usage point at the specific flag, and say what was expected, not just "invalid arguments".

## Streams and exit codes

- Data goes to stdout. Diagnostics, progress, and prompts go to stderr. This is what makes the tool pipeable.
- Exit code 0 means success only. Distinct non-zero codes for distinct failure classes, documented in help.
- Detect whether stdout is a TTY. Suppress color, spinners, and box drawing when it is not.
- Never prompt interactively when stdin is not a TTY. Fail with a message naming the flag that would have supplied the answer.
- Accept "-" as a filename meaning stdin or stdout where a path is taken.
- Offer a machine-readable output mode, such as --json, for anything a script would want to parse.

## Configuration precedence

Resolve in this order, highest first, and document it:

1. Command-line flag
2. Environment variable
3. Project config file
4. User config file
5. Built-in default

A tool that cannot be fully driven by flags alone cannot be used in CI.

## Safety

- Destructive operations support --dry-run, and the dry run output shows exactly what the real run would touch.
- Irreversible operations require confirmation when interactive, and an explicit --yes or --force when not. Never let --force be the only way to run non-interactively.
- Operations that can be interrupted say what state they left behind.
- Re-running the same command should be safe, or the tool should say clearly that it is not.

## Common findings to look for

| Symptom | Usual fix |
|---|---|
| Users keep passing arguments in the wrong order | Convert positionals to named flags |
| Output cannot be piped without sed | Move diagnostics to stderr, add --json |
| Everyone runs it with the same three flags | Change the defaults |
| A flag nobody has set on purpose | Delete it |
| Help exists but nobody reads it | Add a copyable example at the top |
| Script wrapping it parses human text | Add a stable machine output mode |
