# Create Video — Reference

## How it works

The script runs ffmpeg with:

- `-loop 1` on the image stream (still frame repeated)
- `-shortest` so output duration matches the audio
- `libx264` + `yuv420p` for broad player compatibility
- `aac` audio at 192k by default
- `+faststart` so web players can begin playback before full download

## Fit modes

**contain** (default): scales image to fit inside the target box, pads with black bars.

```
scale=W:H:force_original_aspect_ratio=decrease,pad=W:H:(ow-iw)/2:(oh-ih)/2:black
```

**cover**: scales image to fill the box, crops overflow.

```
scale=W:H:force_original_aspect_ratio=increase,crop=W:H
```

## Common resolutions

| Platform | Width × Height |
|----------|----------------|
| YouTube / landscape | 1920 × 1080 |
| Instagram feed (square) | 1080 × 1080 |
| Instagram Stories / Reels | 1080 × 1920 |
| Twitter/X landscape | 1280 × 720 |

H.264 requires even width and height; the script rounds down odd values.

## CRF guide

| CRF | Use case |
|-----|----------|
| 18 | High quality, larger files |
| 23 | Default balance |
| 28 | Smaller files, visible compression on gradients |

## Manual ffmpeg (escape hatch)

Only when the script cannot cover the case (e.g. Ken Burns pan/zoom):

```bash
ffmpeg -y -loop 1 -framerate 30 -i image.png -i audio.mp3 \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" \
  -c:v libx264 -tune stillimage -crf 23 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -movflags +faststart -shortest output.mp4
```

## Install ffmpeg

- macOS: `brew install ffmpeg`
- Ubuntu/Debian: `sudo apt install ffmpeg`
- Windows: https://ffmpeg.org/download.html
