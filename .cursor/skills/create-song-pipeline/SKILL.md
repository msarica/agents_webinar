---
name: create-song-pipeline
description: >-
  End-to-end song production: draft 3 lyrics variants, pick the best, confirm
  with user, generate audio and cover art in parallel, create video, and
  optionally upload to YouTube. Use when the user asks to generate a full song
  project, music video, or run the song pipeline from lyrics to YouTube.
---

# Create Song Pipeline

Orchestrates lyrics → confirmation → audio + cover (parallel) → video → YouTube confirmation.

## Output layout

All artifacts for one song live under `output/<song-slug>/`:

```
output/YYYY-MM-DD_<title-slug>/
├── cover.png
├── lyrics.txt
├── YYYY-MM-DD_<title-slug>.mp3
└── YYYY-MM-DD_<title-slug>.mp4
```

`<song-slug>` = `YYYY-MM-DD_<title-slug>` (date defaults to today).

During drafting, optional scratch files may live in `output/<song-slug>/drafts/` (lyrics-v1.md, lyrics-v2.md, lyrics-v3.md). Delete drafts after the user confirms the final lyrics, or keep them if the user wants history.

Add `output/` to `.gitignore` if not already present.

## Prerequisites

| Step | Skill / tool |
|------|----------------|
| Lyrics | [generate-song-lyrics](../generate-song-lyrics/SKILL.md) |
| Audio | [create-song](../create-song/SKILL.md) — ACE-Step on `localhost:8001` |
| Cover | [generate-image](../generate-image/SKILL.md) — `OPENAI_API_KEY` in `.env` |
| Video | [create-video](../create-video/SKILL.md) — `ffmpeg` on PATH |
| Upload | [youtube-uploader](../../../.agents/skills/youtube-uploader/SKILL.md) |

## Workflow checklist

```
- [ ] Phase 1: Gather inputs
- [ ] Phase 2: Draft 3 lyrics variants
- [ ] Phase 3: Pick best + quality check
- [ ] Phase 4: CHECKPOINT — confirm lyrics with user
- [ ] Phase 5: Parallel — generate MP3 + cover.png
- [ ] Phase 6: Create MP4
- [ ] Phase 7: CHECKPOINT — confirm YouTube upload
- [ ] Phase 8: Upload (only if user approves)
```

---

## Phase 1: Gather inputs

Collect from the user or infer from the command invocation. Ask only for missing essentials:

| Field | Required | Notes |
|-------|----------|-------|
| Theme / story | Yes | What the song is about |
| Title | No | Infer from theme if omitted |
| Mood / genre / style | Yes | Drives caption and image prompt |
| Language | Yes | e.g. `tr`, `en` — sets vocal language |
| Vocal type | No | male, female, duet, instrumental |
| Duration | No | Omit unless user specifies — do not default to 180s |
| Constraints | No | Explicit content, rhyme, reference vibe |
| YouTube privacy | No | Default `unlisted` until user says otherwise |

Build paths:

```bash
DATE=$(date +%Y-%m-%d)
SLUG="${DATE}_$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//' | cut -c1-50)"
OUT_DIR="output/${SLUG}"
mkdir -p "${OUT_DIR}/drafts"
```

---

## Phase 2: Draft 3 lyrics variants

Write **three distinct** lyrics sets following [generate-song-lyrics](../generate-song-lyrics/SKILL.md). Each variant must differ in at least one of:

- metaphor / narrative angle
- chorus hook or emotional peak
- structure (e.g. bridge vs. no bridge)
- energy arc

Save each draft to:

- `output/<song-slug>/drafts/lyrics-v1.md`
- `output/<song-slug>/drafts/lyrics-v2.md`
- `output/<song-slug>/drafts/lyrics-v3.md`

Use the standard markdown layout (`# Title`, `## Caption`, `## Lyrics`).

---

## Phase 3: Pick best + quality check

Score each variant (internally) on:

1. Caption ↔ lyrics alignment
2. Singability (syllables, breath, section tags)
3. Chorus distinctness and memorability
4. Avoidance of AI-flavored clichés (see generate-song-lyrics checklist)
5. Fit to user's theme and constraints

Select the winner. Run the full **Quality Checklist** from generate-song-lyrics on the chosen draft. Fix any issues before presenting to the user.

Document briefly **why** this variant won (2–4 sentences) and list any issues found and fixed.

---

## Phase 4: CHECKPOINT — confirm lyrics

**Stop and wait for user approval.** Present:

