---
name: mermaid-to-drawio
description: Convert Mermaid flowcharts from Markdown files to draw.io XML format
disable-model-invocation: true
argument-hint: [markdown-file] [output-file]
---

Extract Mermaid flowchart blocks from `$1` and generate a `.drawio` XML file at `$2`.

## Steps

1. Read the Markdown file and locate all ```mermaid``` code blocks containing **flowchart** definitions (skip sequence diagrams, etc.).
2. For each flowchart:
   - Parse nodes, edges, `classDef` definitions, and `class` assignments.
   - Map Mermaid node shapes to draw.io shapes:
     - `[text]` → rounded rectangle (process)
     - `{text}` → rhombus (decision)
     - `([text])` → stadium/rounded rectangle (start/end)
     - `[(text)]` → cylinder (database)
     - `@{ shape: comment }` → note shape
   - **Only color nodes that have explicit `classDef`/`class` assignments** in the Mermaid source. All other nodes use the default plain style (white fill, dark stroke). Do NOT apply default color schemes unless the user asks for it.
   - Subgraphs become dashed background rectangles — NOT swimlane containers.
3. Assemble a draw.io XML document:
   - Create one `<diagram>` per flowchart, named after its preceding markdown heading.
   - Insert `<mxCell>` elements for vertices with proper `style` attributes.
   - Connect edges using `orthogonalEdgeStyle`.
4. Output a UTF-8 encoded `.drawio` file preserving any diacritics (Vietnamese, etc.).
5. If multiple diagrams exist, include all pages in the same XML file.

## Default color scheme (only when user requests colored output)

| Role     | Fill Color | Stroke Color | Usage                  |
|----------|------------|--------------|------------------------|
| start    | #DAE8FC    | #6C8EBF      | Light blue             |
| decision | #FFE6CC    | #D79B00      | Orange                 |
| process  | #FFF2CC    | #D6B656      | Yellow                 |
| database | #FFF2CC    | #D6B656      | Yellow                 |
| success  | #D5E8D4    | #82B366      | Green                  |
| fail     | #F8CECC    | #B85450      | Red                    |
| end      | #D5E8D4    | #82B366      | Light green            |
| info     | #DAE8FC    | #6C8EBF      | Blue                   |
| group    | #F5F5F5    | #999999      | Dashed, light gray bg  |

## Draw.io XML pitfalls — MUST follow

### Unique IDs across pages
- Each `<diagram>` page has root cells `id="0"` and `id="1"`. In a multi-page file, these collide.
- **Fix**: prefix root cell IDs with the page index: `"{pageIdx}_0"`, `"{pageIdx}_1"`.
- All node/edge `parent` attributes must reference the page-specific root1 ID.
- Diagram `id` attributes must also be unique — do NOT truncate long names (use hash instead).
- Node/edge IDs must not collide with root cell IDs — start the counter at 100+.

### No swimlane containers for subgraphs
- Swimlane children use **relative** coordinates to the parent, which causes layout chaos if you pass absolute coordinates.
- **Fix**: Use plain background rectangles with `container=0;collapsible=0;` style. Insert them **before** child nodes in the XML so they render behind.
- All nodes stay as children of the page root (`parent=root1`), using absolute coordinates.

### Group sizing
- Groups must be large enough to contain ALL child nodes including diamonds (which are wider/taller than regular rectangles).
- **Formula**: `group_width = max(node_width, decision_width) + 2 * padding + margin`
- Calculate content bottom = last child y + last child height. Group height must exceed this + bottom padding.
- Use explicit dimension-based spacing (`node_height + gap`) instead of magic-number vertical gaps.

### HTML entities in node labels
- Use raw `<br/>` and `&` in Python/code strings. Let the XML serializer escape them to `&lt;br/&gt;` and `&amp;`.
- Do NOT pre-escape to `&lt;br/&gt;` — the serializer will double-escape to `&amp;lt;`.

### Draw.io style strings
```
# Plain (default - no color)
process:  rounded=1;whiteSpace=wrap;html=1;
decision: rhombus;whiteSpace=wrap;html=1;
group:    rounded=1;whiteSpace=wrap;html=1;fillColor=#F5F5F5;strokeColor=#999999;dashed=1;verticalAlign=top;fontStyle=1;fontSize=13;container=0;collapsible=0;
edge:     edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;
comment:  shape=note;whiteSpace=wrap;html=1;fillColor=#E6E6E6;strokeColor=#999999;size=14;backgroundOutline=1;
```

### Recommended dimensions
```
Node:     280 x 45
Decision: 240 x 80
Group padding: 25px
Vertical gap: node_height + 20
```
