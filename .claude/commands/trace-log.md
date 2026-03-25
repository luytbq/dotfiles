Analyze a Java application log file and produce a readable markdown document that traces the execution flow, showing what code was called, significant values, and branch decisions at each step.

## Input

Read the log file: $ARGUMENTS

The argument format is: `<log-file-path> [output-file-path]`
- First argument (required): path to the log file to analyze
- Second argument (optional): path for the output markdown file

If no output file is specified, save next to the input log file with the same base name plus `-flow.md` suffix.
For example: `void-fail-1.log` → `void-fail-1-flow.md`

## Instructions

### Step 1: Parse the log file

Read the entire log file. For each log line, extract:
- **Timestamp**
- **Log level** (INFO, DEBUG, WARN, ERROR)
- **Logger class** (abbreviated, e.g., `c.o.o.c.c.c.Cup3DS2`)
- **Thread name**
- **Trace ID** (the bracketed ID like `[abc123-def456-01]`)
- **Message content**

### Step 2: Identify execution phases

Group consecutive log lines into logical phases/steps. A new phase starts when:
- A different class/component starts logging
- There is a clear boundary marker (e.g., `========`, `----------`, `Begin_`, `End `)
- The operation changes (e.g., from DB call to HTTP call)
- A significant state transition happens

- **Group tightly-coupled sub-operations** — when multiple consecutive log lines belong to the same logical method and serve a single purpose (e.g., encrypt → sign → send HTTP request → receive response within one method), keep them as one phase rather than splitting into separate steps. This applies especially to:
  - Request preparation + encryption + signing + HTTP call within a single method
  - Sequential DB lookups that feed into one operation
  Show the sub-operations as parts within the single step.

### Step 3: For each phase, trace the source code

For each identified phase, search the codebase to find the actual source code being executed:

1. **Resolve the logger class** — expand abbreviated package names (e.g., `c.o.o.c.c.c.Cup3DS2` → find the actual `Cup3DS2.java` file)
2. **Find the method** — search for the logged message string in the source file to identify which method produced it
3. **Extract context** — read surrounding code to understand:
   - What function/method is being called
   - What parameters are being passed
   - What branch/condition led to this code path
   - What the return value or outcome is
   - **Trace dispatch/orchestration methods** — when a log line indicates entering a high-level operation (e.g., a gateway call, a flow/pipeline entry), search for the dispatching method that orchestrates the sub-steps. Include this as a dedicated step showing:
     - The orchestrator method and its sequence of calls
     - Which branch/route was taken based on the input (e.g., command type, acquirer ID)
     - Forward references to the sub-steps that follow
     This provides a "table of contents" for the sub-steps and helps readers understand the overall pipeline before diving into details.

### Step 4: Generate the markdown document

Produce a markdown file with this structure:

```
# [Title based on the operation] — [outcome summary]

**Trace ID:** `...`
**Time:** `...`
**Duration:** ...
**Final Status:** ...

---

## Request

(The initial request that triggered this flow)

---

## Execution Flow

### 1. [Phase Name]
**File:** `ClassName.java:lineNumber`
**Method:** `methodName(params)`

(Description of what happens in this phase)

```java
// Relevant code snippet showing the logic
```

```
Key values:
  input1 = value1
  output1 = value2
```

---

### 2. [Next Phase]
...

---

## Root Cause Summary (if there's a failure)

(Clear explanation of what went wrong and why)

---

## Call Stack (condensed)

(ASCII tree showing the call hierarchy)

---

## Key Values Reference

(Table of important IDs, amounts, status codes, etc.)
```

### Guidelines for each step entry

- **Always include** the source file name and line number when found
- **Always include** the method signature
- **Show relevant code chunks** — the actual Java code that executed, especially:
  - Conditional branches that were taken
  - Method calls with their arguments
  - Return values and state changes
- **Highlight significant values** — IDs, amounts, status codes, response codes, error messages
- **Mark failures/warnings** with a visible indicator (e.g., a warning emoji or `**WARN**`/`**ERROR**` prefix)
- **Show timing** when available (duration between log entries or explicit timing in logs)
- **For DB calls** — show the procedure/query name, input params, and output. **DB writes (INSERT/UPDATE/DELETE) deserve their own step or detailed sub-section** — never reduce a DB write to a one-liner summary. For each DB write, trace the source (XML config or Java code) and show: the table name, the actual SQL with resolved parameter values from the flow context, and which columns are set to what. This is critical because DB writes represent persistent state changes that affect subsequent operations and debugging.
- **For HTTP calls** — show the URL, method, request body (summarized), and response
- **For branch decisions** — show the condition and which branch was taken
- **Do not duplicate values within a step** — if a value is already visible in the code snippet, HTTP request/response body, or log excerpt shown in the step, do NOT repeat it in the "Key values" block. The "Key values" block should only contain values that are NOT already visible in the step's other content, or values that need special emphasis/explanation (e.g., a decoded meaning, a flag indicating an error). If all significant values are already shown in the code/request body, omit the "Key values" block entirely for that step.

### Sensitive data

Mask or abbreviate sensitive data that appears in logs:
- Card numbers → show first 6 and last 4 digits
- Secret keys → show first 3 and last 3 characters
- Full tokens → show first 20 characters + "..."

## Output

Save the markdown file to the output path specified by the user, or if not specified, next to the input log file with `-flow.md` suffix.

Report the output file path and a brief summary of what was found (number of steps, final outcome, any errors detected).
