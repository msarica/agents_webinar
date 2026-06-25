---
name: create-video
description: >-
  Combines a still image and audio file into an MP4 video using ffmpeg. Use
  when the user asks to create, generate, or produce a video from an image and
  mp3, make a music video, slideshow clip, or turn song artwork into video.
---

# Create Video (Image + Audio)

Combines a **still image** and **audio file** into an **MP4 video** using local **ffmpeg**. Typical inputs: artwork from [generate-image](../generate-image/SKILL.md) and audio from [create-song](../create-song/SKILL.md).

## Prerequisites

1. `ffmpeg` installed and on `PATH` (`brew install ffmpeg` on macOS).
2. Input image (`.png`, `.jpg`, `.webp`, …) and audio (`.mp3`, `.wav`, `.m4a`, …).

## Quick Start

```bash
# Verify ffmpeg
.cursor/skills/create-video/scripts/create-video.sh --check

# Image + song → video
.cursor/skills/create-video/scripts/create-video.sh \
  --image images/2026-06-24_esekten-barisa-mektup.png \
  --audio songs/2026-06-24_esekten-barisa-mektup.mp3 \
  -o videos/2026-06-24_esekten-barisa-mektup.mp4
```

## Workflow

```
Task Progress:
- [ ] Step 1: Verify ffmpeg is available
- [ ] Step 2: Confirm image and audio paths exist
- [ ] Step 3: Choose resolution and fit mode (if needed)
- [ ] Step 4: Run create-video.sh
- [ ] Step 5: Save output and report to user
```

### Step 1: Verify ffmpeg

Run `--check`. If it fails, tell the user to install ffmpeg before retrying.

### Step 2: Gather inputs

| Source | Typical path |
|--------|--------------|
| Image | `images/YYYY-MM-DD_<slug>.png` |
| Audio | `songs/YYYY-MM-DD_<slug>.mp3` |

If the user has one but not the other, use the sibling skills first ([generate-image](../generate-image/SKILL.md), [create-song](../create-song/SKILL.md)).

### Step 3: Choose options

| User intent | Options |
|-------------|---------|
| Default (match image size) | Omit `--width` / `--height` |
| YouTube / widescreen | `--width 1920 --height 1080` |
| Instagram square | `--width 1080 --height 1080` |
| Fill frame, crop edges | `--fit cover` |
| Letterbox, keep full image | `--fit contain` (default) |
| Smaller file | `--crf 28` |
| Higher quality | `--crf 18` |

Video length always matches the audio (`-shortest`).

### Step 4: Generate

Prefer the script over hand-written ffmpeg. It probes dimensions, rounds to even sizes, and sets codecs.

```bash
.cursor/skills/create-video/scripts/create-video.sh \
  --image images/YYYY-MM-DD_<slug>.png \
  --audio songs/YYYY-MM-DD_<slug>.mp3 \
  --width 1920 --height 1080 \
  --fit contain \
  -o videos/YYYY-MM-DD_<slug>.mp4
```

### Step 5: Deliver

- Save to `videos/YYYY-MM-DD_<slug>.mp4`.
- Report: output path, duration, and resolution.
- If the user needs only a preview, mention they can open the MP4 directly.

## Script Options

```bash
.cursor/skills/create-video/scripts/create-video.sh [options]

Required:
  --image PATH            Input image
  --audio PATH            Input audio
  -o, --output PATH       Output video (.mp4)

Options:
  --width N               Output width (default: source image width)
  --height N              Output height (default: source image height)
  --fit MODE              contain or cover (default: contain)
  --fps N                 Frame rate (default: 30)
  --crf N                 H.264 quality, 0–51 (default: 23)
  --audio-bitrate RATE    AAC bitrate (default: 192k)
  --check                 Verify ffmpeg, then exit
```

Environment: `FFMPEG` (optional binary override).

## Error Handling

| Symptom | Action |
|---------|--------|
| `ffmpeg` not found | User installs ffmpeg (`brew install ffmpeg`) |
| Image/audio not found | Verify paths; generate missing assets first |
| Odd dimensions / codec error | Script auto-rounds; try explicit `--width` / `--height` |
| Huge output file | Increase `--crf` (e.g. 28) or lower resolution |

## Examples

**User:** "Turn my song and cover art into a video."

```bash
.cursor/skills/create-video/scripts/create-video.sh \
  --image images/2026-06-24_summer-drive.png \
  --audio songs/2026-06-24_summer-drive.mp3 \
  -o videos/2026-06-24_summer-drive.mp4
```

**User:** "Make a 1080p YouTube version with the image filling the frame."

```bash
.cursor/skills/create-video/scripts/create-video.sh \
  --image images/2026-06-24_coding-blog-hero.png \
  --audio songs/2026-06-24_coding-blog-hero.mp3 \
  --width 1920 --height 1080 \
  --fit cover \
  -o videos/2026-06-24_coding-blog-hero.mp4
```

**User:** "Create image, song, and video end to end."

1. [generate-image](../generate-image/SKILL.md) → `images/...`
2. [create-song](../create-song/SKILL.md) → `songs/...`
3. `create-video.sh` with those paths → `videos/...`

## Additional Resources

- ffmpeg filter and codec notes: [reference.md](reference.md)
