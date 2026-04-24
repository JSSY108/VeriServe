import json
import os
import re

import httpx

GLM_API_URL = os.getenv("GLM_API_URL", "https://api.ilmu.ai/v1/chat/completions")
GLM_API_KEY = os.getenv("GLM_API_KEY", "")
GLM_TIMEOUT = 15


def _truncate_claim(text: str, max_words: int = 800) -> str:
    words = text.split()
    if len(words) > max_words:
        return " ".join(words[:max_words])
    return text


def _build_messages(claim: str, vision_json: dict) -> list[dict]:
    truncated = _truncate_claim(claim)
    return [
        {
            "role": "system",
            "content": (
                "You are a Sovereign Audit Agent for a third-party logistics verification SaaS. "
                "Your role is to audit delivery disputes by reasoning over Item Integrity — "
                "assessing whether the delivered item matches the expected condition based on: "
                "(1) Customer Photo, (2) Rider Proof-of-Delivery Photo, (3) Rider Identity. "
                "You handle claims across all industries: Food, Electronics, Apparel, and beyond. "
                "Claim types include 'Damaged' and 'Missing Item'. "
                "If the vision match confidence > 0.85 and damage is detected, choose 'refund'. "
                "Otherwise, choose 'escalate' for manual review. "
                "You MUST respond with valid JSON only: "
                '{"action": "refund"|"escalate", "reason": "...", "confidence": 0.0-1.0}'
            ),
        },
        {
            "role": "user",
            "content": f"Customer claim: {truncated}\nVision API result: {json.dumps(vision_json)}",
        },
    ]


async def call_glm(claim: str, vision_json: dict) -> dict:
    try:
        async with httpx.AsyncClient(timeout=GLM_TIMEOUT) as client:
            response = await client.post(
                GLM_API_URL,
                headers={
                    "Authorization": f"Bearer {GLM_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "ilmu-glm-5.1",
                    "messages": _build_messages(claim, vision_json),
                    "temperature": 0.7,
                    "response_format": {"type": "json_object"},
                },
            )
            response.raise_for_status()
            content = response.json()["choices"][0]["message"]["content"]
            # Strip markdown code fences if present
            content = re.sub(r"^```(?:json)?\s*\n?", "", content.strip())
            content = re.sub(r"\n?```\s*$", "", content.strip())
            return json.loads(content)
    except (httpx.TimeoutException, httpx.HTTPStatusError, KeyError, json.JSONDecodeError, Exception):
        return {"action": "escalate", "reason": "GLM call failed or timed out", "confidence": 0.0}
