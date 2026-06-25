# OpenAI Images API Reference

## Endpoint

```
POST https://api.openai.com/v1/images/generations
Authorization: Bearer $OPENAI_API_KEY
Content-Type: application/json
```

## Models

| Model | Best for | Max `n` | Sizes |
|-------|----------|---------|-------|
| `dall-e-3` | Highest quality single images | 1 | 1024x1024, 1792x1024, 1024x1792 |
| `dall-e-2` | Lower cost, multiple variants | 10 | 256x256, 512x512, 1024x1024 |
| `gpt-image-1` | Latest OpenAI image model
 | Varies | See OpenAI docs |

## dall-e-3 Parameters

| Field | Values | Default |
|-------|--------|---------|
| `prompt` | Text, max ~4000 chars | required |
| `size` | 1024x1024, 1792x1024, 1024x1792 | 1024x1024 |
| `quality` | standard, hd | standard |
| `style` | vivid, natural | vivid |
| `response_format` | url, b64_json | url |

dall-e-3 may return a `revised_prompt` in the response when the model rewrites the input for safety or clarity.

## dall-e-2 Parameters

| Field | Values | Default |
|-------|--------|---------|
| `prompt` | Text | required |
| `size` | 256x256, 512x512, 1024x1024 | 1024x1024 |
| `n` | 1–10 | 1 |
| `response_format` | url, b64_json | url |

## Response Shape

```json
{
  "created": 1713833628,
  "data": [
    {
      "url": "https://...",
      "revised_prompt": "..."
    }
  ]
}
```

With `response_format: b64_json`, each item has `b64_json` instead of `url`.

## Environment

| Variable | Purpose |
|----------|---------|
| `OPENAI_API_KEY` | API authentication (stored in project `.env`) |
| `OPENAI_API_URL` | Optional endpoint override for proxies or testing |

## Related Endpoints (not covered by script)

- **Edits**: `POST /v1/images/edits` — modify an existing image with a mask
- **Variations**: `POST /v1/images/variations` — dall-e-2 only

Use manual curl or extend `generate-image.sh` if the user needs edit/variation workflows.
