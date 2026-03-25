Initialize a new Dev Analysis markdown file by gathering project metadata from the user.

## Instructions

Use the AskUserQuestion tool to collect the following information. Ask all questions in a single call:

1. **Doc ID** — Document identifier (e.g., `MCU_20250310_019`, `TDE_20251222_119`)
2. **Doc Title** — Short title describing the task (e.g., `Shinhanlife - Verify cardholder name`)
3. **Product** — Product name (e.g., `Payment Gateway`, `Cổng thanh toán`). Offer common options: `Payment Gateway`, `Merchant Portal`, `Admin Portal`
4. **Project** — Project/module names (e.g., `msp, wsp`, `theme general/default`)
5. **Function** — Business function area (e.g., `International card payment`, `Installment payment`)
6. **Description** — Brief description of what this task does

Use these defaults (do not ask):
- **Creator**: `LuytBQ`
- **Reviewer**: (empty)
- **Changes**: version 1, "Initial creation", today's date in `DD/MM` format

## Output

After collecting answers, create the file `{doc_id}-dev-analysis.md` in the current working directory, where `{doc_id}` is the Doc ID value provided (e.g., `MCU_20250310_019-dev-analysis.md`).

Use this exact template structure:

```markdown
---
product: "{product}"
project: "{project}"
function: "{function}"
description: "{description}"
creator: "LuytBQ"
reviewer: ""
doc_id: "{doc_id}"
doc_title: "{doc_title}"
changes:
  - version: 1
    content: "Initial creation"
    date: "{today DD/MM}"
---

# I - General Description

## Purpose

(describe the purpose here)

## Requirements

(describe the requirements here)

# II - Dev Analysis

## Current Status

(describe current status here)

## Solution

### Summary

(summarize the solution here)

### Detail

#### (subtopic 1)

(detail here)

## Impact

## Deployment plan

## Service Monitoring

## Network Monitoring

## Security

## Audit Log
```

Fill in the front matter with the user's answers. Leave the body sections as placeholder hints in parentheses for the user to fill in later.

Report the output file path when done.
