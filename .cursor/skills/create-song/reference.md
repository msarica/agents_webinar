# ACE-Step API Reference (condensed)

Source: https://github.com/ace-step/ACE-Step-1.5/blob/main/docs/en/API.md

## Base URL

Default: `http://localhost:8001` (`ACESTEP_API_HOST` + `ACESTEP_API_PORT`).

## Authentication

Optional. Set `ACESTEP_API_KEY` on server and client.

- Header: `Authorization: Bearer <key>`
- Body: `"ai_token": "<key>"`

## Response wrapper

```json
{ "data": {}, "code": 200, "error": null, "timestamp": 0, "extra": null }
```

## Task lifecycle

| status | Meaning |
|--------|---------|
| `0` | Queued or running |
| `1` | Succeeded |
| `2` | Failed |

## Endpoints

### POST /release_task

Submit generation. Content-Type: `application/json` or `multipart/form-data` (file uploads).

**Core text fields**

| Field | Notes |
|-------|-------|
| `prompt` | Caption / style (alias: `caption`) |
| `lyrics` | Structure-tagged lyrics |
| `sample_query` | Natural language description (aliases: `description`, `desc`) |
| `sample_mode` | Random sample mode |
| `use_format` | LM-enhance caption/lyrics (alias: `format`) |
| `thinking` | `true` = LM generates audio codes + fills missing metas (recommended) |
| `vocal_language` | `en`, `zh`, `ja`, `tr`, etc. |
| `audio_format` | `mp3`, `wav`, `flac`, `opus`, `aac`, `wav32` |

**Metadata** (LM auto-fills empty fields when `thinking=true`)

| Field | Aliases | Range |
|-------|---------|-------|
| `audio_duration` | `duration`, `target_duration` | 10–600 sec |
| `bpm` | — | 30–300 |
| `key_scale` | `keyscale`, `keyScale` | e.g. `"C Major"` |
| `time_signature` | `timesignature`, `timeSignature` | `2`, `3`, `4`, `6` |

**Generation control**

| Field | Default | Notes |
|-------|---------|-------|
| `model` | server default | List via `GET /v1/models` |
| `inference_steps` | 8 | Turbo: 1–20; base: 32–64 |
| `guidance_scale` | 7.0 | Base model only |
| `batch_size` | 2 | Max 8 |
| `use_random_seed` | true | |
| `seed` | -1 | When not random |

**Audio edit**

| Field | Notes |
|-------|-------|
| `task_type` | `text2music`, `cover`, `repaint`, `lego`, `extract`, `complete` |
| `src_audio_path` / `src_audio` | Source for cover/repaint |
| `reference_audio_path` / `reference_audio` | Style reference |
| `repainting_start`, `repainting_end` | Repaint window (seconds) |
| `audio_cover_strength` | 0.0–1.0 (lower = more style transfer) |

**thinking semantics**

- `thinking=false`: text2music only; ignores `audio_code_string`
- `thinking=true`: LM generates codes; best quality for new songs
- LM skipped for `cover`, `repaint`, `extract` regardless of `thinking`

**Response `data`**: `{ "task_id": "uuid", "status": "queued", "queue_position": N }`

### POST /query_result

```json
{ "task_id_list": ["uuid-1", "uuid-2"] }
```

**Response `data`**: array of `{ "task_id", "status", "result" }` where `result` is a **JSON string** to parse. Each item contains `file` (download URL path), `metas`, `prompt`, `lyrics`, `seed_value`, etc.

### GET /v1/audio?path=...

Download generated file. Path is URL-encoded.

### POST /format_input

LM-enhance caption/lyrics before generation. Fields: `prompt`, `lyrics`, `temperature`, `param_obj` (JSON string with duration/bpm/key/time_signature/language).

### POST /create_random_sample

Returns random example `{ caption, lyrics, bpm, key_scale, time_signature, duration, vocal_language }`. `sample_type`: `simple_mode` or `custom_mode`.

### GET /v1/models

List loaded DiT models and default.

### POST /v1/init

Load/switch models. Params: `model`, `slot` (1–3), `init_llm`, `lm_model_path`.

### GET /v1/stats

Queue depth, job counts, `avg_job_seconds`.

### GET /health

`{ "status": "ok", "service": "ACE-Step API" }`

## HTTP errors

| Code | Meaning |
|------|---------|
| 400 | Bad request |
| 401 | Invalid/missing API key |
| 429 | Queue full |
| 500 | Server error |

## Environment variables (server)

| Variable | Default | Purpose |
|----------|---------|---------|
| `ACESTEP_API_HOST` | 127.0.0.1 | Bind host |
| `ACESTEP_API_PORT` | 8001 | Bind port |
| `ACESTEP_API_KEY` | (empty) | Auth key |
| `ACESTEP_CONFIG_PATH` | acestep-v15-turbo | Primary model |
| `ACESTEP_INIT_LLM` | auto | LM at startup |
| `ACESTEP_OFFLOAD_TO_CPU` | false | Low VRAM mode |

## Best practices

1. Use `thinking=true` for new compositions.
2. Use `sample_query` for quick ideation from a sentence.
3. Use `use_format=true` when caption/lyrics need polish.
4. Batch-query multiple `task_id`s in one `/query_result` call.
5. Check `/v1/stats` before heavy batch jobs.
