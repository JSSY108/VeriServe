# AGENT COMMAND PRD: VeriServe — Multi-Tenant Logistics Verification SaaS

**CRITICAL INSTRUCTION FOR CLAUDE:** You are building a prototype for a 48-hour hackathon. Speed, strict adherence to these requirements, and Test-Driven Development (TDD) are your priorities. Do NOT build features not explicitly listed here.

## 1. Core Architecture Constraints

* **Tech Stack:** FastAPI (Backend), Flutter (Frontend), PostgreSQL (Database).
* **AI Engine Constraint:** Z.AI's GLM (via ilmu.ai gateway) acts as the central reasoning engine. It MUST control the orchestration. Do NOT use any other LLM for reasoning.
* **External Tools:** ALL external tools (Stripe, Vision APIs, Slack) MUST be mocked as internal FastAPI endpoints. Do NOT attempt real OAuth or third-party integrations.
* **API Gateway:** ilmu.ai (`https://api.ilmu.ai/v1/chat/completions`), model `ilmu-glm-5.1`, Bearer token auth.

## 2. Product Definition

VeriServe is a **Third-Party Verification SaaS for the logistics industry**. It audits delivery disputes across merchants and categories — not limited to food delivery. The GLM acts as a **Sovereign Audit Agent** that reasons over **Item Integrity** using three signals: (1) Customer Photo, (2) Rider Proof-of-Delivery Photo, (3) Rider Identity.

### Supported Categories
| Category | Example Merchants | Claim Types |
|---|---|---|
| Food | Grab, Foodpanda | Damaged packaging, compromised items |
| Electronics | Zalora, Shopee | Crushed box, dented packaging |
| Apparel | DHL, PosLaju | Torn courier bag, stained items |

## 3. Minimum Viable Product (MVP) Features to Build

1. **Unstructured Ingestion:** A Flutter UI to submit a complaint (Text) + Image URL (String) against an order.
2. **Stateful Verification (The Core Loop):**
   - User submits complaint for `order_id`.
   - System fetches `rider_pod_image_url` from DB.
   - System sends both images to `mock_vision_api`.
   - `mock_vision_api` returns JSON with `match_confidence`, `damage_detected`, and `damage_type`.
3. **Agentic Orchestration:**
   - ilmu-glm-5.1 ingests the customer text + the vision JSON.
   - GLM decides: If match > 85%, trigger `mock_refund_api`. If match < 85%, escalate to manual review.
   - GLM reasons over Item Integrity, not food quality.
4. **God Mode UI (Trace Dashboard):** A secondary Flutter view that displays the live backend logs, DB state changes, and the GLM's JSON reasoning trace in real-time.

## 4. Mock Vision API Scenarios

The vision mock MUST handle multi-category scenarios:

| Keyword in `customer_image_url` | Match Confidence | Damage Detected | Damage Type |
|---|---|---|---|
| smashed | 0.95 | true | Damaged packaging — food items compromised |
| soggy | 0.88 | true | Moisture damage to food packaging |
| crushed | 0.92 | true | Crushed box — electronics integrity at risk |
| dented | 0.70 | true | Dented packaging — possible impact damage |
| torn | 0.90 | true | Torn courier bag — apparel exposed |
| stained | 0.75 | true | Stain detected on packaging |
| fake | 0.10 | false | No damage detected — claim unverifiable |
| (default) | 0.50 | false | Inconclusive — requires manual inspection |

## 5. STRICTLY OUT OF SCOPE (Do Not Build)

* User authentication/login (Hardcode a user `user_123` for testing).
* Real file uploading to S3 (Just use static placeholder URLs for images).
* Complex profile management or settings pages.