- Song title and slug / output folder
- Winning variant summary (why chosen)
- Full caption + lyrics (readable, tagged sections)
- Issues checked and resolved
- Ask: approve lyrics, request edits, or pick a different variant (v1/v2/v3)

**Do not generate audio, images, or video until the user explicitly confirms.**

On approval, write final lyrics to `output/<song-slug>/lyrics.txt`:

```text
# <Song Title>

CAPTION
<caption line(s)>

LYRICS

[Verse 1]
...
```

Also keep a markdown copy at `output/<song-slug>/drafts/lyrics-final.md` for `--lyrics-file` (same format as song_lyrics/*.md).

---

## Phase 5: Parallel — MP3 + cover

After lyrics confirmation, run **both** in parallel from the project root:

```bash
SLUG="YYYY-MM-DD_title-slug"
OUT_DIR="output/${SLUG}"

# Song (foreground or background)
.cursor/skills/create-song/scripts/create-song.sh \
  --lyrics-file "${OUT_DIR}/drafts/lyrics-final.md" \
  --vocal-language <code> \
  --thinking \
  -o "${OUT_DIR}/${SLUG}.mp3" &
# Add --duration <seconds> only if the user requested a specific length

SONG_PID=$!

# Cover art — prompt from caption + theme; no text in image unless user asked
.cursor/skills/generate-image/scripts/generate-image.sh \
  --prompt "<album cover description derived from caption and theme>" \
  --size 1024x1024 \
  --quality high \
  -o "${OUT_DIR}/cover.png" &

IMG_PID=$!

wait $SONG_PID $IMG_PID
```

Verify both files exist and are non-zero size. If one fails, report which failed; do not proceed to video until both succeed.

**Image prompt tips:** Square album art, style matches caption (genre, mood, palette), cinematic composition, no watermark, minimal or no typography.

---

## Phase 6: Create MP4

```bash
.cursor/skills/create-video/scripts/create-video.sh \
  --image "${OUT_DIR}/cover.png" \
  --audio "${OUT_DIR}/${SLUG}.mp3" \
  --width 1920 --height 1080 \
  --fit contain \
  -o "${OUT_DIR}/${SLUG}.mp4"
```

Report duration and resolution.

---

## Phase 7: CHECKPOINT — YouTube upload

**Stop and wait for user approval.** Present:

| Asset | Path |
|-------|------|
| Cover | `output/<song-slug>/cover.png` |
| Lyrics | `output/<song-slug>/lyrics.txt` |
| Audio | `output/<song-slug>/<song-slug>.mp3` |
| Video | `output/<song-slug>/<song-slug>.mp4` |

Propose YouTube metadata:

- **Title** — song title (≤100 chars)
- **Description** — short blurb + lyrics or link; hashtags if appropriate
- **Tags** — genre, language, mood keywords
- **Category** — `10` (Music) unless user prefers another
- **Thumbnail** — `cover.png`
- **Privacy** — user choice (default `unlisted`)

Ask explicitly: upload now, change metadata, or skip upload.

**Do not upload without explicit user confirmation.**

---

## Phase 8: Upload (if approved)

```bash
cd .agents/skills/youtube-uploader/scripts

npx ts-node youtube-upload.ts \
  --video "${PROJECT_ROOT}/output/${SLUG}/${SLUG}.mp4" \
  --title "<title>" \
  --description "<description>" \
  --tags "<comma-separated>" \
  --category 10 \
  --thumbnail "${PROJECT_ROOT}/output/${SLUG}/cover.png" \
  --privacy <public|unlisted|private>
```

Return video ID and `https://youtu.be/<id>` on success.

---

## Error handling

| Failure | Action |
|---------|--------|
| ACE-Step unreachable | Ask user to start `python -m acestep.api_server`; retry Phase 5 |
| OpenAI key missing | Ask user to set `OPENAI_API_KEY` in `.env` |
| ffmpeg missing | `brew install ffmpeg` |
| YouTube auth | Run `npx ts-node youtube-upload.ts --auth` in uploader scripts dir |
| User rejects lyrics | Revise or switch variant; re-run Phase 4 |
| User skips upload | End pipeline; deliver local paths only |

## Additional resources

- Lyrics rules: [generate-song-lyrics/reference.md](../generate-song-lyrics/reference.md)
- ACE-Step API: [create-song/reference.md](../create-song/reference.md)
- YouTube setup: [.agents/skills/youtube-uploader/SETUP.md](../../../.agents/skills/youtube-uploader/SETUP.md)
