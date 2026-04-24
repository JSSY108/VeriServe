# AGENT COMMAND SAD: System Architecture & Schemas
**CRITICAL INSTRUCTION FOR CLAUDE:** Use these exact schemas and endpoint contracts. You must implement Pydantic validation for ALL GLM outputs.

## 1. Database Schema (PostgreSQL 3NF)
Create the following tables via SQL/ORM (SQLAlchemy/SQLModel):
* `Users`: `id`, `role` (customer, admin).
* `Orders`: `id`, `customer_id`, `amount`, `rider_pod_image_url`, `status` (delivered, refunded).
* `Tickets`: `id`, `order_id`, `customer_claim_text`, `customer_image_url`, `vision_match_score`, `status` (pending, refunded, manual_review).
* `Audit_Logs`: `id`, `ticket_id`, `action` (vision_check, glm_reasoning, refund_triggered), `timestamp`, `raw_json`.

## 2. API Endpoints to Scaffold (FastAPI)
### Mock Endpoints
* `POST /api/mock/vision/verify`
  - **Input:** `{"customer_image_url": "...", "pod_image_url": "..."}`
  - **Behavior:** Hardcode logic for testing. If `customer_image_url` contains "smashed", return `{"match_confidence": 0.95, "damage_detected": true}`. If it contains "fake", return `{"match_confidence": 0.10, "damage_detected": false}`.
* `POST /api/mock/stripe/refund`
  - **Input:** `{"order_id": int, "amount": float}`
  - **Behavior:** Updates `Orders` table status to 'refunded'. Returns `{"status": "success", "tx_id": "mock_999"}`.

### Core Orchestration Endpoint
* `POST /api/orchestrate`
  - **Input:** `{"order_id": int, "customer_claim": str, "customer_image_url": str}`
  - **Behavior:** 1. Fetch `Orders` data.
    2. Call `/api/mock/vision/verify`.
    3. Construct prompt for Z.AI GLM containing claim + vision JSON.
    4. Parse GLM JSON response using Pydantic. 
    5. Execute GLM's chosen tool (Refund or Escalate).
    6. Log everything to `Audit_Logs`.

## 3. GLM Integration Rules
* **Token Limits:** If `customer_claim` > 800 words, truncate it before sending to GLM.
* **Resilience:** Wrap the GLM API call in a `try/except` block with a 5-second timeout. On timeout or Pydantic validation failure, default ticket status to `manual_review` to prevent 500 errors.