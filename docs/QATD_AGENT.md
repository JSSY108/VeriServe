# QATD Agent Results — VeriServe (Multi-Tenant SaaS)

## Test Execution Summary

| Metric | Threshold | Actual Result | Status |
|---|---|---|---|
| Test Coverage | >= 81.2% | **95.0%** (20 tests) | PASS |
| `/api/orchestrate` avg latency | < 800ms | **12.6ms** (50 requests, GLM mocked) | PASS |
| GLM API timeout | 15s (ilmu.ai) | 15s | PASS |
| All test cases | 20/20 pass | 20/20 pass | PASS |

## Multi-Tenant Live Verification (ilmu-glm-5.1)

| Scenario | Merchant | Category | Image Keyword | Vision Score | GLM Action | Ticket Status | Result |
|---|---|---|---|---|---|---|---|
| A — Smashed pizza box | Grab | Food | smashed | 0.95 | refund | refunded | PASS |
| B — Crushed laptop box | Zalora | Electronics | crushed | 0.92 | refund | refunded | PASS |
| C — Torn courier bag | DHL | Apparel | torn | 0.90 | refund | refunded | PASS |
| Fraud — Fake claim | — | — | fake | 0.10 | escalate | manual_review | PASS |

## Test Case Results

| Test Case | Description | Actual Result | Status |
|---|---|---|---|
| TC-01 | Happy path refund — high-confidence match triggers auto-refund | Returns 200, ticket_status=refunded, vision_match_score=0.95, GLM action=refund | PASS |
| TC-02 | Fraud prevention — low-confidence match escalates to manual review | Returns 200, ticket_status=manual_review, vision_match_score=0.10, GLM action=escalate | PASS |
| TC-03 | Performance latency — avg response < 800ms over 50 requests | Avg=12.6ms, Min=10.8ms, Max=25.7ms (GLM mocked) | PASS |
| TC-04 | GLM timeout fallback — invalid GLM response defaults to manual_review | Returns 200, ticket_status=manual_review (no 500 error) | PASS |
| TC-05 | Scenario A: Food (Grab) — smashed pizza box | vision_match_score=0.95, GLM action=refund | PASS |
| TC-06 | Scenario B: Electronics (Zalora) — crushed laptop box | vision_match_score=0.92, GLM action=refund | PASS |
| TC-07 | Scenario C: Apparel (DHL) — torn courier bag | vision_match_score=0.90, GLM action=refund | PASS |
| TC-08 | Dented packaging (0.70 confidence) escalates | vision_match_score=0.70, ticket_status=manual_review | PASS |
| TC-09 | Claim truncation under 800-word limit | Full text returned unchanged | PASS |
| TC-10 | Claim truncation over 800-word limit | Truncated to exactly 800 words | PASS |
| TC-11 | GLM message builder — Sovereign Audit Agent framing | 2 messages, system prompt contains "Sovereign Audit Agent" and "Item Integrity" | PASS |
| TC-12 | GLM success with mocked HTTP | Returns parsed JSON with action=refund | PASS |
| TC-13 | GLM markdown fence stripping | Code fences stripped, JSON parsed correctly | PASS |
| TC-14 | GLM timeout fallback via HTTP mock | Returns escalate on TimeoutException | PASS |
| TC-15 | GLM invalid JSON fallback | Returns escalate on JSONDecodeError | PASS |
| TC-16 | Audit logs endpoint | GET /api/audit-logs returns list of logs | PASS |
| TC-17 | Vision mock — all 8 scenarios | smashed(0.95), soggy(0.88), crushed(0.92), dented(0.70), torn(0.90), stained(0.75), fake(0.10), default(0.50) with damage_type | PASS |
| TC-18 | Seed module execution | seed.py runs without error (3 merchants) | PASS |
| TC-19 | get_db generator | Yields session and closes cleanly | PASS |
| TC-20 | Health endpoint | GET /health returns {"status": "ok"} | PASS |

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
| app/models/models.py | 38 | 0 | 100% |
| app/routers/__init__.py | 0 | 0 | 100% |
| app/routers/mock.py | 21 | 0 | 100% |
| app/routers/orchestrate.py | 46 | 0 | 100% |
| app/schemas/__init__.py | 2 | 0 | 100% |
| app/schemas/schemas.py | 27 | 0 | 100% |
| app/seed.py | 18 | 8 | 56% |
| app/services/__init__.py | 0 | 0 | 100% |
| app/services/glm_client.py | 26 | 0 | 100% |
| **TOTAL** | **211** | **10** | **95.0%** |

## Remaining Uncovered Lines

- `app/main.py:13-14` — lifespan context (requires full ASGI lifecycle test)
- `app/seed.py:10,14-49` — idempotency checks and error branch in seed

## Schema Changes (Multi-Tenant Pivot)

| Table | Field | Type | Purpose |
|---|---|---|---|
| Orders | merchant_name | String(100) | e.g. "Grab", "Zalora", "DHL" |
| Orders | category | String(50) | e.g. "Food", "Electronics", "Apparel" |
| VisionVerifyResponse | damage_type | String (optional) | e.g. "Crushed box — electronics integrity at risk" |

## Vision Mock Scenarios

| Keyword | Confidence | Damage Detected | Damage Type |
|---|---|---|---|
| smashed | 0.95 | true | Damaged packaging — food items compromised |
| soggy | 0.88 | true | Moisture damage to food packaging |
| crushed | 0.92 | true | Crushed box — electronics integrity at risk |
| dented | 0.70 | true | Dented packaging — possible impact damage |
| torn | 0.90 | true | Torn courier bag — apparel exposed |
| stained | 0.75 | true | Stain detected on packaging |
| fake | 0.10 | false | No damage detected — claim unverifiable |
| (default) | 0.50 | false | Inconclusive — requires manual inspection |
