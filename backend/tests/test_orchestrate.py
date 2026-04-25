import pytest
import json
from unittest.mock import patch, AsyncMock, MagicMock
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.models import Ticket, Order


def _make_glm_response(final_action: str, confidence: float, trace_log: list[dict] | None = None) -> dict:
    """Helper to build valid multi-agent GLM responses."""
    if trace_log is None:
        trace_log = [
            {"agent": "Ingestor", "action": "Entity Extraction", "result": "Extracted intent: Refund."},
            {"agent": "Investigator", "action": "Vision Delta", "result": "High confidence damage match."},
            {"agent": "Auditor", "action": "Policy Check", "result": f"Action: {final_action}"},
        ]
    return {
        "trace_log": trace_log,
        "final_action": final_action,
        "confidence_score": confidence,
    }


# --- Core test cases (TC-01 through TC-04) ---


@pytest.mark.asyncio
async def test_tc01_happy_path_refund(client, seed_data):
    """TC-01: Valid complaint — APPROVE_REFUND triggers refund."""
    glm_response = _make_glm_response("APPROVE_REFUND", 0.95)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "My pizza box arrived completely smashed!",
                "customer_image_url": "smashed_pizza_box.jpg",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["ticket_status"] == "refunded"
    assert data["vision_match_score"] == 0.95
    assert data["glm_decision"]["final_action"] == "APPROVE_REFUND"
    assert len(data["glm_decision"]["trace_log"]) == 3

    # Verify DB state
    from tests.conftest import TestSessionLocal
    db = TestSessionLocal()
    ticket = db.query(Ticket).filter(Ticket.order_id == 1).first()
    assert ticket.status == "refunded"
    order = db.query(Order).filter(Order.id == 1).first()
    assert order.status == "refunded"
    db.close()


@pytest.mark.asyncio
async def test_tc02_negative_fraud_prevention(client, seed_data):
    """TC-02: Fraudulent claim — MANUAL_ESCALATION."""
    glm_response = _make_glm_response("MANUAL_ESCALATION", 0.10)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "I never got my order!",
                "customer_image_url": "fake_claim.jpg",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["ticket_status"] == "manual_review"
    assert data["vision_match_score"] == 0.10
    assert data["glm_decision"]["final_action"] == "MANUAL_ESCALATION"

    # Verify order was NOT refunded
    from tests.conftest import TestSessionLocal
    db = TestSessionLocal()
    order = db.query(Order).filter(Order.id == 1).first()
    assert order.status == "delivered"
    db.close()


@pytest.mark.asyncio
async def test_tc03_performance_latency(client, seed_data):
    """TC-03: Average response time < 800ms over 50 requests."""
    import time

    glm_response = _make_glm_response("APPROVE_REFUND", 0.95)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        latencies = []
        for _ in range(50):
            start = time.perf_counter()
            response = await client.post(
                "/api/orchestrate",
                json={
                    "order_id": 1,
                    "user_category_selection": "Food",
                    "complaint_text": "Item was damaged",
                    "customer_image_url": "smashed_burger.jpg",
                },
            )
            elapsed = (time.perf_counter() - start) * 1000
            latencies.append(elapsed)
            assert response.status_code == 200

    avg_latency = sum(latencies) / len(latencies)
    assert avg_latency < 800, f"Average latency {avg_latency:.1f}ms exceeds 800ms threshold"


@pytest.mark.asyncio
async def test_tc04_glm_timeout_fallback(client, seed_data):
    """TC-04: GLM timeout or Pydantic failure defaults to MANUAL_ESCALATION."""
    glm_bad_response = {"wrong_key": "bad_data"}

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_bad_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "Something went wrong",
                "customer_image_url": "smashed_pizza.jpg",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["ticket_status"] == "manual_review"
    assert data["glm_decision"]["final_action"] == "MANUAL_ESCALATION"

    from tests.conftest import TestSessionLocal
    db = TestSessionLocal()
    ticket = db.query(Ticket).filter(Ticket.order_id == 1).first()
    assert ticket.status == "manual_review"
    db.close()


# --- Multi-tenant scenario tests ---


