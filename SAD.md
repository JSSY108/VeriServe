# AGENT COMMAND SAD: System Architecture & Schemas — Multi-Tenant Logistics Verification SaaS

**CRITICAL INSTRUCTION FOR CLAUDE:** Use these exact schemas and endpoint contracts. You must implement Pydantic validation for ALL GLM outputs.

## 1. Database Schema (PostgreSQL 3NF)

Create the following tables via SQL/ORM (SQLAlchemy/SQLModel):

### `Users`
| Column | Type | Constraints |
|---|---|---|
| id | Integer | PK, index |
| role | String(20) | NOT NULL |

### `Orders`
| Column | Type | Constraints |
|---|---|---|
| id | Integer | PK, index |
| customer_id | Integer | FK → Users.id, NOT NULL |
| merchant_name | String(100) | NOT NULL (e.g. "Grab", "Zalora", "DHL") |
| category | String(50) | NOT NULL (e.g. "Food", "Electronics", "Apparel") |
| amount | Float | NOT NULL |
| rider_pod_image_url | Text | NOT NULL |
| status | String(20) | NOT NULL, default "delivered" |

### `Tickets`
| Column | Type | Constraints |
|---|---|---|
| id | Integer | PK, index |
| order_id | Integer | FK → Orders.id, NOT NULL |
| customer_claim_text | Text | NOT NULL |
| customer_image_url | Text | NOT NULL |
| vision_match_score | Float | nullable |
| status | String(20) | NOT NULL, default "pending" |

**Ticket status flow:** `pending` → `refunded` | `manual_review`

### `Audit_Logs`
| Column | Type | Constraints |
|---|---|---|
| id | Integer | PK, index |
| ticket_id | Integer | FK → Tickets.id, NOT NULL |
| action | String(30) | NOT NULL (`vision_check`, `glm_reasoning`, `refund_triggered`) |
| timestamp | DateTime | NOT NULL, default UTC now |
| raw_json | Text | nullable |

## 2. API Endpoints (FastAPI)

### Mock Endpoints

#### `POST /api/mock/vision/verify`
- **Input:** `{"customer_image_url": "...", "pod_image_url": "..."}`
- **Output:** `{"match_confidence": float, "damage_detected": bool, "damage_type": str | null}`
- **Behavior:** Keyword-based matching (see PRD §4). Returns `damage_type` description for transparency.

#### `POST /api/mock/stripe/refund`
- **Input:** `{"order_id": int, "amount": float}`
- **Output:** `{"status": "success", "tx_id": "mock_999"}`
- **Behavior:** Updates `Orders` table status to 'refunded'.

### Core Orchestration Endpoint

#### `POST /api/orchestrate`
- **Input:** `{"order_id": int, "customer_claim": str, "customer_image_url": str}`
- **Behavior:**
  1. Fetch `Orders` data (includes `merchant_name`, `category`).
  2. Call `/api/mock/vision/verify` → get `match_confidence`, `damage_detected`, `damage_type`.
  3. Create `Tickets` row (status=pending).
  4. Log vision check to `Audit_Logs`.
  5. Construct prompt for ilmu-glm-5.1 containing claim + vision JSON (including `damage_type`).
  6. Parse GLM JSON response using Pydantic (`GLMDecision`).
  7. Execute GLM's chosen tool (Refund or Escalate).
  8. Log everything to `Audit_Logs`.

#### `GET /api/audit-logs`
- **Output:** Array of audit log entries (most recent 100), with `raw_json` parsed.

### Health Check
#### `GET /health`
- **Output:** `{"status": "ok"}`

## 3. Pydantic Schemas

### Request Schemas
```python
class OrchestrateRequest(BaseModel):
    order_id: int
    customer_claim: str
    customer_image_url: str

class VisionVerifyRequest(BaseModel):
    customer_image_url: str
    pod_image_url: str

class RefundRequest(BaseModel):
    order_id: int
    amount: float
```

### Response Schemas
```python
class VisionVerifyResponse(BaseModel):
    match_confidence: float
    damage_detected: bool
    damage_type: str | None = None

class RefundResponse(BaseModel):
    status: str
    tx_id: str

class GLMDecision(BaseModel):
    action: str       # "refund" | "escalate"
    reason: str
    confidence: float  # 0.0–1.0

class OrchestrateResponse(BaseModel):
    ticket_id: int
    ticket_status: str
    vision_match_score: float
    glm_decision: GLMDecision
```

## 4. GLM Integration Rules

### API Configuration
| Parameter | Value |
|---|---|
| Base URL | `https://api.ilmu.ai/v1/chat/completions` |
| Model | `ilmu-glm-5.1` |
| Auth | `Authorization: Bearer <ILMU_API_KEY>` |
| Timeout | 15 seconds |
| Temperature | 0.7 |
| Response Format | `{"type": "json_object"}` |

### System Prompt (Sovereign Audit Agent)
```
You are a Sovereign Audit Agent for a third-party logistics verification SaaS.
Your role is to audit delivery disputes by reasoning over Item Integrity —
assessing whether the delivered item matches the expected condition based on:
(1) Customer Photo, (2) Rider Proof-of-Delivery Photo, (3) Rider Identity.
You handle claims across all industries: Food, Electronics, Apparel, and beyond.
Claim types include 'Damaged' and 'Missing Item'.
If the vision match confidence > 0.85 and damage is detected, choose 'refund'.
Otherwise, choose 'escalate' for manual review.
You MUST respond with valid JSON only:
{"action": "refund"|"escalate", "reason": "...", "confidence": 0.0-1.0}
```

### Resilience Rules
- **Token Limits:** If `customer_claim` > 800 words, truncate before sending to GLM.
- **Markdown Fences:** GLM may wrap JSON in ` ```json ... ``` ` — strip before parsing.
- **Fallback:** Wrap GLM API call in try/except with 15-second timeout. On timeout or Pydantic validation failure, default ticket status to `manual_review` to prevent 500 errors.

## 5. Seed Data

| Order ID | Merchant | Category | Amount | POD Image |
|---|---|---|---|---|
| 1 | Grab | Food | 25.99 | rider_pod_grab_food.jpg |
| 2 | Zalora | Electronics | 499.00 | rider_pod_zalora_electronics.jpg |
| 3 | DHL | Apparel | 89.50 | rider_pod_dhl_apparel.jpg |

All orders belong to `user_123` (User id=1, role=customer).

## 6. Docker Infrastructure

| Service | Image | Port | Notes |
|---|---|---|---|
| postgres | postgres:16-alpine | 5432 | DB: veriserve, user: veriserve |
| backend | python:3.12-slim | 8000 | FastAPI + uvicorn, seeds on start |

Environment variables passed via `.env`:
- `GLM_API_KEY` — ilmu.ai Bearer token
- `GLM_API_URL` — `https://api.ilmu.ai/v1/chat/completions`
- `DATABASE_URL` — `postgresql://veriserve:veriserve_dev@postgres:5432/veriserve`
