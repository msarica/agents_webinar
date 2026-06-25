---
name: markdown-to-docx
description: >-
  Converts Markdown (.md) files to Microsoft Word (.docx) format using pandoc.
  Use when the user asks to convert markdown to Word, export a .md file as
  docx, create a Word document from markdown, or batch-convert lesson plans or
  other markdown documents.
---

# Markdown to DOCX

## Quick Start

1. Confirm the source `.md` file path(s). If the user gave a topic name only, search the project for matching markdown files (e.g. `lesson_plans/lesson_plan_*.md`).
2. Run the conversion script from the project root:

```bash
.cursor/skills/markdown-to-docx/scripts/convert.sh path/to/file.md
```

3. Report the output `.docx` path to the user. Default: same directory as the source, same basename with `.docx` extension.

## Script Options

```bash
# Single file (default output: file.docx next to source)
.cursor/skills/markdown-to-docx/scripts/convert.sh input.md

# Custom output path
.cursor/skills/markdown-to-docx/scripts/convert.sh input.md -o output.docx

# Multiple files
.cursor/skills/markdown-to-docx/scripts/convert.sh file1.md file2.md

# Custom Word styling via reference document
.cursor/skills/markdown-to-docx/scripts/convert.sh input.md --reference-doc template.docx
```

## Workflow

1. **Validate input** — Source file must exist and have a `.md` extension.
2. **Convert** — Run `convert.sh`. Do not hand-roll conversion logic unless pandoc is unavailable.
3. **Verify** — Confirm the output file exists and has a non-zero size.
4. **Report** — Tell the user the full path to the generated `.docx`.

## If Pandoc Is Missing

The script exits with install instructions. Prefer installing pandoc over Python alternatives:

- macOS: `brew install pandoc`
- Ubuntu/Debian: `sudo apt install pandoc`
- Windows: `winget install --id JohnMacFarlane.Pandoc`

Only if pandoc cannot be installed, fall back to `pypandoc` or `markdown` + `python-docx` and note that table/formatting fidelity may be lower.

## Formatting Notes

Pandoc preserves common markdown elements well: headings, bold/italic, lists, tables, horizontal rules, and links.

- Tables in lesson plans and similar docs convert cleanly with default settings.
- For branded output (fonts, margins, heading styles), provide a `--reference-doc` `.docx` the user supplies.
- Images: relative paths in markdown resolve from the source file's directory.

## Examples

**User:** "Convert my trigonometry lesson plan to Word."

```bash
.cursor/skills/markdown-to-docx/scripts/convert.sh lesson_plans/lesson_plan_trigonometry.md
```

Output: `lesson_plans/lesson_plan_trigonometry.docx`

**User:** "Export all lesson plans in lesson_plans/ to docx."

```bash
.cursor/skills/markdown-to-docx/scripts/convert.sh lesson_plans/*.md
```

**User:** "Save it as Trigonometry_Lesson.docx on my Desktop."

```bash
.cursor/skills/markdown-to-docx/scripts/convert.sh lesson_plans/lesson_plan_trigonometry.md -o ~/Desktop/Trigonometry_Lesson.docx
```