@pytest.mark.asyncio
async def test_scenario_a_food_smashed(client, seed_data):
    """Scenario A: Food (Grab) — smashed pizza box → APPROVE_REFUND."""
    glm_response = _make_glm_response("APPROVE_REFUND", 0.95)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "My pizza box is completely smashed!",
                "customer_image_url": "smashed_pizza_box.jpg",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["vision_match_score"] == 0.95
    assert data["glm_decision"]["final_action"] == "APPROVE_REFUND"


@pytest.mark.asyncio
async def test_scenario_b_electronics_crushed(client, seed_data):
    """Scenario B: Electronics (Zalora) — crushed laptop → APPROVE_REFUND."""
    glm_response = _make_glm_response("APPROVE_REFUND", 0.92)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 2,
                "user_category_selection": "Electronics",
                "complaint_text": "The laptop box arrived crushed!",
                "customer_image_url": "crushed_laptop_box.jpg",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["vision_match_score"] == 0.92
    assert data["glm_decision"]["final_action"] == "APPROVE_REFUND"


@pytest.mark.asyncio
async def test_scenario_c_apparel_torn(client, seed_data):
    """Scenario C: Apparel (DHL) — torn courier bag → APPROVE_REFUND."""
    glm_response = _make_glm_response("APPROVE_REFUND", 0.90)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 3,
                "user_category_selection": "Apparel",
                "complaint_text": "The courier bag was torn and clothes fell out!",
                "customer_image_url": "torn_courier_bag.jpg",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["vision_match_score"] == 0.90
    assert data["glm_decision"]["final_action"] == "APPROVE_REFUND"


@pytest.mark.asyncio
async def test_scenario_dented_escalates(client, seed_data):
    """Dented packaging (0.70 confidence) → MANUAL_ESCALATION."""
    glm_response = _make_glm_response("MANUAL_ESCALATION", 0.70)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "Box has a dent but not sure if item is affected",
                "customer_image_url": "dented_box.jpg",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["vision_match_score"] == 0.70
    assert data["ticket_status"] == "manual_review"


# --- REJECT_FRAUD: Category mismatch ---


@pytest.mark.asyncio
async def test_fraud_category_mismatch(client, seed_data):
    """User selects 'Food' but text says 'Cracked screen' → REJECT_FRAUD."""
    trace = [
        {"agent": "Ingestor", "action": "Entity Extraction", "result": "Category mismatch: user selected Food but complaint describes Electronics damage (cracked screen)."},
        {"agent": "Investigator", "action": "Vision Delta", "result": "Image does not match Food category claim."},
        {"agent": "Auditor", "action": "Policy Check", "result": "Fraud detected — category mismatch."},
    ]
    glm_response = _make_glm_response("REJECT_FRAUD", 0.15, trace)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "My phone screen is cracked!",
                "customer_image_url": "crushed_laptop_box.jpg",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["ticket_status"] == "fraud_rejected"
    assert data["glm_decision"]["final_action"] == "REJECT_FRAUD"
    # Verify Ingestor caught the mismatch
    ingestor_result = data["glm_decision"]["trace_log"][0]["result"]
    assert "mismatch" in ingestor_result.lower()


# --- GLM client unit tests ---


def test_truncate_claim_under_limit():
    from app.services.glm_client import _truncate_claim
    text = "hello world"
    assert _truncate_claim(text, max_words=800) == text


def test_truncate_claim_over_limit():
    from app.services.glm_client import _truncate_claim
    words = ["word"] * 900
    text = " ".join(words)
    result = _truncate_claim(text, max_words=800)
    assert len(result.split()) == 800


def test_build_messages():
    from app.services.glm_client import _build_messages
    messages = _build_messages(
        complaint_text="item is damaged",
        user_category_selection="Electronics",
        vision_json={"match_confidence": 0.5, "damage_detected": False, "damage_type": None},
        merchant_name="Zalora",
        auto_refund_limit=500.0,
        order_amount=499.0,
    )
    assert len(messages) == 2
    assert messages[0]["role"] == "system"
    assert messages[1]["role"] == "user"
    # Verify system prompt has 3-persona structure
    assert "Ingestor" in messages[0]["content"]
    assert "Investigator" in messages[0]["content"]
    assert "Auditor" in messages[0]["content"]
    # Verify context in user message (no images → plain JSON)
    user_content = json.loads(messages[1]["content"])
    assert user_content["complaint_text"] == "item is damaged"
    assert user_content["user_category_selection"] == "Electronics"
    assert user_content["merchant_config"]["merchant_name"] == "Zalora"
    assert user_content["merchant_config"]["auto_refund_limit"] == 500.0


