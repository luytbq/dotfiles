Generate a Dev Analysis `.docx` document from a Vietnamese markdown file.

## Input

Read the file: $ARGUMENTS

## Instructions

Read the input Vietnamese markdown file. Parse the YAML front matter and markdown body, then generate a `.docx` file using the MCP word-document-server tools.

### Global styling

Apply consistently across the entire document:

- **Font:** Arial for all text. Exception: code blocks retain `Courier New`.
- **Heading color:** All headings (Heading 1–5) must use a single consistent dark color `#1F272E` (near-black charcoal). Never leave some headings black and others blue.
- **Tables – cell padding:** 0.15 cm on all four sides for every cell.
- **Tables – font size:** Choose based on content density, apply uniformly to all rows in each table:
  - Sparse (few columns, short content): 11 pt
  - Medium: 10 pt
  - Dense (many columns or long text): 9 pt

After generating the document, apply these styles via a Python script using `python-docx` (bulk operation — do not call MCP tools cell by cell):
- Set `font.name = 'Arial'` on every run in paragraphs and table cells, skipping runs where `font.name` contains `'Courier'`.
- Set `font.color.rgb = RGBColor(0x1F, 0x27, 0x2E)` on every run inside heading paragraphs.
- Set table cell margins to 85 twips (≈ 0.15 cm) using `<w:tcMar>` XML manipulation.
- Set `font.size = Pt(N)` on every run in each table according to the density rule above.

### Document structure

Build the document in this exact order:

#### 1. Title
Add a paragraph with text: `TRÁCH NHIỆM BIÊN SOẠN, XEM XÉT VÀ PHÊ DUYỆT`
Style: bold, centered.

#### 2. Metadata table
Add a table with **4 rows x 3 columns** using front matter values:

| Col 1 | Col 2 | Col 3 |
|---|---|---|
| Product: `{product}` | Creator: `{creator}` | Date: `{changes[0].date}` |
| Project: `{project}` | | |
| Function: `{function}` | Reviewer: `{reviewer}` | Date: |
| Mô tả: `{description}` | | Date: |

Format this table with borders.

#### 3. Doc ID + Title
Add a blank line, then a paragraph Heading 1 style, with: `{doc_id}  {doc_title}`

#### 4. Change tracking section
Add a blank line, then a paragraph with bold text: `THEO DÕI SỬA ĐỔI NỘI DUNG TÀI LIỆU`

Add a table with columns: `STT | Nội dung | Ngày | Trang | Chi tiết | Người phê duyệt`

- Header row with those 6 column names
- One data row per entry in `changes[]`: version number, content, date, and empty cells for the rest
- Add one empty row at the end

Format this table: add borders, highlight header row (blue background `4472C4`, white text).

#### 5. Body content
Process the markdown body. Map heading levels to Word styles:

| Markdown | Word Style |
|---|---|
| `#` (H1) | Heading 1 |
| `##` (H2) | Heading 3 |
| `###` (H3) | Heading 4 |
| `####` (H4) | Heading 5 |

Note: H2 in markdown maps to Heading 3 in Word (skipping Heading 2), H3 maps to Heading 4, H4 maps to Heading 5.

For body text (non-heading paragraphs), add as normal paragraphs.

Process content section by section:
- For each heading, use `add_heading` with the appropriate level
- For each paragraph of body text, use `add_paragraph`
- Preserve list items as paragraphs (with their `-` prefix or indentation)
- Preserve blank lines between sections (add empty paragraphs)

#### 6. Operational sections with defaults
After processing all markdown content, check if these sections exist. If any are missing from the markdown, add them with "N/A" as content:

- `Monitor dịch vụ` (Heading 3)
- `Monitor network (đối với dịch vụ mới)` (Heading 3)
- `Security` (Heading 3)
- `Audit log` (Heading 3)

Note: In the template, the full heading for network monitoring is `Monitor network (đối với dịch vụ mới)`. Use this full form.

### Output filename

Save the document as: `{doc_id} - Dev analysis.docx` in the same directory as the input file.

### After generation

1. Run the Python styling script described in **Global styling** above to apply Arial font, heading colors, and table padding in one pass.
2. Report the output file path and a summary of sections included.
