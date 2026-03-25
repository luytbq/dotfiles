Analyze code changes and produce a markdown document tracing the full call chain (upstream callers → changed method → downstream effects), with before/after comparison and impact analysis. Optionally generate a draw.io diagram.

## Input

$ARGUMENTS

### Argument format

`[commit-range] [--drawio] [--help] [output-path]`

- **commit-range** (optional): specifies which changes to analyze
  - _(empty)_ — uncommitted changes (staged + unstaged)
  - `<commit>` — diff from that commit to HEAD (e.g. `abc1234`, `HEAD~3`)
  - `<commit1>..<commit2>` — diff between two specific commits
- **--drawio** (optional): also generate a `.drawio` diagram file
- **--help** (optional): print usage summary and exit
- **output-path** (optional): path for the output file(s). Default: next to the first changed file, named `{basename}-changes-flow.md`

### --help output

If `--help` is in the arguments, print the following and stop:

```
Usage: /analyze-changes [commit-range] [--drawio] [output-path]

Analyze code changes and trace the full call chain around modified methods.

Arguments:
  commit-range    Which changes to analyze (default: uncommitted changes)
                    (empty)          uncommitted staged + unstaged diff
                    <commit>         diff from commit to HEAD
                    <commit1>..<commit2>  diff between two commits
                    HEAD~N           last N commits

  --drawio        Also generate a draw.io flow diagram
  --help          Print this help message

  output-path     Output file path (default: auto-generated next to changed file)

Output:
  {base}-changes-flow.md       Markdown analysis (always)
  {base}-changes-flow.drawio   Draw.io diagram (only with --drawio)

Examples:
  /analyze-changes                      Analyze uncommitted changes
  /analyze-changes HEAD~1               Analyze last commit
  /analyze-changes abc123..def456       Analyze range between two commits
  /analyze-changes --drawio             Uncommitted changes + draw.io diagram
  /analyze-changes HEAD~2 --drawio      Last 2 commits + diagram
```

## Instructions

### Step 1: Get the diff

Based on the commit-range argument, run the appropriate git diff command:
- No argument: `git diff HEAD` (all uncommitted changes)
- Single commit: `git diff <commit> HEAD`
- Commit range: `git diff <commit1> <commit2>`

Parse the diff output to identify:
- Changed files and their paths
- For each file: the changed line ranges (from `@@` hunk headers)
- The added/removed lines

### Step 2: Identify changed methods

For each changed file:
1. Read the file
2. Find which method(s) contain the changed lines
3. Extract: method name, signature, class name, file path, line range
4. Read the method body to understand what changed (before vs after)

If there are multiple changed methods across files, process each independently and produce sections for each.

### Step 3: Trace upstream (callers)

For each changed method, trace callers going upward:

1. Search within the same file for methods that call the changed method
2. For each caller, search across the codebase for its callers
3. Continue until reaching an entry point:
   - HTTP handler / REST endpoint
   - Scheduler / cron job
   - Main method
   - Message consumer (Kafka, JMS, etc.)
   - Public API entry point
4. Record for each node: method signature, file:line, one-line description

### Step 4: Trace downstream (effects)

From the changed method's return, follow the data/control flow:

1. What does the caller do with the return value?
2. Identify persistent effects:
   - DB writes: find the SQL (in Java code, XML config, or stored procedures). Show the table, columns, and what values map to them.
   - HTTP responses: what fields are returned to the client
   - State changes: in-memory state, cache updates
   - Async effects: messages sent to queues, async callbacks
3. For XML-configured transformers (Spring, ESB, Mule), read the XML bean definitions to find the SQL and parameter mappings
4. Continue until reaching terminal effects (HTTP response, final DB write, etc.)

### Step 5: Analyze impact

For each downstream effect, compare before vs after:
- What values change?
- What values stay the same?
- Build a table: | Aspect | Before Change | After Change |
- Clearly mark which rows are "unchanged" to show the change is safe/scoped

### Step 6: Generate markdown

Write the output markdown file with this structure:

```markdown
# Flow: `ClassName.methodName()` — [one-line change summary]

## Change Summary

**File:** `path/to/File.java:line-range`
**Change:** [brief description of what was changed and why]

---

## Full Call Chain (Upstream → Changed Method → Downstream)

[ASCII flowchart using box-drawing characters showing the full chain.
 Each node shows: method signature, file:line, brief description.
 The changed method is highlighted with a star marker.
 The downstream section shows DB writes, HTTP responses, etc.]

---

## Impact Analysis

| Aspect | Before Change | After Change |
|--------|---------------|--------------|
| ... | ... | ... |

**[Summary sentence about what changed vs what stayed the same]**

---

## Affected Operations

| Operation | Entry Point | Affected? |
|-----------|------------|-----------|
| ... | ... | ... |
```

### Step 7: Generate draw.io diagram (only if --drawio flag)

If `--drawio` is in the arguments, generate a `.drawio` file following the `drawio-style-guide` skill conventions:

- **Color mapping:**
  - Start/End nodes: ellipse, light blue (#e1f5fe) / light green (#e8f5e9)
  - Process nodes: rounded rect, yellow (#fff9c4) for main flow, blue (#e3f2fd) for helpers
  - Decision diamonds: orange (#fff3e0)
  - Changed method container: dashed orange border (#FF9800), light orange fill (#FFF3E0)
  - Fix/change highlight: red border (#e53935), red fill (#ffcdd2)
  - Success path: green fill (#c8e6c9)
  - Error/fail path: red fill (#ffcdd2)

- **CRITICAL draw.io rules** (from drawio-style-guide):
  - Every edge MUST contain `<mxGeometry relative="1" as="geometry"/>`
  - Edge labels go as `value` attribute on the edge `<mxCell>`, NOT as nested children
  - All `<mxCell>` elements must be direct children of `<root>` — never nest cells
  - Include impact analysis table as an HTML table in a info-box node at the bottom

Save as `{output-base}-changes-flow.drawio`.

## Output

Report:
- Output file path(s)
- Number of changed methods analyzed
- Depth of upstream/downstream trace
- Key findings (what changes, what doesn't)
