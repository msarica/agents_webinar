---
name: create-song
description: >-
  Generates songs via the local ACE-Step 1.5 HTTP API — submit tasks, poll
  results, and download audio. Use when the user asks to create, generate, or
  produce a song, music track, or audio with ACE-Step, or to run their local
  ACE-Step server.
---

# Create Song (ACE-Step)

Generates audio through a **local ACE-Step API** (default `http://localhost:8001`). For lyrics-only work, use the [generate-song-lyrics](../generate-song-lyrics/SKILL.md) skill first, then generate here.

## Prerequisites

1. ACE-Step API server running locally (`python -m acestep.api_server`, default port `8001`).
2. `curl` and `jq` available in the shell.
3. Optional: `ACESTEP_API_KEY` if auth is enabled on the server.

## Quick Start

```bash
# Health check
.cursor/skills/create-song/scripts/create-song.sh --check

# Quick generation from a description
.cursor/skills/create-song/scripts/create-song.sh \
  --sample-query "upbeat indie pop, female vocal, summer road trip" \
  -o songs/2026-06-24_summer-drive.mp3

# From an existing lyrics file (song_lyrics/*.md format)
.cursor/skills/create-song/scripts/create-song.sh \
  --lyrics-file song_lyrics/2026-06-24_my-song.md \
  -o songs/2026-06-24_my-song.mp3
```

## Workflow

Copy and track progress:

```
Task Progress:
- [ ] Step 1: Verify ACE-Step is running
- [ ] Step 2: Choose generation mode
- [ ] Step 3: Prepare caption/lyrics (if needed)
- [ ] Step 4: Submit and wait for audio
- [ ] Step 5: Save output and report to user
```

### Step 1: Verify server

Run `--check` or `curl http://localhost:8001/health`. If unreachable, tell the user to start ACE-Step before retrying.

### Step 2: Choose generation mode

| User intent | Mode | Key API fields |
|-------------|------|----------------|
| Vibe/description only | **Sample query** | `sample_query`, `thinking=true` |
| Has or needs lyrics | **Caption + lyrics** | `prompt` (caption), `lyrics`, `thinking=true` |
| Existing `song_lyrics/*.md` | **Lyrics file** | `--lyrics-file` (script extracts Caption + Lyrics) |
| Remix/cover/repaint | **Audio edit** | `task_type`, `src_audio` or `reference_audio` upload |
| Enhance rough inputs | **Format** | `use_format=true` on submit, or call `/format_input` first |

Default quality settings: `thinking=true`, `inference_steps=8` (turbo), `batch_size=1` unless the user wants variants.

### Step 3: Prepare caption/lyrics

- **No lyrics yet** → run [generate-song-lyrics](../generate-song-lyrics/SKILL.md), save to `song_lyrics/YYYY-MM-DD_<slug>.md`, then pass `--lyrics-file`.
- **Caption only** → use `--sample-query` or pass `--prompt` with empty lyrics.
- **Metadata** (optional): `--duration`, `--bpm`, `--key-scale`, `--time-signature`, `--vocal-language`. Omit to let the LM auto-fill when `thinking=true`.

### Step 4: Generate

Prefer the script over hand-written curl. It handles auth, polling, parsing results, and download.

```bash
.cursor/skills/create-song/scripts/create-song.sh \
  --prompt "female vocal, piano ballad, emotional" \
  --lyrics "[Verse 1]\nFirst line\nSecond line" \
  --duration 180 \
  --vocal-language en \
  --thinking \
  -o songs/2026-06-24_ballad.mp3
```

Poll interval defaults to 3s; override with `--poll-interval` or `ACESTEP_POLL_INTERVAL`. Max wait defaults to 600s (`--max-wait`).

### Step 5: Deliver

- Save audio to `songs/YYYY-MM-DD_<title-slug>.<ext>` (default format: `mp3`).
- Report: output path, duration/BPM/key from result metadata if available, and `task_id`.
- If `batch_size > 1`, save each variant with a suffix (`-1`, `-2`, …).

## Script Options

