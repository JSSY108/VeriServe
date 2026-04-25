import json
import os
import re

import httpx

GLM_API_URL = os.getenv("GLM_API_URL", "https://api.ilmu.ai/v1/chat/completions")
GLM_API_KEY = os.getenv("GLM_API_KEY", "")
GLM_TIMEOUT = 45

_MULTI_AGENT_SYSTEM_PROMPT = (
    "You are a 3-Persona audit system for logistics claim verification. "
    "Produce a trace_log with 3 entries.\n\n"
    "1. [Ingestor]: Extract damage_type and intent from complaint_text. "
    "Cross-reference user_category_selection — flag mismatches as fraud.\n"
    "2. [Investigator]: You are given TWO images: the rider's proof-of-delivery (PoD) "
    "and the customer's evidence photo. Analyze BOTH images visually. "
    "Describe EXACTLY what you see — specific visual findings like "
    "'cardboard compression on left side', 'FRAGILE sticker visible via OCR', "
    "'images appear identical suggesting pre-existing damage', or "
    "'minor surface scratch not matching claim severity'. "
    "Compare the two images for structural deltas. Your confidence_score MUST equal "
    "the vision_api_result.match_confidence when damage_detected is true.\n"
    "3. [Auditor]: Check order_amount vs auto_refund_limit. Make final decision.\n\n"
    "Decision rules (apply strictly):\n"
    "- category mismatch → REJECT_FRAUD\n"
    "- vision match_confidence >= 0.85 AND damage_detected AND order_amount <= auto_refund_limit → APPROVE_REFUND\n"
    "- Otherwise → MANUAL_ESCALATION\n\n"
    "CRITICAL: confidence_score in your response MUST match vision_api_result.match_confidence. "
    "Do NOT lower it based on your own assessment — the vision model score is authoritative.\n\n"
    'Respond JSON: {"trace_log":[{"agent":"Ingestor","action":"Entity Extraction","result":"..."},'
    '{"agent":"Investigator","action":"Vision Delta","result":"..."},'
    '{"agent":"Auditor","action":"Policy Check","result":"..."}],'
    '"final_action":"APPROVE_REFUND"|"MANUAL_ESCALATION"|"REJECT_FRAUD","confidence_score":0.0-1.0}'
)


def _truncate_claim(text: str, max_words: int = 800) -> str:
    words = text.split()
    if len(words) > max_words:
        return " ".join(words[:max_words])
    return text


def _build_messages(
    complaint_text: str,
    user_category_selection: str | None,
    vision_json: dict,
    merchant_name: str,
    auto_refund_limit: float,
    order_amount: float,
    rider_pod_url: str = "",
    customer_image_url: str = "",
) -> list[dict]:
    truncated = _truncate_claim(complaint_text)
    context = {
        "complaint_text": truncated,
        "user_category_selection": user_category_selection,
        "vision_api_result": vision_json,
        "merchant_config": {
            "merchant_name": merchant_name,
            "auto_refund_limit": auto_refund_limit,
        },
        "order_amount": order_amount,
    }
    # Embed images as markdown for ilmu.ai gateway vision support
    image_section = ""
    if customer_image_url:
        image_section += f"![customer_evidence]({customer_image_url})\n"
    if rider_pod_url:
        image_section += f"![rider_pod]({rider_pod_url})\n"

    user_content = f"{image_section}\n{json.dumps(context)}" if image_section else json.dumps(context)
    return [
        {"role": "system", "content": _MULTI_AGENT_SYSTEM_PROMPT},
        {"role": "user", "content": user_content},
    ]


def _fallback_response() -> dict:
    return {
        "trace_log": [
            {"agent": "Ingestor", "action": "Error", "result": "GLM call failed or timed out"},
            {"agent": "Investigator", "action": "Error", "result": "Skipped due to prior failure"},
            {"agent": "Auditor", "action": "Error", "result": "Defaulting to manual escalation"},
        ],
        "final_action": "MANUAL_ESCALATION",
        "confidence_score": 0.0,
    }


def _parse_glm_content(content: str) -> dict:
    content = re.sub(r"^```(?:json)?\s*\n?", "", content.strip())
    content = re.sub(r"\n?```\s*$", "", content.strip())
    return json.loads(content)


async def call_glm(
    complaint_text: str,
    user_category_selection: str | None,
    vision_json: dict,
    merchant_name: str,
    auto_refund_limit: float,
    order_amount: float,
    rider_pod_url: str = "",
    customer_image_url: str = "",
) -> dict:
    payload = {
        "model": "ilmu-glm-5.1",
        "messages": _build_messages(
            complaint_text,
            user_category_selection,
            vision_json,
            merchant_name,
            auto_refund_limit,
            order_amount,
            rider_pod_url,
            customer_image_url,
        ),
        "temperature": 0.3,
        "response_format": {"type": "json_object"},
    }
    headers = {
        "Authorization": f"Bearer {GLM_API_KEY}",
        "Content-Type": "application/json",
    }

    for attempt in range(2):
        try:
            async with httpx.AsyncClient(timeout=GLM_TIMEOUT) as client:
                response = await client.post(GLM_API_URL, headers=headers, json=payload)
                response.raise_for_status()
                content = response.json()["choices"][0]["message"]["content"]
                return _parse_glm_content(content)
        except (httpx.TimeoutException, httpx.HTTPStatusError, KeyError, json.JSONDecodeError):
            if attempt == 0:
                continue
        except Exception:
            pass
    return _fallback_response()
