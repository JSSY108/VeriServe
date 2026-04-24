import pytest
import json
from unittest.mock import patch, AsyncMock, MagicMock
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.models import Ticket, Order


@pytest.mark.asyncio
async def test_tc01_happy_path_refund(client, seed_data):
    """TC-01: Valid complaint with high match confidence triggers refund."""
    glm_response = {"action": "refund", "reason": "High confidence match", "confidence": 0.95}

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "customer_claim": "My pizza box arrived completely smashed!",
                "customer_image_url": "smashed_pizza_box.jpg",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["ticket_status"] == "refunded"
    assert data["vision_match_score"] == 0.95
    assert data["glm_decision"]["action"] == "refund"

    # Verify DB state — ticket is refunded
    from tests.conftest import TestSessionLocal
    db = TestSessionLocal()
    ticket = db.query(Ticket).filter(Ticket.order_id == 1).first()
    assert ticket is not None
    assert ticket.status == "refunded"

    # Verify order status was updated to refunded (mock_stripe_refund called)
    order = db.query(Order).filter(Order.id == 1).first()
    assert order.status == "refunded"
    db.close()


@pytest.mark.asyncio
async def test_tc02_negative_fraud_prevention(client, seed_data):
    """TC-02: Fraudulent claim with low match escalates to manual review."""
    glm_response = {"action": "escalate", "reason": "Low confidence match", "confidence": 0.10}

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "customer_claim": "I never got my order!",
                "customer_image_url": "fake_claim.jpg",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["ticket_status"] == "manual_review"
    assert data["vision_match_score"] == 0.10
    assert data["glm_decision"]["action"] == "escalate"

    # Verify DB state — ticket is manual_review
    from tests.conftest import TestSessionLocal
    db = TestSessionLocal()
    ticket = db.query(Ticket).filter(Ticket.order_id == 1).first()
    assert ticket is not None
    assert ticket.status == "manual_review"

    # Verify order was NOT refunded (stripe_refund NOT called)
    order = db.query(Order).filter(Order.id == 1).first()
    assert order.status == "delivered"
    db.close()


@pytest.mark.asyncio
async def test_tc03_performance_latency(client, seed_data):
    """TC-03: Average response time < 800ms over 50 requests."""
    import time

    glm_response = {"action": "refund", "reason": "High confidence", "confidence": 0.95}

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        latencies = []
        for _ in range(50):
            start = time.perf_counter()
            response = await client.post(
                "/api/orchestrate",
                json={
                    "order_id": 1,
                    "customer_claim": "Item was damaged",
                    "customer_image_url": "smashed_burger.jpg",
                },
            )
            elapsed = (time.perf_counter() - start) * 1000  # ms
            latencies.append(elapsed)
            assert response.status_code == 200

    avg_latency = sum(latencies) / len(latencies)
    assert avg_latency < 800, f"Average latency {avg_latency:.1f}ms exceeds 800ms threshold"


@pytest.mark.asyncio
async def test_tc04_glm_timeout_fallback(client, seed_data):
    """TC-04: GLM timeout or Pydantic validation failure defaults to manual_review."""
    # Simulate GLM returning invalid JSON (Pydantic validation failure)
    glm_bad_response = {"wrong_key": "bad_data"}

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_bad_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "customer_claim": "Something went wrong",
                "customer_image_url": "smashed_pizza.jpg",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["ticket_status"] == "manual_review"

    # Verify DB state
    from tests.conftest import TestSessionLocal
    db = TestSessionLocal()
    ticket = db.query(Ticket).filter(Ticket.order_id == 1).first()
    assert ticket is not None
    assert ticket.status == "manual_review"
    db.close()


# --- Multi-tenant scenario tests ---


@pytest.mark.asyncio
async def test_scenario_a_food_smashed(client, seed_data):
    """Scenario A: Food — smashed pizza box triggers refund."""
    glm_response = {"action": "refund", "reason": "High confidence — food packaging damaged", "confidence": 0.95}

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "customer_claim": "My pizza box is completely smashed!",
                "customer_image_url": "smashed_pizza_box.jpg",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["vision_match_score"] == 0.95
    assert data["glm_decision"]["action"] == "refund"


@pytest.mark.asyncio
async def test_scenario_b_electronics_crushed(client, seed_data):
    """Scenario B: Electronics — crushed laptop box triggers refund."""
    glm_response = {"action": "refund", "reason": "High confidence — electronics box crushed", "confidence": 0.92}

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 2,
                "customer_claim": "The laptop box arrived crushed!",
                "customer_image_url": "crushed_laptop_box.jpg",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["vision_match_score"] == 0.92
    assert data["glm_decision"]["action"] == "refund"


@pytest.mark.asyncio
async def test_scenario_c_apparel_torn(client, seed_data):
    """Scenario C: Apparel — torn courier bag triggers refund."""
    glm_response = {"action": "refund", "reason": "High confidence — courier bag torn", "confidence": 0.90}

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 3,
                "customer_claim": "The courier bag was torn and clothes fell out!",
                "customer_image_url": "torn_courier_bag.jpg",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["vision_match_score"] == 0.90
    assert data["glm_decision"]["action"] == "refund"


