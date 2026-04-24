# VeriServe — UMHackathon 2026

## Project Overview
VeriServe is a **multi-tenant logistics verification SaaS**. Customers submit complaints with images; a mock vision API compares the image to the rider's proof-of-delivery photo; ilmu-glm-5.1 (Z.AI GLM) reasons over Item Integrity and orchestrates either an automatic refund (>85% match) or manual review escalation. Supports Food, Electronics, and Apparel categories across merchants like Grab, Zalora, and DHL.

## Tech Stack
- **Backend:** FastAPI + SQLAlchemy + PostgreSQL
- **Frontend:** Flutter
- **AI Engine:** ilmu-glm-5.1 via ilmu.ai gateway (sole reasoning engine — no other LLMs)
- **External APIs:** All mocked as internal FastAPI endpoints (Stripe, Vision, Slack)

## Priority Matrix
1. **Correctness** — Orchestration logic matches PRD rules exactly (85% threshold, manual_review fallback)
2. **Test Coverage** — Minimum 81.2% (CI hard gate)
3. **Performance** — API latency < 800ms average (TC-03)
4. **Resilience** — GLM timeout/Pydantic failure defaults to `manual_review`, never 500

## NFR Thresholds
| Metric | Threshold |
|---|---|
| `/api/orchestrate` avg latency | < 800ms |
| Test coverage | >= 81.2% |
| GLM API timeout | 15 seconds |
| Customer claim word limit | 800 words (truncate) |
| Vision match refund threshold | > 85% |

## TDD Workflow
- Write tests BEFORE implementation logic.
- Tests: TC-01 (happy path refund), TC-02 (fraud prevention), TC-03 (latency), TC-04 (GLM timeout fallback).
- Plus multi-tenant scenarios: Food (smashed), Electronics (crushed), Apparel (torn).
- Run `pytest` before every commit (pre-commit hook).

## Key Constraints
- Hardcoded user `user_123` for testing — no auth system.
- Static placeholder image URLs — no S3/file upload.
- No profile/settings pages.
- All external integrations are mock endpoints.

## GLM Integration Rules
- Token limit: truncate `customer_claim` > 800 words before sending.
- Wrap GLM call in try/except with 15-second timeout.
- On timeout or Pydantic validation failure → default ticket to `manual_review`.
- Strip markdown code fences (` ```json ... ``` `) from GLM response before JSON parsing.
- API: `https://api.ilmu.ai/v1/chat/completions`, model `ilmu-glm-5.1`, Bearer token auth.

## Architecture
- See SAD.md for DB schema (3NF) and API contracts.
- See QATD.md for test specifications and CI requirements.
- See docs/QATD_AGENT.md for actual test results.
