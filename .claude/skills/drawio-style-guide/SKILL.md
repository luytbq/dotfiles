---
name: drawio-style-guide
description: Draw.io XML styling conventions for flowchart diagrams. Use when creating or editing draw.io files.
user-invocable: false
---

## Color Palette

| Role             | Hex      |
|------------------|----------|
| Start node       | #e1f5fe  |
| Decision diamond | #fff3e0  |
| Process/Database | #fff9c4  |
| Success/PASS     | #c8e6c9  |
| Fail/Error       | #ffcdd2  |
| End node         | #e8f5e9  |
| Info box         | #e3f2fd  |

## Shape Styles

```xml
<mxCell style="ellipse;fillColor=#e1f5fe;strokeColor=#0288d1;fontStyle=1" …/>
<mxCell style="rhombus;fillColor=#fff3e0;strokeColor=#ff9800" …/>
<mxCell style="rounded=1;fillColor=#fff9c4;strokeColor=#fbc02d" …/>
<mxCell style="rounded=1;fillColor=#c8e6c9;strokeColor=#43a047" …/>
<mxCell style="rounded=1;fillColor=#ffcdd2;strokeColor=#e53935" …/>
<mxCell style="ellipse;fillColor=#e8f5e9;strokeColor=#43a047;fontStyle=1" …/>
<mxCell style="rounded=1;fillColor=#e3f2fd;strokeColor=#1565c0" …/>
```

## Edge Styles

- Default: `edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1`

### CRITICAL: Edges must contain `<mxGeometry>`

Every edge `<mxCell>` **MUST** have a child `<mxGeometry relative="1" as="geometry"/>`, otherwise **arrows will not render** in draw.io web.

Correct:
```xml
<mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;" edge="1" source="n1" target="n2" parent="1">
  <mxGeometry relative="1" as="geometry"/>
</mxCell>
```

Wrong (arrows won't render):
```xml
<mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;" edge="1" source="n1" target="n2" parent="1"/>
```

### Edge Labels

Place labels as the `value` attribute directly on the edge `<mxCell>`. Do **NOT** nest child `<mxCell>` elements inside edges — this causes "Could not add object mxCell" errors.

Correct:
```xml
<mxCell id="e1" value="Yes" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;" edge="1" source="n1" target="n2" parent="1">
  <mxGeometry relative="1" as="geometry"/>
</mxCell>
```

Wrong (causes load errors):
```xml
<mxCell id="e1" style="..." edge="1" source="n1" target="n2" parent="1">
  <mxCell value="Yes" style="edgeLabel;html=1;" vertex="1" connectable="0" parent="e1">
    <mxGeometry relative="1" as="geometry"/>
  </mxCell>
</mxCell>
```

## Document Structure

- One `<diagram>` element per page with `name` attribute.
- `<mxGraphModel>` root containing `<mxCell id="0"/>` and `<mxCell id="1" parent="0"/>`.
- All `<mxCell>` elements (vertices AND edges) must be **direct children of `<root>`**. Never nest `<mxCell>` inside another `<mxCell>`.
- Follow existing examples for grouping, layout, and page metadata.