def test_build_messages_with_images():
    """Verify images are embedded as markdown in user message for ilmu.ai gateway."""
    from app.services.glm_client import _build_messages
    messages = _build_messages(
        complaint_text="food arrived smashed",
        user_category_selection="Food",
        vision_json={"match_confidence": 0.95, "damage_detected": True, "damage_type": "Food damaged"},
        merchant_name="Grab",
        auto_refund_limit=50.0,
        order_amount=25.99,
        rider_pod_url="https://placehold.co/600x400/4CAF50/white?text=Intact+Food+Box",
        customer_image_url="https://placehold.co/600x400/F44336/white?text=Smashed+Pizza",
    )
    user_content = messages[1]["content"]
    # Must contain markdown image references
    assert "![customer_evidence](https://placehold.co/600x400/F44336/white?text=Smashed+Pizza)" in user_content
    assert "![rider_pod](https://placehold.co/600x400/4CAF50/white?text=Intact+Food+Box)" in user_content
    # Context JSON must still be present after images
    assert '"complaint_text"' in user_content
    assert '"merchant_name": "Grab"' in user_content


def test_build_messages_no_images():
    """Verify no markdown image when URLs are empty."""
    from app.services.glm_client import _build_messages
    messages = _build_messages(
        complaint_text="item is damaged",
        user_category_selection="Electronics",
        vision_json={"match_confidence": 0.5, "damage_detected": False, "damage_type": None},
        merchant_name="Zalora",
        auto_refund_limit=500.0,
        order_amount=499.0,
        rider_pod_url="",
        customer_image_url="",
    )
    user_content = messages[1]["content"]
    assert "![" not in user_content
    # Should be plain JSON
    parsed = json.loads(user_content)
    assert parsed["complaint_text"] == "item is damaged"


@pytest.mark.asyncio
async def test_call_glm_success_mocked():
    """Test call_glm with mocked HTTP returning valid multi-agent JSON."""
    from app.services.glm_client import call_glm

    mock_response = MagicMock()
    mock_response.raise_for_status = MagicMock()
    mock_response.json.return_value = {
        "choices": [{"message": {"content": json.dumps(_make_glm_response("APPROVE_REFUND", 0.9))}}]
    }

    mock_client = AsyncMock()
    mock_client.post = AsyncMock(return_value=mock_response)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("app.services.glm_client.httpx.AsyncClient", return_value=mock_client):
        result = await call_glm("item damaged", "Electronics", {"match_confidence": 0.9}, "Zalora", 500.0, 499.0)

    assert result["final_action"] == "APPROVE_REFUND"
    assert result["confidence_score"] == 0.9
    assert len(result["trace_log"]) == 3


@pytest.mark.asyncio
async def test_call_glm_markdown_fence_stripping():
    """Test markdown code fences stripped from multi-agent response."""
    from app.services.glm_client import call_glm

    payload = _make_glm_response("MANUAL_ESCALATION", 0.2)
    content = f"```json\n{json.dumps(payload)}\n```"

    mock_response = MagicMock()
    mock_response.raise_for_status = MagicMock()
    mock_response.json.return_value = {"choices": [{"message": {"content": content}}]}

    mock_client = AsyncMock()
    mock_client.post = AsyncMock(return_value=mock_response)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("app.services.glm_client.httpx.AsyncClient", return_value=mock_client):
        result = await call_glm("fake claim", "Food", {"match_confidence": 0.2}, "Grab", 50.0, 25.0)

    assert result["final_action"] == "MANUAL_ESCALATION"
    assert result["confidence_score"] == 0.2


