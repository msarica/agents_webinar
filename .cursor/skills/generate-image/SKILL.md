---
name: generate-image
description: >-
  Generates images via the OpenAI Images API (gpt-image / DALL-E) using an API
  key from the project .env file. Use when the user asks to create, generate,
  or produce an image, illustration, icon, mockup, or artwork with ChatGPT or
  OpenAI.
---

# Generate Image (OpenAI)

Generates images through the **OpenAI Images API**. Default model is **`gpt-image-2`**. The API key is read from the project root `.env` file (`OPENAI_API_KEY`).

## Prerequisites

1. OpenAI API key in `.env` at the project root.
2. `curl` and `jq` available in the shell.

## Setup

If `.env` does not exist or the key is empty:

1. Copy the example: `cp .env.example .env`
2. Add your key from https://platform.openai.com/api-keys
3. Verify: `.cursor/skills/generate-image/scripts/generate-image.sh --check`

Never commit `.env` — it is gitignored.

## Quick Start

```bash
# Verify API key
.cursor/skills/generate-image/scripts/generate-image.sh --check

# Generate an image
.cursor/skills/generate-image/scripts/generate-image.sh \
  --prompt "Minimal flat vector app icon for a note-taking app, soft blue palette" \
  -o images/2026-06-24_note-app-icon.png
```

## Workflow

```
Task Progress:
- [ ] Step 1: Verify OPENAI_API_KEY is configured
- [ ] Step 2: Refine the prompt (if needed)
- [ ] Step 3: Choose model, size, and quality
- [ ] Step 4: Run generate-image.sh
- [ ] Step 5: Save output and show the user the file path
```

### Step 1: Verify key

Run `--check`. If it fails, tell the user to add `OPENAI_API_KEY` to `.env`.

### Step 2: Refine the prompt

Write a concrete prompt: subject, style, colors, composition, and constraints. For icons or UI mockups, specify dimensions and flat/minimal style explicitly.

### Step 3: Choose options

| User intent | Model | Notes |
|-------------|-------|-------|
| Best quality (default) | `gpt-image-2` | Returns base64 PNG; use `--quality high` for final output |
| Fast drafts | `gpt-image-2` | `--quality low` or `medium` |
| Legacy / multiple variants | `dall-e-2` | Deprecated; may not work on all accounts |

### Step 4: Generate

Prefer the script over hand-written curl. It loads `.env`, calls the API, and downloads the result.

```bash
.cursor/skills/generate-image/scripts/generate-image.sh \
  --prompt "YOUR PROMPT" \
  --model gpt-image-2 \
  --size 1024x1024 \
  --quality medium \
  -o images/YYYY-MM-DD_<slug>.png
```

### Step 5: Deliver

- Save to `images/YYYY-MM-DD_<slug>.png` (or `.webp` if the user prefers).
- Report the output path and any revised prompt returned by the API.
- If multiple images (`--n` > 1), save with `-1`, `-2` suffixes.

## Script Options

```bash
.cursor/skills/generate-image/scripts/generate-image.sh [options]

Required:
  --prompt TEXT           Image description
  -o, --output PATH       Output file path

Options:
  --model NAME            gpt-image-2, gpt-image-1, dall-e-3, dall-e-2 (default: gpt-image-2)
  --size SIZE             Image dimensions (default: 1024x1024)
  --quality QUALITY       low, medium, or high (gpt-image); standard or hd (dall-e-3)
  --style STYLE           vivid or natural (dall-e-3 only)
  --output-format FMT     png, jpeg, or webp (gpt-image; default: png)
  --n N                   Number of images (default: 1)
  --check                 Verify OPENAI_API_KEY, then exit
```

Environment: `OPENAI_API_KEY` (required), `OPENAI_API_URL` (optional override).

## Error Handling

| Symptom | Action |
|---------|--------|
| `OPENAI_API_KEY is not set` | User must add key to `.env` |
| 401 Unauthorized | Key is invalid or expired — regenerate at platform.openai.com |
| 429 Rate limit | Wait and retry, or reduce `--n` |
| Content policy rejection | Rephrase prompt; remove disallowed content |
| Billing error | User must add payment method on OpenAI account |

## Examples

**User:** "Create a hero illustration for a coding blog."

```bash
.cursor/skills/generate-image/scripts/generate-image.sh \
  --prompt "Wide hero illustration, developer at laptop, warm sunset colors, modern flat design, no text" \
  --size 1792x1024 \
  --quality hd \
  -o images/2026-06-24_coding-blog-hero.png
```

**User:** "Generate 4 logo concepts."

```bash
.cursor/skills/generate-image/scripts/generate-image.sh \
  --prompt "Abstract geometric logo mark for an AI assistant product, minimal, monochrome" \
  --model dall-e-2 \
  --n 4 \
  -o images/2026-06-24_ai-logo.png
```

## Additional Resources

- API parameters and model limits: [reference.md](reference.md)
- OpenAI docs: https://platform.openai.com/docs/guides/images
