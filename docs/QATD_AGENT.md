# QATD Agent Results — VeriServe (Multi-Tenant SaaS + 3-Persona Multi-Agent)

## Test Execution Summary

| Metric | Threshold | Actual Result | Status |
|---|---|---|---|
| Test Coverage | >= 81.2% | **96.0%** (21 tests) | PASS |
| `/api/orchestrate` avg latency | < 800ms | **12.6ms** (50 requests, GLM mocked) | PASS |
| GLM API timeout | 45s (with retry) | 45s | PASS |
| All test cases | 21/21 pass | 21/21 pass | PASS |

## Multi-Tenant Live Verification (ilmu-glm-5.1)

| Scenario | Merchant | Category | Image Keyword | Vision Score | GLM Action | Ticket Status | Result |
|---|---|---|---|---|---|---|---|
| A — Smashed pizza box | Grab | Food | smashed | 0.95 | APPROVE_REFUND | refunded | PASS |
| B — Crushed laptop box | Zalora | Electronics | crushed | 0.92 | APPROVE_REFUND | refunded | PASS |
| C — Torn courier bag | DHL | Apparel | torn | 0.90 | APPROVE_REFUND | refunded | PASS |
| Fraud — Fake claim | — | — | fake | 0.10 | MANUAL_ESCALATION | manual_review | PASS |
| Fraud — Category mismatch | Grab | Food vs Electronics | crushed | 0.92 | REJECT_FRAUD | fraud_rejected | PASS (mocked) |

## Test Case Results

| Test Case | Description | Actual Result | Status |
|---|---|---|---|
| TC-01 | Happy path — APPROVE_REFUND triggers refund | Returns 200, ticket_status=refunded, trace_log with 3 agents | PASS |
| TC-02 | Fraud prevention — MANUAL_ESCALATION | Returns 200, ticket_status=manual_review, order NOT refunded | PASS |
| TC-03 | Performance latency — avg < 800ms over 50 requests | Avg=12.6ms | PASS |
| TC-04 | GLM timeout fallback — defaults to MANUAL_ESCALATION | Returns 200, ticket_status=manual_review | PASS |
| TC-05 | Scenario A: Food (Grab) — smashed | vision=0.95, APPROVE_REFUND | PASS |
| TC-06 | Scenario B: Electronics (Zalora) — crushed | vision=0.92, APPROVE_REFUND | PASS |
| TC-07 | Scenario C: Apparel (DHL) — torn | vision=0.90, APPROVE_REFUND | PASS |
| TC-08 | Dented packaging — MANUAL_ESCALATION | vision=0.70, manual_review | PASS |
| TC-09 | Category mismatch — REJECT_FRAUD | Ingestor detects mismatch, fraud_rejected | PASS |
| TC-10 | Claim truncation under 800-word limit | Full text returned | PASS |
| TC-11 | Claim truncation over 800-word limit | Truncated to 800 words | PASS |
| TC-12 | _build_messages — 3-persona system prompt | Contains Ingestor/Investigator/Auditor, merchant_config in user message | PASS |
| TC-13 | GLM success with mocked HTTP | Returns trace_log + APPROVE_REFUND | PASS |
| TC-14 | GLM markdown fence stripping | Code fences stripped, JSON parsed | PASS |
| TC-15 | GLM timeout fallback via HTTP mock | Returns MANUAL_ESCALATION with error trace | PASS |
| TC-16 | GLM invalid JSON fallback | Returns MANUAL_ESCALATION | PASS |
| TC-17 | Audit logs endpoint | GET /api/audit-logs returns logs | PASS |
| TC-18 | Vision mock — all 8 scenarios | All keywords return correct confidence + damage_type | PASS |
| TC-19 | Seed module execution | seed.py runs (4 merchants with auto_refund_limit) | PASS |
| TC-20 | get_db generator | Yields session, closes cleanly | PASS |
| TC-21 | Health endpoint | GET /health returns {"status": "ok"} | PASS |

## Latency Breakdown (TC-03)

| Stat | Value |
|---|---|
| Average | 12.6ms |
| Min | 10.8ms |
| Max | 25.7ms |
| Sample size | 50 requests |
| GLM mocked | Yes (per QATD spec) |

## Coverage Breakdown

| Module | Stmts | Miss | Cover |
|---|---|---|---|
| app/__init__.py | 0 | 0 | 100% |
| app/database.py | 14 | 0 | 100% |
| app/main.py | 17 | 2 | 88% |
| app/models/__init__.py | 2 | 0 | 100% |
| app/models/models.py | 43 | 0 | 100% |
| app/routers/__init__.py | 0 | 0 | 100% |
| app/routers/mock.py | 21 | 0 | 100% |
| app/routers/orchestrate.py | 51 | 0 | 100% |
| app/schemas/__init__.py | 2 | 0 | 100% |
| app/schemas/schemas.py | 32 | 0 | 100% |
| app/seed.py | 21 | 8 | 62% |
| app/services/__init__.py | 0 | 0 | 100% |
| app/services/glm_client.py | 28 | 0 | 100% |
| **TOTAL** | **231** | **10** | **96.0%** |

## Remaining Uncovered Lines

- `app/main.py:13-14` — lifespan context (requires full ASGI lifecycle test)
- `app/seed.py` — idempotency checks and error branch

## Schema Changes (Multi-Agent Upgrade)

| Table | Field | Type | Purpose |
|---|---|---|---|
| merchant_config | id | Integer PK | Auto-increment |
| merchant_config | merchant_name | String(100) unique | e.g. "Grab", "Zalora", "DHL", "Shopee" |
| merchant_config | auto_refund_limit | Float | RM threshold for auto-refund |

### New Pydantic Schemas

| Schema | Fields |
|---|---|
| OrchestrateRequest | order_id, user_category_selection (optional), complaint_text, customer_image_url |
| TraceEntry | agent, action, result |
| MultiAgentDecision | trace_log (list[TraceEntry]), final_action (APPROVE_REFUND/MANUAL_ESCALATION/REJECT_FRAUD), confidence_score |
| OrchestrateResponse | ticket_id, ticket_status, vision_match_score, glm_decision (MultiAgentDecision) |

### Merchant Config Seed Data

| Merchant | Auto-Refund Limit (RM) |
|---|---|
| Grab | 50.00 |
| Zalora | 500.00 |
| DHL | 100.00 |
| Shopee | 50.00 |

## GLM Resilience

- Timeout: 45 seconds
- Retry: 1 automatic retry on timeout/HTTP error
- Fallback: Returns MANUAL_ESCALATION with error trace_log on failure
- Markdown fence stripping: handles ` ```json ... ``` ` wrapping