@pytest.mark.asyncio
async def test_call_glm_timeout_fallback():
    """Test call_glm falls back to MANUAL_ESCALATION on timeout."""
    import httpx
    from app.services.glm_client import call_glm

    mock_client = AsyncMock()
    mock_client.post = AsyncMock(side_effect=httpx.TimeoutException("timeout"))
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("app.services.glm_client.httpx.AsyncClient", return_value=mock_client):
        result = await call_glm("item damaged", "Electronics", {"match_confidence": 0.9}, "Zalora", 500.0, 499.0)

    assert result["final_action"] == "MANUAL_ESCALATION"
    assert result["confidence_score"] == 0.0
    assert len(result["trace_log"]) == 3


@pytest.mark.asyncio
async def test_call_glm_json_decode_error_fallback():
    """Test call_glm falls back on invalid JSON in response content."""
    from app.services.glm_client import call_glm

    mock_response = MagicMock()
    mock_response.raise_for_status = MagicMock()
    mock_response.json.return_value = {"choices": [{"message": {"content": "this is not valid json"}}]}

    mock_client = AsyncMock()
    mock_client.post = AsyncMock(return_value=mock_response)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("app.services.glm_client.httpx.AsyncClient", return_value=mock_client):
        result = await call_glm("item damaged", "Electronics", {"match_confidence": 0.9}, "Zalora", 500.0, 499.0)

    assert result["final_action"] == "MANUAL_ESCALATION"


# --- Other coverage tests ---


@pytest.mark.asyncio
async def test_audit_logs_endpoint(client, seed_data):
    """Test GET /api/audit-logs returns logs."""
    from tests.conftest import TestSessionLocal
    from app.models import AuditLog

    db = TestSessionLocal()
    db.add(AuditLog(ticket_id=1, action="vision_check", raw_json='{"test": true}'))
    db.commit()
    db.close()

    response = await client.get("/api/audit-logs")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert data[0]["action"] == "vision_check"


def test_vision_all_scenarios():
    """Test all mock vision scenarios return correct values."""
    from app.routers.mock import vision_verify
    from app.schemas import VisionVerifyRequest

    # Food — smashed
    r = vision_verify(VisionVerifyRequest(customer_image_url="smashed_pizza_box.jpg", pod_image_url="pod.jpg"))
    assert r.match_confidence == 0.95
    assert r.damage_detected is True
    assert "food" in r.damage_type.lower()

    # Food — soggy
    r = vision_verify(VisionVerifyRequest(customer_image_url="soggy_noodles.jpg", pod_image_url="pod.jpg"))
    assert r.match_confidence == 0.88
    assert r.damage_detected is True

    # Electronics — crushed
    r = vision_verify(VisionVerifyRequest(customer_image_url="crushed_laptop_box.jpg", pod_image_url="pod.jpg"))
    assert r.match_confidence == 0.92
    assert r.damage_detected is True
    assert "electronics" in r.damage_type.lower()

    # Electronics — dented
    r = vision_verify(VisionVerifyRequest(customer_image_url="dented_box.jpg", pod_image_url="pod.jpg"))
    assert r.match_confidence == 0.70
    assert r.damage_detected is True

    # Apparel — torn
    r = vision_verify(VisionVerifyRequest(customer_image_url="torn_courier_bag.jpg", pod_image_url="pod.jpg"))
    assert r.match_confidence == 0.90
    assert r.damage_detected is True
    assert "apparel" in r.damage_type.lower()

    # Apparel — stained
    r = vision_verify(VisionVerifyRequest(customer_image_url="stained_package.jpg", pod_image_url="pod.jpg"))
    assert r.match_confidence == 0.75
    assert r.damage_detected is True

    # Fraud — fake
    r = vision_verify(VisionVerifyRequest(customer_image_url="fake_claim.jpg", pod_image_url="pod.jpg"))
    assert r.match_confidence == 0.10
    assert r.damage_detected is False

    # Default — unknown
    r = vision_verify(VisionVerifyRequest(customer_image_url="normal_photo.jpg", pod_image_url="pod.jpg"))
    assert r.match_confidence == 0.50
    assert r.damage_detected is False
    assert "manual inspection" in r.damage_type.lower()


