# AGENT COMMAND PRD: VeriServe
**CRITICAL INSTRUCTION FOR CLAUDE:** You are building a prototype for a 48-hour hackathon. Speed, strict adherence to these requirements, and Test-Driven Development (TDD) are your priorities. Do NOT build features not explicitly listed here.

## 1. Core Architecture Constraints
* **Tech Stack:** FastAPI (Backend), Flutter (Frontend), PostgreSQL (Database).
* [cite_start]**AI Engine Constraint:** Z.AI's GLM acts as the central reasoning engine[cite: 194]. It MUST control the orchestration. Do NOT use any other LLM for reasoning. 
* **External Tools:** ALL external tools (Stripe, Vision APIs, Slack) MUST be mocked as internal FastAPI endpoints. Do NOT attempt real OAuth or third-party integrations.

## 2. Minimum Viable Product (MVP) Features to Build
1. **Unstructured Ingestion:** A Flutter UI to submit a complaint (Text) + Image URL (String).
2. **Stateful Verification (The Core Loop):**
   - User submits complaint for `order_id`.
   - System fetches `rider_pod_image_url` from DB.
   - System sends both images to a `mock_vision_api`.
   - `mock_vision_api` returns a JSON payload detailing damage match confidence.
3. **Agentic Orchestration:**
   - Z.AI GLM ingests the user text + the vision JSON.
   - GLM decides: If match > 85%, trigger `mock_refund_api`. [cite_start]If match < 85%, escalate to manual review. [cite: 203]
4. **God Mode UI (Trace Dashboard):** A secondary Flutter view that displays the live backend logs, DB state changes, and the GLM's JSON reasoning trace in real-time.

## 3. STRICTLY OUT OF SCOPE (Do Not Build)
* User authentication/login (Hardcode a user `user_123` for testing).
* Real file uploading to S3 (Just use static placeholder URLs for images).
* Complex profile management or settings pages.