---
name: create-lesson-plan
description: Create a structured lesson plan in lesson_plans/ and export it as Word (.docx)
argument-hint: "[optional: subject, grade, topic, duration — e.g. '7th grade science photosynthesis 45 min']"
tools:
  read: true
  write: true
  edit: true
  glob: true
  grep: true
  bash: true
  askuserquestion: true
---

<objective>
Create a complete K-12 or higher-ed lesson plan, save it under `lesson_plans/`, and convert it to Word format.

Output naming: `lesson_plans/YYYY-MM-DD_<topic-slug>.docx`. Markdown is written temporarily for conversion, then deleted.

If any required information is missing, ask the user before writing anything.
</objective>

<skills>
Follow these project skills exactly:

- **create-lesson-plan** — `.cursor/skills/create-lesson-plan/SKILL.md` (template, content quality, section structure)
- **markdown-to-docx** — `.cursor/skills/markdown-to-docx/SKILL.md` (pandoc conversion via `convert.sh`)
</skills>

<context>
@.cursor/skills/create-lesson-plan/template.md
</context>

<required_inputs>
Collect before writing. Ask only for what is still missing.

| Field | Required | Notes |
|-------|----------|-------|
| Subject | Yes | e.g. Mathematics, Science, ELA |
| Grade level | Yes | e.g. 7th Grade, 10th Grade |
| Topic / unit | Yes | Drives lesson title and filename slug |
| Duration | Yes | Total minutes; timed sections must sum to this |
| Date | No | Defaults to today (`YYYY-MM-DD`) |
| Teacher | No | Defaults to **Mehmet Sarica** |
| Standards / competencies | No | Use competency language if not provided |
| Prior knowledge | No | Infer reasonable assumptions if omitted |
| Special constraints | No | ELL, IEP, class size, tech access, etc. |
</required_inputs>

<process>

**Step 1: Parse arguments and conversation**

If the user invoked the command with text (e.g. `/create-lesson-plan 10th grade math trigonometry 45 min`), extract any fields you can infer.

Combine with details already stated in the conversation. Do not re-ask for information the user already provided.

**Step 2: Ask for missing essentials**

Use `AskUserQuestion` for any missing required field. Prefer one combined question when multiple fields are missing:

```
AskUserQuestion(
  header: "Lesson Plan Details",
  question: "I need a few details to create your lesson plan:",
  options: [...]  // only if offering discrete choices; otherwise use follow-up free text
)
```

If a single field is missing, ask only for that field.

**Do not proceed until Subject, Grade level, Topic, and Duration are known.**

**Step 3: Build filenames**

```bash
DATE=$(date +%Y-%m-%d)   # or user-provided date in YYYY-MM-DD form
SLUG=$(echo "$TOPIC" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//' | cut -c1-50)
mkdir -p lesson_plans
MD_PATH="lesson_plans/${DATE}_${SLUG}.md"
DOCX_PATH="lesson_plans/${DATE}_${SLUG}.docx"
```

**Step 4: Write the lesson plan**

1. Read `.cursor/skills/create-lesson-plan/template.md`
2. Follow all content quality rules in `.cursor/skills/create-lesson-plan/SKILL.md`
3. Fill every section — do not leave template placeholders
4. Set the **Date** field in General Information to the chosen date
5. Set the **Teacher** field to the provided name, or **Mehmet Sarica** if not specified
6. Write the completed plan to `$MD_PATH`

**Step 5: Convert to DOCX**

From the project root:

```bash
.cursor/skills/markdown-to-docx/scripts/convert.sh "$MD_PATH" -o "$DOCX_PATH"
```

Verify the output file exists and has non-zero size.

**Step 6: Remove the markdown source**

After successful conversion, delete the temporary markdown file:

```bash
rm "$MD_PATH"
```

Do not delete the `.md` file if conversion failed.

**Step 7: Report to user**

Confirm the Word file:

```
Lesson plan created:

- Word: lesson_plans/YYYY-MM-DD_<topic-slug>.docx

Subject: …
Grade: …
Topic: …
Duration: … minutes
Teacher: …
```

</process>

<anti_patterns>
- Do not save to the project root — always use `lesson_plans/`
- Do not use the old `lesson_plan_<topic>.md` naming convention
- Do not skip the DOCX conversion step
- Do not leave the temporary `.md` file after successful conversion
- Do not omit template sections or reorder headings
- Do not guess required fields silently — ask the user
</anti_patterns>

<success_criteria>
- [ ] All required inputs collected (asked user if missing)
- [ ] DOCX written to `lesson_plans/YYYY-MM-DD_<topic-slug>.docx`
- [ ] Temporary markdown removed after successful conversion
- [ ] Teacher field set (default: Mehmet Sarica)
- [ ] Timed sections sum to total duration
- [ ] User receives full path to the `.docx` file
</success_criteria>