def test_seed_module():
    """Test seed.py runs without error."""
    import importlib
    from app import database as _db_mod

    original_url = _db_mod.DATABASE_URL
    _db_mod.DATABASE_URL = "sqlite:///./test_seed_check.db"
    _db_mod.engine = create_engine(_db_mod.DATABASE_URL, connect_args={"check_same_thread": False})
    _db_mod.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=_db_mod.engine)
    _db_mod.Base.metadata.create_all(bind=_db_mod.engine)

    from app import seed as seed_mod
    importlib.reload(seed_mod)

    _db_mod.DATABASE_URL = original_url
    _db_mod.engine = create_engine(_db_mod.DATABASE_URL, connect_args={"check_same_thread": False} if original_url.startswith("sqlite") else {})
    _db_mod.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=_db_mod.engine)


def test_get_db_generator():
    """Test get_db yields a session and closes it."""
    from app.database import get_db
    gen = get_db()
    db = next(gen)
    assert db is not None
    gen.close()


@pytest.mark.asyncio
async def test_health_endpoint(client):
    """Test GET /health returns ok."""
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


# --- Edge case tests ---


@pytest.mark.asyncio
async def test_fraud_reject_sets_fraud_status(client, seed_data):
    """REJECT_FRAUD sets ticket to fraud_rejected and order stays delivered."""
    trace = [
        {"agent": "Ingestor", "action": "Entity Extraction", "result": "Category mismatch detected. Claim describes Electronics but order is Food."},
        {"agent": "Investigator", "action": "Vision Delta", "result": "Image does not match claimed damage type. Low confidence."},
        {"agent": "Auditor", "action": "Policy Check", "result": "Fraud detected — category and image mismatch. Rejecting."},
    ]
    glm_response = _make_glm_response("REJECT_FRAUD", 0.15, trace)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "Phone screen cracked",
                "customer_image_url": "crushed_laptop_box.jpg",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["ticket_status"] == "fraud_rejected"
    assert data["glm_decision"]["final_action"] == "REJECT_FRAUD"

    # Order should NOT be refunded
    from tests.conftest import TestSessionLocal
    db = TestSessionLocal()
    order = db.query(Order).filter(Order.id == 1).first()
    assert order.status == "delivered"
    db.close()


@pytest.mark.asyncio
async def test_glm_exception_defaults_to_manual_review(client, seed_data):
    """GLM call raises exception → defaults to manual_review, never 500."""
    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, side_effect=Exception("GLM down")):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "Something went wrong",
                "customer_image_url": "smashed_pizza.jpg",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["ticket_status"] == "manual_review"
    assert data["glm_decision"]["final_action"] == "MANUAL_ESCALATION"
    assert len(data["glm_decision"]["trace_log"]) == 3  # fallback trace


@pytest.mark.asyncio
async def test_invalid_order_id_still_processes(client, seed_data):
    """Non-existent order_id → still creates ticket, defaults to Unknown merchant."""
    glm_response = _make_glm_response("MANUAL_ESCALATION", 0.50)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 999,
                "user_category_selection": "General",
                "complaint_text": "Generic complaint",
                "customer_image_url": "photo.jpg",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["ticket_status"] == "manual_review"


@pytest.mark.asyncio
async def test_empty_complaint_text(client, seed_data):
    """Empty complaint text still processes without error."""
    glm_response = _make_glm_response("MANUAL_ESCALATION", 0.30)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "",
                "customer_image_url": "",
            },
        )

    assert response.status_code == 200


@pytest.mark.asyncio
async def test_claims_endpoint_returns_submitted_claim(client, seed_data):
    """GET /api/claims returns claims after orchestration."""
    glm_response = _make_glm_response("APPROVE_REFUND", 0.95)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "Smashed pizza",
                "customer_image_url": "smashed_pizza_box.jpg",
            },
        )

    response = await client.get("/api/claims")
    assert response.status_code == 200
    data = response.json()
    assert len(data) >= 1
    claim = data[0]
    assert claim["id"].startswith("CLM-")
    assert claim["merchant"] == "Grab"
    assert claim["category"] == "Food"
    assert claim["status"] == "resolved"
    assert claim["confidence"] == 0.95


