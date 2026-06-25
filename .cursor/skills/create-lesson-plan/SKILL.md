---
name: create-lesson-plan
description: >-
  Creates structured lesson plans for K-12 and higher-ed instruction using a
  fixed template with learning objectives, standards, timed activities,
  assessment, and differentiation. Use when the user asks to create, draft, or
  write a lesson plan, unit lesson, teaching plan, or classroom activity plan.
---

# Create Lesson Plan

## Workflow

1. **Gather inputs** — Collect any details the user provided. Ask only for missing essentials:
   - Subject, grade level, topic/unit, duration
   - Teacher (defaults to **Mehmet Sarica** if not specified)
   - Standards or competencies (if known)
   - Prior knowledge assumptions
   - Special constraints (ELL, IEP accommodations, class size, tech access)

2. **Plan the lesson arc** — Before writing, align:
   - 3 measurable learning objectives (action verbs: explain, analyze, create, etc.)
   - Hook → instruction → guided practice → independent practice → closure
   - Time allocations that sum to total duration

3. **Write the plan** — Follow the template exactly. Read `lesson_plan_template.md` in the project root, or [template.md](template.md) in this skill folder. Preserve all section headings, subheadings, horizontal rules (`---`), and structure. Replace every placeholder with real content.

4. **Save output** — Write to `lesson_plans/YYYY-MM-DD_<topic-slug>.md` (date = lesson date or today). When invoked via `/create-lesson-plan`, convert to `lesson_plans/YYYY-MM-DD_<topic-slug>.docx` and delete the `.md` file after successful conversion. If updating an existing plan, edit that file in place.

## Content Quality Rules

- **Learning objectives**: Start with "By the end of the lesson, students will be able to:" and write 3 specific, measurable outcomes.
- **Standards**: List actual standard codes when provided; otherwise note the competency area clearly.
- **Timed sections**: Hook, Instruction, Guided Practice, Independent Practice, and Closure must each include `**Time:** X minutes` and times must add up to total duration.
- **Activities**: Be concrete — what the teacher does, what students do, and what materials are needed.
- **Assessment**: Formative checks during the lesson; summative measures what objectives were met.
- **Differentiation**: Provide distinct strategies for struggling, advanced, and special-needs learners — not generic advice.
- **Reflection section**: Leave blank placeholders for the teacher to complete after the lesson.
- **Notes**: Use for timing tips, common misconceptions, or safety considerations.

## Output Format

Match the template structure precisely:

```markdown
# Lesson Plan: [Topic]

## General Information
| Field | Details |
...

## Learning Objectives
...

[all remaining sections in order]
```

Do not omit sections. Do not reorder sections. Do not add extra top-level sections unless the user explicitly requests them.

## Examples

**User request:** "Create a 45-minute 7th grade science lesson on photosynthesis."

**Agent actions:**
1. Confirm or infer: no specific standards given → use NGSS-style competency language
2. Allocate time: Hook 5, Instruction 15, Guided 10, Independent 10, Closure 5
3. Write filled plan to `lesson_plan_photosynthesis.md`

**User request:** "Add differentiation for ELL students to my existing plan."

**Agent actions:**
1. Read the existing lesson plan file
2. Expand the Differentiation / Accommodations section only
3. Preserve all other content unchanged
