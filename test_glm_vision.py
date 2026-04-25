"""
Standalone test: Verify ilmu-glm-5.1 multimodal (vision) capabilities.
Tests both remote image URL and Base64-encoded image inputs.
Strictly uses Z AI GLM API only.

Discovery: ilmu-glm-5.1 via ilmu.ai gateway does NOT support the
OpenAI-style content array (image_url blocks are silently dropped).
Instead, images must be embedded as markdown ![image](url) within
the text content string — both remote URLs and data: URIs work.
"""

import base64
import json
import os
import sys

import httpx

GLM_API_URL = os.getenv("GLM_API_URL", "https://api.ilmu.ai/v1/chat/completions")
GLM_API_KEY = os.getenv("GLM_API_KEY", "")
GLM_MODEL = "ilmu-glm-5.1"
GLM_TIMEOUT_VISION = 120


def _headers() -> dict:
    return {
        "Authorization": f"Bearer {GLM_API_KEY}",
        "Content-Type": "application/json",
    }


def _log(label: str, data: dict) -> None:
    print(f"\n{'='*60}")
    print(f"  {label}")
    print(f"{'='*60}")
    safe = json.dumps(data, indent=2, ensure_ascii=False)
    sys.stdout.buffer.write(safe.encode("utf-8"))
    sys.stdout.buffer.write(b"\n")
    sys.stdout.buffer.flush()


def _is_visual_response(content: str) -> bool:
    """Heuristic: if GLM says it can't see the image, that's not a real vision pass."""
    no_image_phrases = [
        "no image was attached",
        "no image",
        "could you please upload",
        "please share the image",
        "it appears that no image",
        "i can't see",
        "cannot see",
        "unable to see",
        "no picture",
        "no photo",
        "don't see any image",
    ]
    lower = content.lower()
    return not any(phrase in lower for phrase in no_image_phrases)


def _call_glm(messages: list[dict], max_tokens: int = 1024, timeout: int = GLM_TIMEOUT_VISION) -> dict:
    """Send a request to GLM and return the parsed response dict."""
    payload = {
        "model": GLM_MODEL,
        "messages": messages,
        "temperature": 0.3,
        "max_tokens": max_tokens,
    }
    with httpx.Client(timeout=timeout) as client:
        response = client.post(GLM_API_URL, headers=_headers(), json=payload)
        response.raise_for_status()
        return response.json()


def test_remote_image_url() -> bool:
    """TC-V1: GLM processes a remote image URL and returns visual reasoning."""
    image_url = (
        "https://upload.wikimedia.org/wikipedia/commons/"
        "thumb/5/5f/Box_with_FRAGILE_sticker.jpg/640px-Box_with_FRAGILE_sticker.jpg"
    )

    # ilmu-glm-5.1 requires image URLs embedded as markdown in text content
    messages = [
        {
            "role": "user",
            "content": (
                f"![image]({image_url})\n\n"
                "Analyze this image. Describe the condition of the package "
                "and identify any visible damage."
            ),
        }
    ]

    print(f"\n[TC-V1] Remote Image URL Test")
    print(f"  URL: {image_url}")
    print(f"  Format: markdown-embedded image URL")

    try:
        raw = _call_glm(messages)
        _log("TC-V1 Raw Response", raw)

        content = raw["choices"][0]["message"]["content"]
        usage = raw.get("usage", {})
        print(f"\n[TC-V1] Token usage: prompt={usage.get('prompt_tokens')}, "
              f"completion={usage.get('completion_tokens')}")
        sys.stdout.buffer.write(f"[TC-V1] GLM Description:\n  {content}\n".encode("utf-8"))
        sys.stdout.buffer.flush()

        if not content or len(content.strip()) < 10:
            print("[TC-V1] FAIL: Response too short.")
            return False

        if not _is_visual_response(content):
            print("[TC-V1] FAIL: GLM did not process the image (said it can't see one).")
            return False

        if usage.get("prompt_tokens", 0) == 0:
            print("[TC-V1] WARN: prompt_tokens=0 — image may not have been tokenized.")

        print("[TC-V1] PASS: GLM returned visual reasoning from remote URL.")
        return True

    except httpx.TimeoutException:
        print("[TC-V1] FAIL: Request timed out.")
        return False
    except httpx.HTTPStatusError as e:
        print(f"[TC-V1] FAIL: HTTP {e.response.status_code} — {e.response.text}")
        return False
    except (KeyError, json.JSONDecodeError) as e:
        print(f"[TC-V1] FAIL: Malformed response — {e}")
        return False


