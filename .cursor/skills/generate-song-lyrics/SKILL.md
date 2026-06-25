---
name: generate-song-lyrics
description: >-
  Generates ACE-Step 1.5–ready song lyrics with structure tags, vocal control,
  and temporal scripting for AI music generation. Use when the user asks to
  write, draft, or generate song lyrics, verse/chorus structure, or lyrics for
  ACE-Step, Suno-style tags, or AI music tools.
---

# Generate Song Lyrics

Produces lyrics formatted for **ACE-Step 1.5** — a temporal script with structure tags, not plain poem text. Caption (style/atmosphere) and lyrics must tell the same story; see workflow below.

## Workflow

1. **Gather inputs** — Collect what the user provided. Ask only for missing essentials:
   - Theme, mood, genre/style
   - Language (e.g., English, Chinese, Spanish)
   - Vocal type (male, female, duet, instrumental)
   - Song length / structure preference (e.g., verse–chorus–bridge)
   - Existing **caption** (if any) — lyrics must align with it
   - Constraints (explicit content, rhyme scheme, reference artist vibe)

2. **Draft caption companion** (if user did not provide one) — One paragraph or comma-separated tags covering style, emotion, instruments, timbre, vocal character, and production. Do not put BPM, key, or time signature in caption; those belong in metadata fields.

3. **Plan structure** — Before writing lines, outline sections: Intro → Verse(s) → Pre-Chorus (optional) → Chorus → Bridge (optional) → Final Chorus → Outro. Match energy arc to caption (e.g., "building to powerful chorus").

4. **Write lyrics** — Follow the rules and template below. Read [reference.md](reference.md) for full tag tables when needed.

5. **Self-check** — Run the quality checklist before delivering.

6. **Save output** — Write to `song_lyrics/YYYY-MM-DD_<title-slug>.md` (date = today unless specified). Include caption and lyrics in the file. If updating existing lyrics, edit that file in place.

## Core Rules

### Structure tags (meta tags)

- Every section starts with a tag on its own line: `[Verse 1]`, `[Chorus - anthemic]`, `[Bridge - whispered]`.
- Combine **one** structure label with **one** performance hint using `-`: `[Chorus - powerful]` not `[Chorus - anthemic - stacked harmonies - high energy]`.
- Separate sections with blank lines.
- For instrumental tracks, use `[Instrumental]` or instrumental structure tags only — no sung lyric text.

### Caption ↔ lyrics consistency

| Caption describes | Lyrics must match |
|-------------------|-------------------|
| Instruments | Instrumental section tags (`[Guitar Solo]`, `[Piano Interlude]`) |
| Emotion / energy | Energy tags (`[building energy]`, `[melancholic]`) |
| Vocal character | Vocal tags (`[raspy vocal]`, `[whispered]`, `[powerful belting]`) |

Resolve style conflicts in caption via **temporal evolution** ("soft strings intro → heavy metal climax"), not contradictory simultaneous styles.

### Line writing

- **6–10 syllables per line** (±1–2 within a verse). Keep parallel lines in the same position similar length.
- **UPPERCASE** for peak intensity (chorus shouts, climactic lines).
- **Parentheses** for background vocals or echoes: `We rise together (together)`.
- Vowel extension (`aliiive`) — use sparingly; effects are unstable.
- One core metaphor per song; avoid adjective stacking and mixed metaphors across sections.

### Avoid "AI-flavored" lyrics

| Red flag | Fix |
|----------|-----|
| Vague imagery piles ("neon skies, electric hearts") | One concrete image per line |
| Forced or inconsistent rhymes | Prioritize natural speech rhythm over rhyme |
| Blurred section boundaries | Hard breaks between tagged sections |
| Lines too long to sing in one breath | Shorten or split |
| Metaphor whiplash (water → fire → flying) | Stick to one metaphor family |

## Output Format

```markdown
# [Song Title]

## Caption
[Style/atmosphere description for ACE-Step — no BPM/key/time signature here]

## Lyrics

[Intro - optional hint]

[Verse 1]
Line one
Line two

[Chorus - performance hint]
Chorus line one
CHORUS PEAK LINE

[Verse 2]
...

[Bridge - optional hint]
...

[Final Chorus]
...

[Outro - optional hint]
```

Deliver the lyrics block **ready to paste** into ACE-Step's `lyrics` field (tags + text only, no markdown fences in the pasteable block when user copies).

## Quality Checklist

Before saving or presenting:

- [ ] Every section has a structure tag; tags are concise (≤2 parts joined by `-`)
- [ ] Syllable counts are consistent within each verse/chorus
- [ ] Caption and lyrics agree on instruments, energy, and vocal style
- [ ] No conflicting simultaneous styles between caption and tags
- [ ] Chorus is emotionally distinct from verses
- [ ] Instrumental sections contain no singable lyric text (unless intentional vocables)
- [ ] No adjective-stacking clichés or mixed metaphors

## Examples

**User:** "Write lyrics for a melancholic piano ballad in Chinese, female vocal, about lost love."

**Agent actions:**
1. Draft caption: `female vocal, piano ballad, emotional, intimate atmosphere, strings, building to powerful chorus`
2. Structure: Intro → V1 → Pre-Chorus → Chorus → V2 → Bridge (whispered) → Final Chorus → Outro
3. Write 5–7 syllable Chinese lines; tag `[Chorus - powerful]` for climax
4. Save to `song_lyrics/2026-06-24_lost-love-ballad.md`

**User:** "Instrumental lo-fi study beat, 2 minutes."

**Agent actions:**
1. Caption: `lo-fi, chill, mellow, vinyl crackle, soft drums, jazzy chords, relaxed groove`
2. Lyrics use only structure tags: `[Intro - ambient]` → `[Main Theme - piano]` → `[Outro - fade out]`
3. No vocal lines; mark `[Instrumental]` if using a single block

## Additional Resources

- Full tag reference and complete worked example: [reference.md](reference.md)
- ACE-Step tutorial source: https://github.com/ace-step/ACE-Step-1.5/blob/main/docs/en/Tutorial.md