@pytest.mark.asyncio
async def test_claims_endpoint_merchant_filter(client, seed_data):
    """GET /api/claims?merchant=Grab filters correctly."""
    glm_response = _make_glm_response("APPROVE_REFUND", 0.95)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "Smashed pizza",
                "customer_image_url": "smashed_pizza_box.jpg",
            },
        )

    response = await client.get("/api/claims?merchant=Grab")
    assert response.status_code == 200
    data = response.json()
    assert all(c["merchant"] == "Grab" for c in data)

    # Non-matching merchant returns empty
    response = await client.get("/api/claims?merchant=NonExistent")
    assert response.status_code == 200
    assert len(response.json()) == 0


@pytest.mark.asyncio
async def test_claim_trace_endpoint(client, seed_data):
    """GET /api/claims/{id}/trace returns structured trace."""
    glm_response = _make_glm_response("APPROVE_REFUND", 0.95)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "Smashed pizza",
                "customer_image_url": "smashed_pizza_box.jpg",
            },
        )

    response = await client.get("/api/claims/1/trace")
    assert response.status_code == 200
    data = response.json()
    assert "ingestorResult" in data
    assert "investigatorConfidence" in data
    assert "investigatorSummary" in data
    assert "complianceChecks" in data
    assert "verdict" in data
    assert "reasoningLog" in data
    assert len(data["reasoningLog"]) == 3
    assert data["verdict"] == "Autonomous Approval"


@pytest.mark.asyncio
async def test_claim_trace_not_found(client, seed_data):
    """GET /api/claims/{id}/trace returns error for non-existent ticket."""
    response = await client.get("/api/claims/9999/trace")
    assert response.status_code == 200
    data = response.json()
    assert "error" in data


@pytest.mark.asyncio
async def test_merchant_policies_endpoint(client, seed_data):
    """GET /api/merchants/policies returns all merchant configs."""
    response = await client.get("/api/merchants/policies")
    assert response.status_code == 200
    data = response.json()
    assert len(data) >= 3  # Grab, Zalora, DHL
    merchants = [p["merchantName"] for p in data]
    assert "Grab" in merchants
    assert "Zalora" in merchants
    assert "DHL" in merchants
    # Verify policy structure
    for p in data:
        assert "merchantId" in p
        assert "autoRefundThreshold" in p
        assert "categories" in p
        assert isinstance(p["categories"], list)


@pytest.mark.asyncio
async def test_claims_status_mapping(client, seed_data):
    """Verify backend statuses map correctly to frontend statuses in GET /api/claims."""
    # Submit with REJECT_FRAUD
    trace = [
        {"agent": "Ingestor", "action": "Entity Extraction", "result": "Fraud detected."},
        {"agent": "Investigator", "action": "Vision Delta", "result": "No damage match."},
        {"agent": "Auditor", "action": "Policy Check", "result": "Fraud — rejecting."},
    ]
    glm_response = _make_glm_response("REJECT_FRAUD", 0.10, trace)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "Fake claim",
                "customer_image_url": "fake_claim.jpg",
            },
        )

    response = await client.get("/api/claims")
    data = response.json()
    fraud_claim = [c for c in data if c["status"] == "denied"]
    assert len(fraud_claim) >= 1, "fraud_rejected should map to 'denied'"


@pytest.mark.asyncio
async def test_multiple_claims_same_order(client, seed_data):
    """Multiple claims for the same order_id each get their own ticket."""
    glm_response = _make_glm_response("APPROVE_REFUND", 0.95)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        for i in range(3):
            response = await client.post(
                "/api/orchestrate",
                json={
                    "order_id": 1,
                    "user_category_selection": "Food",
                    "complaint_text": f"Complaint {i+1}",
                    "customer_image_url": "smashed_food.jpg",
                },
            )
            assert response.status_code == 200

    response = await client.get("/api/claims")
    data = response.json()
    assert len(data) >= 3


