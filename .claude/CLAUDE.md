# Global Instructions

## Writing Guidelines
- Never use the em dash (—) in any output. Always use a hyphen (-) instead.
- Never use arrows (→) in any output. Always use (-->) instead.
- In Markdown output: never use inline code; limit bold and italic to 1–2 instances per paragraph at most; default to plain prose.

## Code Comments

Write for the person who opens the file months from now with no access to this
conversation, the diff, or the task. Everything else is noise to them.

- **Never encode working context.** No reference to the change being made, the
  task, the session, or the history of the edit. Banned: "vừa thêm", "sau khi
  sửa", "theo yêu cầu", "restored from commit abc123", "new logic", "previously
  this used X", "TODO from the review". The reader sees only the final state, so
  a comment that describes a transition is unreadable to them.
- **Change context belongs in the commit message or PR description**, never in
  the code.
- **Comment the why, not the what.** If the comment restates the line below it,
  delete it.
- **Do explain what the code cannot say itself**: why a magic value exists, why
  an order of operations matters, a workaround for an external system's quirk,
  an invariant a caller must uphold.
- **Prefer no comment to a filler comment.** Every comment must earn its line.
- **Match the file**: same language and same comment density as the surrounding
  code. Never mix languages inside one file.
- **Same rules for tests.** A test name states the behavior asserted, not the
  change that prompted it. TestMappingStatusAndReasonUnchanged, not
  TestMappingStillWorksAfterMyFix.
- **Never address the user in code**: no "as you requested", no "this fixes your
  issue". That goes in the response.

```go
// BAD - only meaningful while the diff is on screen
// Tra cuu nguyen ven truoc vi truoc day chi tra theo 3 chu so dau
// Cac hanh vi duoc dua lai tu commit 1cce9cc
// van cat con 3 chu so

// GOOD - true and useful with no context at all
// AmountTimeout: sleep 120s rồi xử lý tiếp như bình thường
// Amount dài hơn 3 chữ số phải tra nguyên chuỗi, tra theo 3 chữ số đầu sẽ trượt
```

Test before keeping a comment: would it still be true and useful if this code had
shipped a year ago and the reader had never seen the diff? If not, cut it.

## Skill/Command Self-Improvement

When a skill or command output doesn't satisfy the user and a fix is applied to the current output:
1. Fix the immediate output first
2. Then **suggest updating the skill/command definition itself** so future runs don't have the same issue

## Workflow Patterns

### Plan Mode
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately — don't keep pushing
- Write detailed specs upfront to reduce ambiguity

### Subagent Strategy
- Use subagents to keep the main context window clean
- Offload research, exploration, and parallel analysis to subagents
- One task per subagent for focused execution
- For complex problems, throw more compute at it via parallel subagents

### Agent Teams
When a task involves 3+ independent, parallelizable pieces of work, proactively ask the user whether to start an agent team.
Examples:
- Changes spanning multiple services (e.g., MSP + PSP + WSP in a paygate flow)
- Cross-language changes (e.g., Java paygate + Go msp/prsp for the same feature)
- Tracing/debugging a transaction across service boundaries in parallel
- Research from multiple angles (e.g., DB schema + API flow + log analysis)
- Feature work with independent layers (e.g., DB migration + service logic + IPN handler)

Don't suggest teams for sequential work or simple single-service tasks.

### Self-Improvement Loop
- After ANY correction from the user: capture the lesson so the same mistake isn't repeated
- Write rules for yourself that prevent the same mistake
- Review lessons at session start for the relevant project

### Verification Before Done
- Never mark a task complete without proving it works
- Build, run tests, check logs, demonstrate correctness
- Ask yourself: "Would a staff engineer approve this?"

### Multi-Project Awareness
- When working in `~/projects/onepay/`, always read the root CLAUDE.md first
- Each subdirectory is an independent git repo
- Check for project-level CLAUDE.md before diving into code
- If a project lacks CLAUDE.md, run `/init-project-claude` to generate one

@RTK.md
