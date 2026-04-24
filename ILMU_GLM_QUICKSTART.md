# ilmu.ai GLM Quickstart for Coding Agents

## 1. API Connection Details

| Parameter | Value |
|---|---|
| Base URL | `https://api.ilmu.ai/v1/chat/completions` |
| Model | `ilmu-glm-5.1` |
| Auth Header | `Authorization: Bearer sk-b70de109e864f7075c9434e00d8f7915abaf26c005afeb85` |
| Content-Type | `application/json` |
| Timeout | 15 seconds (minimum — model is slow) |
| Temperature | 0.7 |
| Response Format | `{"type": "json_object"}` (forces JSON output) |

## 2. Payload Structure (OpenAI-Compatible)

```json
{
  "model": "ilmu-glm-5.1",
  "messages": [
    {"role": "system", "content": "You are a helpful assistant. Respond with valid JSON only."},
    {"role": "user", "content": "Your prompt here"}
  ],
  "temperature": 0.7,
  "response_format": {"type": "json_object"}
}
```

## 3. Critical Gotchas (MUST HANDLE)

### Gotcha #1: Model Name
The model is **`ilmu-glm-5.1`**, NOT `glm-4`, NOT `ilmu-1`. Using the wrong name returns `404 model_not_found`.

### Gotcha #2: Markdown Code Fences
Even with `response_format: json_object`, the model wraps JSON in markdown fences:
```
```json
{"action": "refund", "reason": "...", "confidence": 0.95}
```
```
You MUST strip these before parsing. Regex pattern:
```python
content = re.sub(r"^```(?:json)?\s*\n?", "", content.strip())
content = re.sub(r"\n?```\s*$", "", content.strip())
```

### Gotcha #3: Timeout
The model routinely takes 5–12 seconds to respond. If you set timeout < 15s, expect frequent timeouts. Always implement a fallback on timeout.

## 4. Python Working Example (Copy-Paste Ready)

```python
"""Minimal ilmu.ai GLM client — copy this file and run it."""
import json
import os
import re
import httpx

ILMU_API_URL = "https://api.ilmu.ai/v1/chat/completions"
ILMU_API_KEY = "sk-b70de109e864f7075c9434e00d8f7915abaf26c005afeb85"
ILMU_TIMEOUT = 15


def call_ilmu_glm(system_prompt: str, user_prompt: str) -> dict:
    """Call ilmu-glm-5.1 and return parsed JSON dict. Falls back to empty dict on failure."""
    payload = {
        "model": "ilmu-glm-5.1",
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": 0.7,
        "response_format": {"type": "json_object"},
    }
    headers = {
        "Authorization": f"Bearer {ILMU_API_KEY}",
        "Content-Type": "application/json",
    }
    try:
        with httpx.Client(timeout=ILMU_TIMEOUT) as client:
            response = client.post(ILMU_API_URL, headers=headers, json=payload)
            response.raise_for_status()
            content = response.json()["choices"][0]["message"]["content"]
            # Strip markdown code fences (Gotcha #2)
            content = re.sub(r"^```(?:json)?\s*\n?", "", content.strip())
            content = re.sub(r"\n?```\s*$", "", content.strip())
            return json.loads(content)
    except Exception as e:
        print(f"[ilmu GLM] call failed: {e}")
        return {}


if __name__ == "__main__":
    result = call_ilmu_glm(
        system_prompt="You are a helpful assistant. Respond with valid JSON only.",
        user_prompt='Decide: {"action": "refund", "reason": "high match", "confidence": 0.95}',
    )
    print(json.dumps(result, indent=2))
```

## 5. Async Version (for FastAPI / async frameworks)

```python
import json
import re
import httpx

ILMU_API_URL = "https://api.ilmu.ai/v1/chat/completions"
ILMU_API_KEY = "sk-b70de109e864f7075c9434e00d8f7915abaf26c005afeb85"
ILMU_TIMEOUT = 15


async def call_ilmu_glm(system_prompt: str, user_prompt: str) -> dict:
    payload = {
        "model": "ilmu-glm-5.1",
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": 0.7,
        "response_format": {"type": "json_object"},
    }
    headers = {
        "Authorization": f"Bearer {ILMU_API_KEY}",
        "Content-Type": "application/json",
    }
    try:
        async with httpx.AsyncClient(timeout=ILMU_TIMEOUT) as client:
            response = await client.post(ILMU_API_URL, headers=headers, json=payload)
            response.raise_for_status()
            content = response.json()["choices"][0]["message"]["content"]
            content = re.sub(r"^```(?:json)?\s*\n?", "", content.strip())
            content = re.sub(r"\n?```\s*$", "", content.strip())
            return json.loads(content)
    except Exception as e:
        print(f"[ilmu GLM] call failed: {e}")
        return {}
```

## 6. curl Test (Verify Connection)

```bash
curl -s -X POST https://api.ilmu.ai/v1/chat/completions \
  -H "Authorization: Bearer sk-b70de109e864f7075c9434e00d8f7915abaf26c005afeb85" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "ilmu-glm-5.1",
    "messages": [
      {"role": "system", "content": "Respond with valid JSON only."},
      {"role": "user", "content": "Say hello as JSON: {\"greeting\": \"hello\"}"}
    ],
    "temperature": 0.7,
    "response_format": {"type": "json_object"}
  }'
```

Expected response (status 200):
```json
{
  "id": "...",
  "object": "chat.completion",
  "choices": [{
    "message": {
      "content": "```json\n{\"greeting\": \"hello\"}\n```"
    }
  }]
}
```

## 7. Response Format Reference

```json
{
  "id": "string",
  "object": "chat.completion",
  "created": 1777025072,
  "model": "ilmu-glm-5.1",
  "choices": [{
    "index": 0,
    "message": {
      "role": "assistant",
      "content": "<your JSON here, possibly wrapped in markdown fences>"
    },
    "finish_reason": "stop"
  }],
  "usage": {
    "prompt_tokens": 36,
    "completion_tokens": 265,
    "total_tokens": 301
  }
}
```

## 8. Dependencies

```
pip install httpx
```

No other packages needed. The API is OpenAI-compatible — if you already use the `openai` SDK, point it at `https://api.ilmu.ai/v1` with the Bearer key.