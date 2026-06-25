#!/usr/bin/env bash
# Submit ACE-Step generation tasks, poll until complete, download audio.
set -euo pipefail

BASE_URL="${ACESTEP_API_BASE_URL:-http://localhost:8001}"
API_KEY="${ACESTEP_API_KEY:-}"
POLL_INTERVAL="${ACESTEP_POLL_INTERVAL:-3}"
MAX_WAIT=600

# Defaults
PROMPT=""
LYRICS=""
SAMPLE_QUERY=""
LYRICS_FILE=""
SRC_AUDIO=""
REFERENCE_AUDIO=""
DURATION=""
BPM=""
KEY_SCALE=""
TIME_SIGNATURE=""
VOCAL_LANGUAGE=""
THINKING=""
USE_FORMAT="false"
MODEL=""
INFERENCE_STEPS="8"
BATCH_SIZE="1"
SEED=""
AUDIO_FORMAT="mp3"
TASK_TYPE="text2music"
OUTPUT=""
CHECK_ONLY=false

usage() {
  cat <<'EOF'
Usage: create-song.sh [options]

Generate audio via local ACE-Step API.

Connection:
  --base-url URL          API base (default: http://localhost:8001)
  --check                 Health check only

Input:
  --sample-query TEXT     Description-driven generation
  --prompt, --caption     Style/caption text
  --lyrics TEXT           Lyrics with structure tags
  --lyrics-file PATH      Parse Caption + Lyrics from markdown
  --src-audio PATH        Source audio (cover/repaint)
  --reference-audio PATH  Reference audio (style transfer)

Metadata:
  --duration SECONDS      Target length (10-600)
  --bpm N                 Tempo (30-300)
  --key-scale TEXT        e.g. "C Major"
  --time-signature N      2, 3, 4, or 6
  --vocal-language CODE   en, zh, ja, tr, etc.

Generation:
  --thinking              Enable LM (recommended)
  --no-thinking           Disable LM
  --use-format            LM-enhance caption/lyrics
  --model NAME            DiT model name
  --inference-steps N     Default 8
  --batch-size N          Variants (max 8, default 1)
  --seed N                Fixed seed
  --audio-format FORMAT   mp3, wav, flac, etc.
  --task-type TYPE        text2music, cover, repaint, ...

Output:
  -o, --output PATH       Output audio file (required unless --check)
  --poll-interval SEC     Poll interval (default 3)
  --max-wait SEC          Max wait (default 600)

Environment: ACESTEP_API_BASE_URL, ACESTEP_API_KEY, ACESTEP_POLL_INTERVAL
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed."
}

api_curl() {
  local method="$1"
  local path="$2"
  shift 2
  local args=(-sS -X "$method" "${BASE_URL}${path}")
  if [[ -n "$API_KEY" ]]; then
    args+=(-H "Authorization: Bearer ${API_KEY}")
  fi
  args+=("$@")
  curl "${args[@]}"
}

check_health() {
  local resp
  resp="$(api_curl GET /health)" || die "Cannot reach ACE-Step at ${BASE_URL}"
  local status
  status="$(echo "$resp" | jq -r '.data.status // empty')"
  if [[ "$status" != "ok" ]]; then
    echo "$resp" | jq . >&2
    die "Health check failed"
  fi
  echo "ACE-Step OK at ${BASE_URL}"
}

extract_from_lyrics_file() {
  local file="$1"
  [[ -f "$file" ]] || die "Lyrics file not found: $file"

  local caption lyrics
  caption="$(awk '
    /^## Caption/ { cap=1; next }
    /^## / && cap { exit }
    cap { if (NF) { if (n++) printf ", "; printf "%s", $0 } }
  ' "$file")"

  lyrics="$(awk '
    /^## Lyrics/ { lyr=1; next }
    /^## / && lyr { exit }
    lyr { print }
  ' "$file")"

  lyrics="$(printf '%s\n' "$lyrics" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"

  [[ -n "$caption" ]] || die "No ## Caption section in $file"
  [[ -n "$lyrics" ]] || die "No ## Lyrics section in $file"

  PROMPT="$caption"
  LYRICS="$lyrics"
}

build_json_payload() {
  local thinking_val="true"
  if [[ "$THINKING" == "false" ]]; then
    thinking_val="false"
  fi

  local jq_args=(
    -n
    --arg prompt "$PROMPT"
    --arg lyrics "$LYRICS"
    --arg sample_query "$SAMPLE_QUERY"
    --arg vocal_language "$VOCAL_LANGUAGE"
    --arg audio_format "$AUDIO_FORMAT"
    --arg model "$MODEL"
    --arg task_type "$TASK_TYPE"
    --arg key_scale "$KEY_SCALE"
    --arg time_signature "$TIME_SIGNATURE"
    --argjson thinking "$thinking_val"
    --argjson use_format "$USE_FORMAT"
    --argjson inference_steps "$INFERENCE_STEPS"
    --argjson batch_size "$BATCH_SIZE"
  )

  local json
  json="$(jq "${jq_args[@]}" \
    '{
      prompt: $prompt,
      lyrics: $lyrics,
      sample_query: $sample_query,
      vocal_language: (if $vocal_language == "" then null else $vocal_language end),
      audio_format: $audio_format,
      thinking: $thinking,
      use_format: $use_format,
      inference_steps: $inference_steps,
      batch_size: $batch_size,
      task_type: $task_type
    }
    | if $model != "" then .model = $model else . end
    | if $key_scale != "" then .key_scale = $key_scale else . end
    | if $time_signature != "" then .time_signature = $time_signature else . end
    ')"

  if [[ -n "$DURATION" ]]; then
    json="$(echo "$json" | jq --argjson d "$DURATION" '. + {audio_duration: $d}')"
  fi
  if [[ -n "$BPM" ]]; then
    json="$(echo "$json" | jq --argjson b "$BPM" '. + {bpm: $b}')"
  fi
  if [[ -n "$SEED" ]]; then
    json="$(echo "$json" | jq --argjson s "$SEED" '. + {seed: $s, use_random_seed: false}')"
  fi
  if [[ -n "$API_KEY" ]]; then
    json="$(echo "$json" | jq --arg t "$API_KEY" '. + {ai_token: $t}')"
  fi

  echo "$json"
}