```bash
.cursor/skills/create-song/scripts/create-song.sh [options]

Connection:
  --base-url URL          API base (default: ACESTEP_API_BASE_URL or http://localhost:8001)
  --check                 Health check only, then exit

Input (pick one primary mode):
  --sample-query TEXT     Description-driven generation
  --prompt TEXT           Caption/style (alias: --caption)
  --lyrics TEXT           Lyrics with structure tags
  --lyrics-file PATH      Parse Caption + Lyrics from markdown
  --src-audio PATH        Source audio for cover/repaint (multipart upload)
  --reference-audio PATH  Reference audio for style transfer

Metadata:
  --duration SECONDS      Target length (10–600)
  --bpm N                 Tempo (30–300)
  --key-scale TEXT        e.g. "C Major", "Am"
  --time-signature N      2, 3, 4, or 6
  --vocal-language CODE   en, zh, ja, tr, etc.

Generation:
  --thinking              Enable LM code generation (recommended)
  --no-thinking           Disable thinking (text2music only)
  --use-format            LM-enhance caption/lyrics before generation
  --model NAME            DiT model (see /v1/models)
  --inference-steps N     Default 8 for turbo
  --batch-size N          Variants to generate (max 8)
  --seed N                Fixed seed (--no-random-seed implied)
  --audio-format FORMAT   mp3, wav, flac, opus, aac (default mp3)
  --task-type TYPE        text2music, cover, repaint, lego, extract, complete

Output:
  -o, --output PATH       Output audio file path
  --poll-interval SEC     Seconds between status polls (default 3)
  --max-wait SEC          Max wait before timeout (default 600)
```

Environment variables: `ACESTEP_API_BASE_URL`, `ACESTEP_API_KEY`, `ACESTEP_POLL_INTERVAL`.

## Lyrics File Format

The script expects the same layout as [generate-song-lyrics](../generate-song-lyrics/SKILL.md):

```markdown
# Song Title

## Caption
style tags, mood, instruments...

## Lyrics

[Verse 1]
Line one
```

Caption → `prompt`; Lyrics section (tags + lines) → `lyrics`.

## Manual API Flow

Use only when the script cannot cover the case (e.g. custom training). Full parameter list: [reference.md](reference.md).

1. `POST /release_task` → `task_id`
2. `POST /query_result` with `task_id_list` until `status` is `1` (success) or `2` (failed)
3. `GET /v1/audio?path=...` using the `file` URL from the parsed result

## Error Handling

| Symptom | Action |
|---------|--------|
| Connection refused | Ask user to start `python -m acestep.api_server` |
| 401 Unauthorized | Set `ACESTEP_API_KEY` to match server config |
| 429 Queue full | Wait and retry; check `/v1/stats` |
| status `2` failed | Report error; try fewer steps, shorter duration, or `thinking=false` |
| Timeout | Increase `--max-wait`; check GPU load via `/v1/stats` |

## Examples

**User:** "Make a 2-minute lo-fi beat."

```bash
.cursor/skills/create-song/scripts/create-song.sh \
  --sample-query "lo-fi chill study beat, mellow, vinyl crackle, no vocals" \
  --duration 120 \
  --thinking \
  -o songs/2026-06-24_lofi-study.mp3
```

**User:** "Generate the song from my lyrics file."

```bash
.cursor/skills/create-song/scripts/create-song.sh \
  --lyrics-file song_lyrics/2026-06-24_esekten-barisa-mektup.md \
  --vocal-language tr \
  --duration 180 \
  --thinking \
  -o songs/2026-06-24_esekten-barisa-mektup.mp3
```

**User:** "Write lyrics and create the song."

1. Follow [generate-song-lyrics](../generate-song-lyrics/SKILL.md) → save markdown.
2. Run `create-song.sh --lyrics-file ...` as above.

## Additional Resources

- API reference (endpoints, parameters, env vars): [reference.md](reference.md)
- Lyrics authoring rules: [generate-song-lyrics/reference.md](../generate-song-lyrics/reference.md)
- Upstream docs: https://github.com/ace-step/ACE-Step-1.5/blob/main/docs/en/API.md
