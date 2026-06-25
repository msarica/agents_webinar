---
name: create-song-pipeline
description: >-
  Full song pipeline — 3 lyrics drafts, pick best, confirm, generate audio +
  cover, video, optional YouTube upload to output/<song>/
argument-hint: >-
  [optional: theme, title, genre, language, mood — e.g. 'Turkish folk rock
  letter from a donkey to Barış, playful nostalgic']
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
Run the end-to-end song production pipeline from user-provided information through lyrics, audio, cover art, video, and optional YouTube upload.

All final artifacts go under `output/<song-slug>/`:

```
output/YYYY-MM-DD_<title-slug>/
├── cover.png
├── lyrics.txt
├── YYYY-MM-DD_<title-slug>.mp3
└── YYYY-MM-DD_<title-slug>.mp4
```

There are **two mandatory user checkpoints**: (1) after lyrics are chosen, before any generation; (2) before YouTube upload.
</objective>

<skills>
Follow these project skills exactly:

- **create-song-pipeline** — `.cursor/skills/create-song-pipeline/SKILL.md` (orchestration, output layout, checkpoints)
- **generate-song-lyrics** — `.cursor/skills/generate-song-lyrics/SKILL.md` (ACE-Step lyrics format, quality checklist)
- **create-song** — `.cursor/skills/create-song/SKILL.md` (ACE-Step audio via `create-song.sh`)
- **generate-image** — `.cursor/skills/generate-image/SKILL.md` (cover via `generate-image.sh`)
- **create-video** — `.cursor/skills/create-video/SKILL.md` (MP4 via `create-video.sh`)
- **youtube-uploader** — `.agents/skills/youtube-uploader/SKILL.md` (upload only after user confirms)
</skills>

<required_inputs>
Collect before drafting lyrics. Ask only for what is still missing.

| Field | Required | Notes |
|-------|----------|-------|
| Theme / story | Yes | What the song is about |
| Mood / genre / style | Yes | Drives caption and cover prompt |
| Language | Yes | Vocal language code (`tr`, `en`, …) |
| Title | No | Infer from theme; used in slug |
| Vocal type | No | male, female, duet, instrumental |
| Duration | No | Omit unless user specifies — do not default to 180s |
| Constraints | No | Content limits, rhyme, reference artist |
| YouTube privacy | No | Default `unlisted` when proposing upload |
</required_inputs>

<process>

**Step 1: Parse arguments and conversation**

If the user invoked the command with text (e.g. `/create-song-pipeline Turkish folk rock donkey letter to Barış`), extract inferable fields.

Combine with details already in the conversation. Do not re-ask for information already provided.

**Step 2: Ask for missing essentials**

Use `AskUserQuestion` when required fields are missing. Do not proceed until **theme**, **mood/genre/style**, and **language** are known.

**Step 3: Set up output directory**

```bash
DATE=$(date +%Y-%m-%d)
SLUG="${DATE}_<title-slug>"
OUT_DIR="output/${SLUG}"
mkdir -p "${OUT_DIR}/drafts"
```

**Step 4: Draft 3 lyrics variants**

Follow `.cursor/skills/generate-song-lyrics/SKILL.md`. Write three **distinct** variants to:

- `${OUT_DIR}/drafts/lyrics-v1.md`
- `${OUT_DIR}/drafts/lyrics-v2.md`
- `${OUT_DIR}/drafts/lyrics-v3.md`

**Step 5: Pick the best variant**

Score all three internally (alignment, singability, chorus strength, cliché avoidance, theme fit). Select the winner. Run the generate-song-lyrics quality checklist; fix issues before presenting.

**Step 6: CHECKPOINT — lyrics confirmation**

**STOP. Do not generate audio, images, or video yet.**

Present to the user:

1. Why the chosen variant won (brief)
2. Quality issues found and how they were fixed
3. Full caption + lyrics of the winner
4. Option to approve, request edits, or switch to v1/v2/v3

Use `AskUserQuestion` or wait for explicit approval.

On approval:

- Write `${OUT_DIR}/lyrics.txt` (plain text: title, CAPTION, LYRICS)
- Write `${OUT_DIR}/drafts/lyrics-final.md` (markdown for `--lyrics-file`)

**Step 7: Parallel generation — audio + cover**

Only after lyrics confirmation. From project root, run both in parallel:

```bash
.cursor/skills/create-song/scripts/create-song.sh \
  --lyrics-file "${OUT_DIR}/drafts/lyrics-final.md" \
  --vocal-language <code> \
  --thinking \
  -o "${OUT_DIR}/${SLUG}.mp3" &
# Add --duration <seconds> only if the user requested a specific length

SONG_PID=$!

.cursor/skills/generate-image/scripts/generate-image.sh \
  --prompt "<album cover from caption + theme, square, no watermark>" \
  --size 1024x1024 \
  --quality high \
  -o "${OUT_DIR}/cover.png" &

IMG_PID=$!

wait $SONG_PID $IMG_PID
```

Verify `${OUT_DIR}/${SLUG}.mp3` and `${OUT_DIR}/cover.png` exist.

**Step 8: Create video**

```bash
.cursor/skills/create-video/scripts/create-video.sh \
  --image "${OUT_DIR}/cover.png" \
  --audio "${OUT_DIR}/${SLUG}.mp3" \
  --width 1920 --height 1080 \
  --fit contain \
  -o "${OUT_DIR}/${SLUG}.mp4"
```

**Step 9: CHECKPOINT — YouTube upload**

**STOP. Do not upload without explicit user approval.**

Present all output paths and proposed YouTube metadata (title, description, tags, category 10 Music, thumbnail = cover.png, privacy).

Ask: upload now, change metadata, or skip.

**Step 10: Upload (only if user confirms)**

```bash
cd .agents/skills/youtube-uploader/scripts
npx ts-node youtube-upload.ts \
  --video "<absolute-path>/${OUT_DIR}/${SLUG}.mp4" \
  --title "..." \
  --description "..." \
  --tags "..." \
  --category 10 \
  --thumbnail "<absolute-path>/${OUT_DIR}/cover.png" \
  --privacy <public|unlisted|private>
```

Report video URL on success.

**Step 11: Final report**

```
Song pipeline complete:

output/<song-slug>/
├── cover.png
├── lyrics.txt
├── <song-slug>.mp3
└── <song-slug>.mp4

[YouTube URL if uploaded]
```

</process>

<anti_patterns>
- Do not skip the lyrics checkpoint — never generate audio before user confirms lyrics
- Do not upload to YouTube without a second explicit confirmation
- Do not save final assets outside `output/<song-slug>/`
- Do not write only one lyrics draft — always produce three variants first
- Do not run audio and image sequentially when both can run in parallel
- Do not guess required fields silently — ask the user
</anti_patterns>

<success_criteria>
- [ ] Required inputs collected
- [ ] Three lyrics drafts written under `output/<song-slug>/drafts/`
- [ ] Best variant selected, quality-checked, and approved by user
- [ ] `lyrics.txt` and `drafts/lyrics-final.md` written after approval
- [ ] MP3 and cover.png generated in parallel
- [ ] MP4 created from cover + audio
- [ ] User explicitly confirmed or declined YouTube upload
- [ ] All four final files present under `output/<song-slug>/`
</success_criteria>