submit_task_json() {
  local payload="$1"
  local resp task_id code
  resp="$(api_curl POST /release_task \
    -H 'Content-Type: application/json' \
    -d "$payload")"
  code="$(echo "$resp" | jq -r '.code // 0')"
  if [[ "$code" != "200" ]]; then
    echo "$resp" | jq . >&2
    die "release_task failed (code=$code)"
  fi
  task_id="$(echo "$resp" | jq -r '.data.task_id // empty')"
  [[ -n "$task_id" ]] || die "No task_id in response"
  echo "$task_id"
}

submit_task_multipart() {
  local payload="$1"
  local -a form_args=(-H 'Content-Type: multipart/form-data')

  while IFS= read -r key; do
    local val
    val="$(echo "$payload" | jq -r --arg k "$key" '.[$k] // empty')"
    [[ -n "$val" && "$val" != "null" ]] && form_args+=(-F "${key}=${val}")
  done < <(echo "$payload" | jq -r 'keys[]')

  [[ -n "$SRC_AUDIO" ]] && form_args+=(-F "src_audio=@${SRC_AUDIO}")
  [[ -n "$REFERENCE_AUDIO" ]] && form_args+=(-F "reference_audio=@${REFERENCE_AUDIO}")

  local resp task_id code
  resp="$(api_curl POST /release_task "${form_args[@]}")"
  code="$(echo "$resp" | jq -r '.code // 0')"
  if [[ "$code" != "200" ]]; then
    echo "$resp" | jq . >&2
    die "release_task failed (code=$code)"
  fi
  task_id="$(echo "$resp" | jq -r '.data.task_id // empty')"
  [[ -n "$task_id" ]] || die "No task_id in response"
  echo "$task_id"
}

poll_task() {
  local task_id="$1"
  local elapsed=0
  local status

  while [[ "$elapsed" -lt "$MAX_WAIT" ]]; do
    local resp
    resp="$(api_curl POST /query_result \
      -H 'Content-Type: application/json' \
      -d "$(jq -n --arg id "$task_id" '{task_id_list: [$id]}')")"

    status="$(echo "$resp" | jq -r '.data[0].status // empty')"
    case "$status" in
      1)
        echo "$resp" | jq -r '.data[0].result'
        return 0
        ;;
      2)
        echo "$resp" | jq . >&2
        die "Task failed: $task_id"
        ;;
      0|"")
        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
        ;;
      *)
        die "Unknown status: $status"
        ;;
    esac
  done

  die "Timed out after ${MAX_WAIT}s waiting for task $task_id"
}

