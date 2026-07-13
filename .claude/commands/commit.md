# Git Commit Rules for Claude

You must follow these instructions strictly whenever generating git commit messages.

## General Structure
- Write the message in the imperative mood (e.g., "add", "fix", not "added", "fixes").
- Do not period-terminate the subject line.
- Limit the first line (subject) to 50 characters.
- Wrap all body lines at 72 characters.
- Separate the subject from the body with one blank line.

## Format Specification
Every commit must match this pattern:
<type> <scope>: <short summary>

[optional body describing the 'why' and 'what', not the 'how']

[optional footer(s) for breaking changes or issue links]

## Allowed Types
- **feat**: A new feature for the user
- **fix**: A bug fix for the user
- **docs**: Changes to the documentation
- **style**: Formatting, missing semi-colons, etc. (no production code changes)
- **refactor**: Refactoring production code (no bug fixes, no new features)
- **perf**: Code changes that improve performance
- **test**: Adding missing tests or correcting existing tests
- **chore**: Updating build tasks, package manager configs, etc.

## Guidelines for Claude
1. Run `git diff --cached` to see staged changes before writing the message.
2. If no changes are staged, run `git diff` to analyze unstaged changes.
3. Determine the `<scope>` based on the **feature name** (short, e.g., `refund`, `payment-notification`, `otp`, `qr-code`). NEVER use a project name as scope. Leave it blank if the change spans multiple features or is cross-cutting.
4. Focus the body on the **motivation** behind the change, not a literal translation of the diff lines.

