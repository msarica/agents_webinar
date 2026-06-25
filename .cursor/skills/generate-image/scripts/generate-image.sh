#!/usr/bin/env bash
# Generate images via OpenAI Images API (DALL-E / gpt-image).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.env"
  set +a
fi

API_KEY="${OPENAI_API_KEY:-}"
API_URL="${OPENAI_API_URL:-https://api.openai.com/v1/images/generations}"

PROMPT=""
OUTPUT=""
MODEL="gpt-image-2"
SIZE="1024x1024"
QUALITY="medium"
STYLE="vivid"
N=1
OUTPUT_FORMAT="png"

usage() {
  cat <<'EOF'
Usage: generate-image.sh --prompt TEXT -o PATH [options]

Generate an image via the OpenAI Images API.

Required:
  --prompt TEXT           Image description
  -o, --output PATH       Output image file (.png recommended)

Options:
  --model NAME            gpt-image-2, gpt-image-1, dall-e-3, dall-e-2 (default: gpt-image-2)
  --size SIZE             e.g. 1024x1024, 1792x1024, 1024x1792
  --quality QUALITY       low, medium, or high (gpt-image); standard or hd (dall-e-3)
  --style STYLE           vivid or natural (dall-e-3 only)
  --output-format FMT     png, jpeg, or webp (gpt-image; default: png)
  --n N                   Number of images (default: 1)
  --check                 Verify OPENAI_API_KEY is set, then exit

Environment:
  OPENAI_API_KEY          Required (set in project .env)
  OPENAI_API_URL          Override API endpoint (optional)
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g' | cut -c1-48
}

CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt) PROMPT="${2:-}"; shift 2 ;;
    -o|--output) OUTPUT="${2:-}"; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --size) SIZE="${2:-}"; shift 2 ;;
    --quality) QUALITY="${2:-}"; shift 2 ;;
    --style) STYLE="${2:-}"; shift 2 ;;
    --output-format) OUTPUT_FORMAT="${2:-}"; shift 2 ;;
    --n) N="${2:-}"; shift 2 ;;
    --check) CHECK_ONLY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1 (use --help)" ;;
  esac
done

require_cmd curl
require_cmd jq

if [[ -z "$API_KEY" ]]; then
  die "OPENAI_API_KEY is not set. Add it to $ROOT_DIR/.env"
fi

if $CHECK_ONLY; then
  echo "OK: OPENAI_API_KEY is configured."
  exit 0
fi

[[ -n "$PROMPT" ]] || die "--prompt is required"
[[ -n "$OUTPUT" ]] || die "-o/--output is required"

mkdir -p "$(dirname "$OUTPUT")"

payload=$(jq -n \
  --arg model "$MODEL" \
  --arg prompt "$PROMPT" \
  --arg size "$SIZE" \
  --arg quality "$QUALITY" \
  --arg style "$STYLE" \
  --arg output_format "$OUTPUT_FORMAT" \
  --argjson n "$N" \
  '
  if ($model | startswith("gpt-image")) then
    {
      model: $model,
      prompt: $prompt,
      n: $n,
      size: $size,
      quality: $quality,
      output_format: $output_format
    }
  elif $model == "dall-e-3" then
    {
      model: $model,
      prompt: $prompt,
      n: $n,
      size: $size,
      quality: $quality,
      style: $style,
      response_format: "url"
    }
  else
    {
      model: $model,
      prompt: $prompt,
      n: $n,
      size: $size,
      response_format: "url"
    }
  end
  ')

response=$(curl -sS -w "\n%{http_code}" "$API_URL" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$payload")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [[ "$http_code" != "200" ]]; then
  message=$(echo "$body" | jq -r '.error.message // .message // "Unknown API error"' 2>/dev/null || echo "$body")
  die "OpenAI API error ($http_code): $message"
fi

count=$(echo "$body" | jq '.data | length')
[[ "$count" -ge 1 ]] || die "API returned no image data"

if [[ "$count" -eq 1 ]]; then
  paths=("$OUTPUT")
else
  base="${OUTPUT%.*}"
  ext="${OUTPUT##*.}"
  [[ "$ext" == "$OUTPUT" ]] && ext="png"
  paths=()
  for ((i = 0; i < count; i++)); do
    paths+=("${base}-$((i + 1)).${ext}")
  done
fi

for ((i = 0; i < count; i++)); do
  out="${paths[$i]}"
  url=$(echo "$body" | jq -r ".data[$i].url // empty")
  b64=$(echo "$body" | jq -r ".data[$i].b64_json // empty")

  if [[ -n "$url" && "$url" != "null" ]]; then
    curl -sS -L "$url" -o "$out"
  elif [[ -n "$b64" && "$b64" != "null" ]]; then
    echo "$b64" | base64 --decode > "$out"
  else
    die "No url or b64_json in response for image $((i + 1))"
  fi

  revised=$(echo "$body" | jq -r ".data[$i].revised_prompt // empty")
  echo "Saved: $out"
  if [[ -n "$revised" && "$revised" != "null" ]]; then
    echo "Revised prompt: $revised"
  fi
done

echo "Done."