download_audio() {
  local file_path="$1"
  local out_path="$2"

  local url
  if [[ "$file_path" == http* ]]; then
    url="$file_path"
  elif [[ "$file_path" == /* ]]; then
    url="${BASE_URL}${file_path}"
  else
    url="${BASE_URL}/${file_path}"
  fi

  mkdir -p "$(dirname "$out_path")"
  local args=(-sS -o "$out_path")
  if [[ -n "$API_KEY" ]]; then
    args+=(-H "Authorization: Bearer ${API_KEY}")
  fi
  curl "${args[@]}" "$url"

  [[ -s "$out_path" ]] || die "Download produced empty file: $out_path"
  echo "$out_path"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url) BASE_URL="${2%/}"; shift 2 ;;
    --check) CHECK_ONLY=true; shift ;;
    --sample-query) SAMPLE_QUERY="$2"; shift 2 ;;
    --prompt|--caption) PROMPT="$2"; shift 2 ;;
    --lyrics) LYRICS="$2"; shift 2 ;;
    --lyrics-file) LYRICS_FILE="$2"; shift 2 ;;
    --src-audio) SRC_AUDIO="$2"; shift 2 ;;
    --reference-audio) REFERENCE_AUDIO="$2"; shift 2 ;;
    --duration) DURATION="$2"; shift 2 ;;
    --bpm) BPM="$2"; shift 2 ;;
    --key-scale) KEY_SCALE="$2"; shift 2 ;;
    --time-signature) TIME_SIGNATURE="$2"; shift 2 ;;
    --vocal-language) VOCAL_LANGUAGE="$2"; shift 2 ;;
    --thinking) THINKING="true"; shift ;;
    --no-thinking) THINKING="false"; shift ;;
    --use-format) USE_FORMAT="true"; shift ;;
    --model) MODEL="$2"; shift 2 ;;
    --inference-steps) INFERENCE_STEPS="$2"; shift 2 ;;
    --batch-size) BATCH_SIZE="$2"; shift 2 ;;
    --seed) SEED="$2"; shift 2 ;;
    --audio-format) AUDIO_FORMAT="$2"; shift 2 ;;
    --task-type) TASK_TYPE="$2"; shift 2 ;;
    -o|--output) OUTPUT="$2"; shift 2 ;;
    --poll-interval) POLL_INTERVAL="$2"; shift 2 ;;
    --max-wait) MAX_WAIT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1 (use --help)" ;;
  esac
done

need_cmd curl
need_cmd jq

if $CHECK_ONLY; then
  check_health
  exit 0
fi

[[ -n "$OUTPUT" ]] || die "Output path required (-o/--output)"

check_health

[[ -n "$LYRICS_FILE" ]] && extract_from_lyrics_file "$LYRICS_FILE"

if [[ -z "$SAMPLE_QUERY" && -z "$PROMPT" && -z "$LYRICS" && -z "$SRC_AUDIO" ]]; then
  die "Provide --sample-query, --prompt/--lyrics, --lyrics-file, or --src-audio"
fi

[[ -n "$SRC_AUDIO" && ! -f "$SRC_AUDIO" ]] && die "Source audio not found: $SRC_AUDIO"
[[ -n "$REFERENCE_AUDIO" && ! -f "$REFERENCE_AUDIO" ]] && die "Reference audio not found: $REFERENCE_AUDIO"

PAYLOAD="$(build_json_payload)"

echo "Submitting task..." >&2
if [[ -n "$SRC_AUDIO" || -n "$REFERENCE_AUDIO" ]]; then
  TASK_ID="$(submit_task_multipart "$PAYLOAD")"
else
  TASK_ID="$(submit_task_json "$PAYLOAD")"
fi
echo "Task ID: $TASK_ID" >&2

echo "Waiting for generation (poll every ${POLL_INTERVAL}s)..." >&2
RESULT_JSON="$(poll_task "$TASK_ID")"

# Parse result array
COUNT="$(echo "$RESULT_JSON" | jq 'length')"
[[ "$COUNT" -ge 1 ]] || die "Empty result array"

if [[ "$COUNT" -eq 1 ]]; then
  FILE_URL="$(echo "$RESULT_JSON" | jq -r '.[0].file')"
  OUT="$(download_audio "$FILE_URL" "$OUTPUT")"
  echo "$OUT"
  echo "$RESULT_JSON" | jq -r '.[0].metas // empty | "Metadata: bpm=\(.bpm // "n/a") duration=\(.duration // "n/a") key=\(.keyscale // "n/a")"' >&2
else
  OUT_BASE="${OUTPUT%.*}"
  OUT_EXT="${OUTPUT##*.}"
  idx=0
  while [[ "$idx" -lt "$COUNT" ]]; do
    FILE_URL="$(echo "$RESULT_JSON" | jq -r --argjson i "$idx" '.[$i].file')"
    VARIANT_OUT="${OUT_BASE}-$((idx + 1)).${OUT_EXT}"
    download_audio "$FILE_URL" "$VARIANT_OUT"
    idx=$((idx + 1))
  done
  echo "${OUT_BASE}-1.${OUT_EXT}"
fi
