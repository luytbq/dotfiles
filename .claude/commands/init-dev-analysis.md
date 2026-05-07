Initialize a new Dev Analysis markdown file by gathering project metadata from the user.

## Instructions

Create a new file task-x-dev-analysis.md in the current working directory with the exact content below.

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

# I - Mô tả chung

## Mục đích

## Yêu cầu

# II - Dev Analysis

## Hiện trạng

## Giải pháp

## Phạm vi ảnh hưởng

## Kế hoạch deploy

## Monitor sau khi deploy

### Query dữ liệu

### Check log nginx API

### Check log service các luồng ảnh hưởng

### Monitor khác nếu có

## Service Monitoring

## Network Monitoring

## Security

## Audit Log
```
