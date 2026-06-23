# Global Instructions

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
