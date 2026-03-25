Translate the English dev-analysis markdown file to Vietnamese.

## Input

Read the file: $ARGUMENTS

## Instructions

1. Read the input markdown file completely.
2. Parse the YAML front matter — keep it unchanged (it is already in the target format).
3. Translate the markdown body from English to Vietnamese following these rules:

### Heading mapping (use these exact Vietnamese headings):

| English heading | Vietnamese heading |
|---|---|
| `# I - General Description` | `# I - Mô tả chung` |
| `## Purpose` | `## Mục đích` |
| `## Requirements` | `## Yêu cầu` |
| `# II - Dev Analysis` | `# II - Dev Analyst` |
| `## Current Status` | `## Hiện trạng` |
| `## Flow` | `## Flow` |
| `## Solution` | `## Giải Pháp` |
| `### Summary` | `### Tóm tắt` |
| `### Detail` | `### Chi tiết` |
| `## Impact` | `## Ảnh hưởng` |
| `## Deployment plan` | `## Phương án deploy` |
| `## Service Monitoring` | `## Monitor dịch vụ` |
| `## Network Monitoring` | `## Monitor network` |
| `## Security` | `## Security` |
| `## Audit Log` | `## Audit log` |

For `####` subtopic headings, translate the text to Vietnamese.

### Translation rules:

- **DO NOT translate**: code snippets, class names, method names, field names (e.g., `user_PayerName`, `auto_fill`, `is_locked`), API paths, URLs, project names (e.g., `msp`, `wsp`), component names, merchant IDs, JSON structures, technical abbreviations (e.g., API, GET, POST, UI)
- **DO translate**: descriptive prose, explanations, requirements text, general descriptions
- Keep the same markdown structure (headings, lists, indentation, blank lines)
- Use natural Vietnamese phrasing, not word-by-word translation
- Keep technical terms commonly used in Vietnamese IT (e.g., "auto", "fill", "validate", "request", "response", "header", "submit", "disable", "render", "component", "theme", "monitor", "deploy", "production", "block", "user") in their English form

## Output

Write the translated file to the same directory as the input file, with `_vi` appended before the extension.
For example: `my-task.md` → `my-task_vi.md`

Report the output file path when done.
