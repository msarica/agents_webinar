#!/usr/bin/env bash
# Combine a still image and audio file into an MP4 video via ffmpeg.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

IMAGE=""
AUDIO=""
OUTPUT=""
WIDTH=""
HEIGHT=""
FIT="contain"
FPS=30
VIDEO_CODEC="libx264"
AUDIO_BITRATE="192k"
CRF=23

usage() {
  cat <<'EOF'
Usage: create-video.sh --image PATH --audio PATH -o PATH [options]

Combine a still image and audio file into an MP4 video.

Required:
  --image PATH            Input image (.png, .jpg, .webp, etc.)
  --audio PATH            Input audio (.mp3, .wav, .m4a, etc.)
  -o, --output PATH       Output video file (.mp4 recommended)

Options:
  --width N               Output width (default: image width, even-rounded)
  --height N              Output height (default: image height, even-rounded)
  --fit MODE              contain (letterbox) or cover (crop to fill) (default: contain)
  --fps N                 Video frame rate (default: 30)
  --crf N                 H.264 quality 0-51, lower is better (default: 23)
  --audio-bitrate RATE    AAC bitrate (default: 192k)
  --check                 Verify ffmpeg is available, then exit

Environment:
  FFMPEG                  Override ffmpeg binary (default: ffmpeg)
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

even() {
  local n="$1"
  if (( n % 2 != 0 )); then
    echo $((n - 1))
  else
    echo "$n"
  fi
}

probe_image_size() {
  local path="$1"
  local w h

  if command -v ffprobe >/dev/null 2>&1; then
    w=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$path" 2>/dev/null || true)
    h=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$path" 2>/dev/null || true)
  fi

  if [[ -z "$w" || -z "$h" ]]; then
    if command -v sips >/dev/null 2>&1; then
      w=$(sips -g pixelWidth "$path" 2>/dev/null | awk '/pixelWidth/ {print $2}')
      h=$(sips -g pixelHeight "$path" 2>/dev/null | awk '/pixelHeight/ {print $2}')
    fi
  fi

  [[ -n "$w" && -n "$h" ]] || die "Could not read image dimensions for: $path"
  echo "$w $h"
}

probe_duration() {
  local path="$1"
  local duration

  if command -v ffprobe >/dev/null 2>&1; then
    duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$path" 2>/dev/null || true)
  fi

  [[ -n "$duration" ]] || die "Could not read audio duration for: $path"
  printf "%.1f" "$duration"
}

build_vf() {
  local w="$1"
  local h="$2"
  local fit="$3"

  w=$(even "$w")
  h=$(even "$h")

  if [[ "$fit" == "cover" ]]; then
    echo "scale=${w}:${h}:force_original_aspect_ratio=increase,crop=${w}:${h}"
  else
    echo "scale=${w}:${h}:force_original_aspect_ratio=decrease,pad=${w}:${h}:(ow-iw)/2:(oh-ih)/2:black"
  fi
}

FFMPEG_BIN="${FFMPEG:-ffmpeg}"
CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE="${2:-}"; shift 2 ;;
    --audio) AUDIO="${2:-}"; shift 2 ;;
    -o|--output) OUTPUT="${2:-}"; shift 2 ;;
    --width) WIDTH="${2:-}"; shift 2 ;;
    --height) HEIGHT="${2:-}"; shift 2 ;;
    --fit) FIT="${2:-}"; shift 2 ;;
    --fps) FPS="${2:-}"; shift 2 ;;
    --crf) CRF="${2:-}"; shift 2 ;;
    --audio-bitrate) AUDIO_BITRATE="${2:-}"; shift 2 ;;
    --check) CHECK_ONLY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1 (use --help)" ;;
  esac
done

require_cmd "$FFMPEG_BIN"

if $CHECK_ONLY; then
  echo "OK: ffmpeg is available ($("$FFMPEG_BIN" -version | head -n1))."
  exit 0
fi

[[ -n "$IMAGE" ]] || die "--image is required"
[[ -n "$AUDIO" ]] || die "--audio is required"
[[ -n "$OUTPUT" ]] || die "-o/--output is required"
[[ -f "$IMAGE" ]] || die "Image not found: $IMAGE"
[[ -f "$AUDIO" ]] || die "Audio not found: $AUDIO"
[[ "$FIT" == "contain" || "$FIT" == "cover" ]] || die "--fit must be contain or cover"

read -r IMG_W IMG_H < <(probe_image_size "$IMAGE")

if [[ -z "$WIDTH" ]]; then
  WIDTH="$IMG_W"
fi
if [[ -z "$HEIGHT" ]]; then
  HEIGHT="$IMG_H"
fi

WIDTH=$(even "$WIDTH")
HEIGHT=$(even "$HEIGHT")

VF=$(build_vf "$WIDTH" "$HEIGHT" "$FIT")
DURATION=$(probe_duration "$AUDIO")

mkdir -p "$(dirname "$OUTPUT")"

"$FFMPEG_BIN" -hide_banner -loglevel error -y \
  -loop 1 -framerate "$FPS" -i "$IMAGE" \
  -i "$AUDIO" \
  -vf "$VF" \
  -c:v "$VIDEO_CODEC" -tune stillimage -crf "$CRF" -pix_fmt yuv420p \
  -c:a aac -b:a "$AUDIO_BITRATE" \
  -movflags +faststart \
  -shortest \
  "$OUTPUT"

echo "Saved: $OUTPUT"
echo "Duration: ${DURATION}s"
echo "Resolution: ${WIDTH}x${HEIGHT}"
echo "Done."