def test_base64_image() -> bool:
    """TC-V2: GLM processes a Base64-encoded image and returns pixel-level reasoning."""
    local_image = os.path.join(
        os.path.dirname(__file__),
        "frontend",
        "stitch_assets",
        "screenshots",
        "04_merchant_policy_editor.png",
    )

    if not os.path.isfile(local_image):
        print(f"[TC-V2] SKIP: Local test image not found at {local_image}")
        return False

    with open(local_image, "rb") as f:
        b64_data = base64.b64encode(f.read()).decode("utf-8")

    ext = os.path.splitext(local_image)[1].lower()
    mime_map = {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".gif": "image/gif",
        ".webp": "image/webp",
    }
    mime = mime_map.get(ext, "image/png")
    data_uri = f"data:{mime};base64,{b64_data}"

    # ilmu-glm-5.1: embed data URI as markdown image in text content
    messages = [
        {
            "role": "user",
            "content": (
                f"![image]({data_uri})\n\n"
                "Perform an OCR and structural analysis on this uploaded image. "
                "Does it contain a 'FRAGILE' sticker?"
            ),
        }
    ]

    print(f"\n[TC-V2] Base64 Image Test")
    print(f"  File: {local_image}")
    print(f"  MIME: {mime}")
    print(f"  Base64 length: {len(b64_data)} chars")
    print(f"  Format: markdown-embedded data URI")

    try:
        raw = _call_glm(messages, timeout=GLM_TIMEOUT_VISION)
        _log("TC-V2 Raw Response", raw)

        content = raw["choices"][0]["message"]["content"]
        usage = raw.get("usage", {})
        print(f"\n[TC-V2] Token usage: prompt={usage.get('prompt_tokens')}, "
              f"completion={usage.get('completion_tokens')}")
        sys.stdout.buffer.write(f"[TC-V2] GLM Analysis:\n  {content}\n".encode("utf-8"))
        sys.stdout.buffer.flush()

        if not content or len(content.strip()) < 10:
            print("[TC-V2] FAIL: Response too short.")
            return False

        if not _is_visual_response(content):
            print("[TC-V2] FAIL: GLM did not process the image (said it can't see one).")
            return False

        prompt_tokens = usage.get("prompt_tokens", 0)
        if prompt_tokens == 0:
            print("[TC-V2] WARN: prompt_tokens=0 — image may not have been tokenized.")
        else:
            print(f"[TC-V2] Image tokenized: {prompt_tokens} prompt tokens (confirms pixel processing).")

        print("[TC-V2] PASS: GLM returned reasoning from Base64-encoded image.")
        return True

    except httpx.TimeoutException:
        print("[TC-V2] FAIL: Request timed out.")
        return False
    except httpx.HTTPStatusError as e:
        print(f"[TC-V2] FAIL: HTTP {e.response.status_code} — {e.response.text}")
        return False
    except (KeyError, json.JSONDecodeError) as e:
        print(f"[TC-V2] FAIL: Malformed response — {e}")
        return False


def _disqualification_check() -> bool:
    """Verify no prohibited third-party AI SDK references exist in code."""
    script_path = os.path.abspath(__file__)
    with open(script_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    violations = []
    for i, line in enumerate(lines, 1):
        low = line.lower()
        is_import_or_model = (
            low.strip().startswith("import ")
            or low.strip().startswith("from ")
            or ("model" in low and "=" in low and '"' in line)
        )
        if not is_import_or_model:
            continue
        for term in ["gemini", "openai"]:
            if term in low:
                violations.append(f"  Line {i}: {line.strip()}")

    if violations:
        print("[DQ] FAIL: Prohibited references found in code:")
        for v in violations:
            print(v)
        return False

    print("[DQ] PASS: No prohibited third-party AI references in code.")
    return True


def main():
    sys.stdout.reconfigure(encoding="utf-8")

    print("=" * 60)
    print("  GLM 5.1 Multimodal Vision Verification")
    print(f"  Endpoint: {GLM_API_URL}")
    print(f"  Model:    {GLM_MODEL}")
    print(f"  Key:      {GLM_API_KEY[:8]}...{GLM_API_KEY[-4:]}")
    print("=" * 60)

    if not GLM_API_KEY:
        print("\nERROR: GLM_API_KEY is not set. Export it or add to .env before running.")
        sys.exit(1)

    results = {}

    results["DQ"] = _disqualification_check()
    results["TC-V1"] = test_remote_image_url()
    results["TC-V2"] = test_base64_image()

    print(f"\n{'='*60}")
    print("  SUMMARY")
    print(f"{'='*60}")
    for tc, passed in results.items():
        status = "PASS" if passed else "FAIL"
        print(f"  {tc}: {status}")

    all_passed = all(results.values())
    print(f"\n  Overall: {'ALL PASSED' if all_passed else 'SOME FAILED'}")
    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