@pytest.mark.asyncio
async def test_scenario_dented_escalates(client, seed_data):
    """Dented packaging (0.70 confidence) should escalate, not auto-refund."""
    glm_response = {"action": "escalate", "reason": "Below threshold — needs manual review", "confidence": 0.70}

    with patch("app.routers.orchestrate.call_glm", new_callable=AsyncMock, return_value=glm_response):
        response = await client.post(
            "/api/orchestrate",
            json={
                "order_id": 1,
                "customer_claim": "Box has a dent but not sure if item is affected",
                "customer_image_url": "dented_box.jpg",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["vision_match_score"] == 0.70
    assert data["ticket_status"] == "manual_review"


# --- Additional coverage tests ---


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
    messages = _build_messages("item is damaged", {"match_confidence": 0.5, "damage_detected": False})
    assert len(messages) == 2
    assert messages[0]["role"] == "system"
    assert messages[1]["role"] == "user"
    assert "item is damaged" in messages[1]["content"]
    assert "0.5" in messages[1]["content"]
    # Verify Sovereign Audit Agent framing
    assert "Sovereign Audit Agent" in messages[0]["content"]
    assert "Item Integrity" in messages[0]["content"]


@pytest.mark.asyncio
async def test_call_glm_success_mocked():
    """Test call_glm with mocked HTTP returning valid JSON."""
    from app.services.glm_client import call_glm

    mock_response = MagicMock()
    mock_response.raise_for_status = MagicMock()
    mock_response.json.return_value = {
        "choices": [{"message": {"content": '{"action": "refund", "reason": "test", "confidence": 0.9}'}}]
    }

    mock_client = AsyncMock()
    mock_client.post = AsyncMock(return_value=mock_response)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("app.services.glm_client.httpx.AsyncClient", return_value=mock_client):
        result = await call_glm("item damaged", {"match_confidence": 0.9})

    assert result["action"] == "refund"
    assert result["confidence"] == 0.9


@pytest.mark.asyncio
async def test_call_glm_markdown_fence_stripping():
    """Test that markdown code fences are stripped from GLM response."""
    from app.services.glm_client import call_glm

    mock_response = MagicMock()
    mock_response.raise_for_status = MagicMock()
    mock_response.json.return_value = {
        "choices": [{"message": {"content": '```json\n{"action": "escalate", "reason": "low match", "confidence": 0.2}\n```'}}]
    }

    mock_client = AsyncMock()
    mock_client.post = AsyncMock(return_value=mock_response)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("app.services.glm_client.httpx.AsyncClient", return_value=mock_client):
        result = await call_glm("fake claim", {"match_confidence": 0.2})

    assert result["action"] == "escalate"
    assert result["confidence"] == 0.2


@pytest.mark.asyncio
async def test_call_glm_timeout_fallback():
    """Test call_glm falls back to escalate on timeout."""
    import httpx
    from app.services.glm_client import call_glm

    mock_client = AsyncMock()
    mock_client.post = AsyncMock(side_effect=httpx.TimeoutException("timeout"))
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("app.services.glm_client.httpx.AsyncClient", return_value=mock_client):
        result = await call_glm("item damaged", {"match_confidence": 0.9})

    assert result["action"] == "escalate"
    assert "failed" in result["reason"].lower() or "timed out" in result["reason"].lower()


@pytest.mark.asyncio
async def test_call_glm_json_decode_error_fallback():
    """Test call_glm falls back on invalid JSON in response content."""
    from app.services.glm_client import call_glm

    mock_response = MagicMock()
    mock_response.raise_for_status = MagicMock()
    mock_response.json.return_value = {
        "choices": [{"message": {"content": "this is not valid json"}}]
    }

    mock_client = AsyncMock()
    mock_client.post = AsyncMock(return_value=mock_response)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("app.services.glm_client.httpx.AsyncClient", return_value=mock_client):
        result = await call_glm("item damaged", {"match_confidence": 0.9})

    assert result["action"] == "escalate"


@pytest.mark.asyncio
async def test_audit_logs_endpoint(client, seed_data):
    """Test GET /api/audit-logs returns logs after orchestration."""
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

    # Point seed at test DB so it doesn't hit real PostgreSQL
    original_url = _db_mod.DATABASE_URL
    _db_mod.DATABASE_URL = "sqlite:///./test_seed_check.db"
    _db_mod.engine = create_engine(_db_mod.DATABASE_URL, connect_args={"check_same_thread": False})
    _db_mod.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=_db_mod.engine)
    _db_mod.Base.metadata.create_all(bind=_db_mod.engine)

    from app import seed as seed_mod
    importlib.reload(seed_mod)

    # Restore
    _db_mod.DATABASE_URL = original_url
    _db_mod.engine = create_engine(_db_mod.DATABASE_URL, connect_args={"check_same_thread": False} if original_url.startswith("sqlite") else {})
    _db_mod.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=_db_mod.engine)


def test_get_db_generator():
    """Test get_db yields a session and closes it."""
    from app.database import get_db, SessionLocal
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