@pytest.mark.asyncio
async def test_vision_override_approves_when_glm_escalates(client, seed_data):
    """GLM returns MANUAL_ESCALATION due to low confidence, but vision is 0.95 → override to APPROVE_REFUND."""
    # GLM gives low confidence but no error — real scenario where GLM is too cautious
    trace = [
        {"agent": "Ingestor", "action": "Entity Extraction", "result": "Damage extracted. No mismatch."},
        {"agent": "Investigator", "action": "Vision Delta", "result": "Moderate confidence."},
        {"agent": "Auditor", "action": "Policy Check", "result": "Escalating for review."},
    ]
    glm_response = _make_glm_response("MANUAL_ESCALATION", 0.60, trace)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "Food arrived smashed",
                "customer_image_url": "smashed_pizza_box.jpg",  # vision returns 0.95
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["ticket_status"] == "refunded", "Vision override should approve when vision >= 0.85"
    assert data["glm_decision"]["final_action"] == "APPROVE_REFUND"


@pytest.mark.asyncio
async def test_vision_override_does_not_apply_when_glm_errors(client, seed_data):
    """GLM fails entirely → fallback trace_log has Error entries → no override, stays manual_review."""
    glm_bad_response = {"wrong_key": "bad_data"}

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_bad_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "Food arrived smashed",
                "customer_image_url": "smashed_pizza_box.jpg",  # vision returns 0.95
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["ticket_status"] == "manual_review", "Override should NOT apply when GLM errored"


@pytest.mark.asyncio
async def test_vision_override_does_not_apply_for_fraud(client, seed_data):
    """GLM returns REJECT_FRAUD → override should NOT upgrade to APPROVE_REFUND."""
    trace = [
        {"agent": "Ingestor", "action": "Entity Extraction", "result": "Category mismatch detected."},
        {"agent": "Investigator", "action": "Vision Delta", "result": "Image doesn't match claim."},
        {"agent": "Auditor", "action": "Policy Check", "result": "Fraud — rejecting."},
    ]
    glm_response = _make_glm_response("REJECT_FRAUD", 0.10, trace)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "Phone screen cracked",
                "customer_image_url": "crushed_laptop_box.jpg",  # vision returns 0.92
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["ticket_status"] == "fraud_rejected", "Override should NOT apply for REJECT_FRAUD"


@pytest.mark.asyncio
async def test_vision_override_does_not_apply_low_vision(client, seed_data):
    """Vision score < 0.85 → override should NOT apply even if GLM escalates."""
    glm_response = _make_glm_response("MANUAL_ESCALATION", 0.60)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "Box has a dent",
                "customer_image_url": "dented_box.jpg",  # vision returns 0.70
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["ticket_status"] == "manual_review", "Override should NOT apply when vision < 0.85"


@pytest.mark.asyncio
async def test_scenario_4_shopee_minor_damage(client, seed_data):
    """Scenario 4: Shopee Electronics — minor scratch → MANUAL_ESCALATION."""
    glm_response = _make_glm_response("MANUAL_ESCALATION", 0.50)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 4,
                "user_category_selection": "Electronics",
                "complaint_text": "Small scratch on package",
                "customer_image_url": "https://placehold.co/600x400/FFC107/white?text=Minor+Scratch",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["ticket_status"] == "manual_review"
    assert data["rider_pod_url"] is not None


@pytest.mark.asyncio
async def test_orchestrate_returns_rider_pod_url(client, seed_data):
    """Orchestrate response includes rider_pod_url from the order."""
    glm_response = _make_glm_response("APPROVE_REFUND", 0.95)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "Food smashed",
                "customer_image_url": "https://placehold.co/600x400/F44336/white?text=Smashed+Pizza",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert "rider_pod_url" in data
    assert data["rider_pod_url"] is not None
    assert "placehold.co" in data["rider_pod_url"]


@pytest.mark.asyncio
async def test_claims_endpoint_includes_rider_pod_url(client, seed_data):
    """GET /api/claims includes riderPodUrl field."""
    glm_response = _make_glm_response("APPROVE_REFUND", 0.95)

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "user_category_selection": "Food",
                "complaint_text": "Food smashed",
                "customer_image_url": "https://placehold.co/600x400/F44336/white?text=Smashed+Pizza",
            },
        )

    response = await client.get("/api/claims")
    assert response.status_code == 200
    data = response.json()
    assert len(data) >= 1
    assert data[0]["riderPodUrl"] is not None
