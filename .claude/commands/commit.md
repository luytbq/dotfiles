# Commit and Push

Commit the current changes, then push to the remote.

## Steps

1. Run git diff --cached to see staged changes. If nothing is staged, run git diff to analyze unstaged changes and stage them.
2. Write the commit message following the format below, then commit.
3. Push right away, without asking:
   - If the branch has an upstream, run git push.
   - If not, run git push -u origin followed by the branch name.
4. Report the commit hash, the subject line, and the branch that was pushed.

If the push is rejected, stop and show the user the exact error. Do not pull, rebase, retry, or force push.

## Commit Message Format

```
<type>(<scope>): <short summary>

[optional body describing the 'why' and 'what', not the 'how']

[optional footer(s) for breaking changes or issue links]
```

- Use the imperative mood ("add", "fix", not "added", "fixes").
- Do not end the subject line with a period.
- Limit the subject line to 50 characters.
- Wrap body lines at 72 characters.
- Separate the subject from the body with one blank line.
- Choose the scope by feature name (short, e.g. refund, payment-notification, otp, qr-code). Never use a project name as scope. Leave it blank if the change spans multiple features or is cross-cutting.
- Focus the body on the motivation behind the change, not a literal translation of the diff lines.

## Allowed Types

- **feat**: A new feature for the user
- **fix**: A bug fix for the user
- **docs**: Changes to the documentation
- **style**: Formatting, missing semi-colons, etc. (no production code changes)
- **refactor**: Refactoring production code (no bug fixes, no new features)
- **perf**: Code changes that improve performance
- **test**: Adding missing tests or correcting existing tests
- **chore**: Updating build tasks, package manager configs, etc.
