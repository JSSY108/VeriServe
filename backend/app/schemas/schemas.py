from pydantic import BaseModel, Field


# --- Request Schemas ---

class OrchestrateRequest(BaseModel):
    order_id: int
    user_category_selection: str | None = None
    complaint_text: str
    customer_image_url: str


class VisionVerifyRequest(BaseModel):
    customer_image_url: str
    pod_image_url: str


class RefundRequest(BaseModel):
    order_id: int
    amount: float


# --- Response Schemas ---

class VisionVerifyResponse(BaseModel):
    match_confidence: float
    damage_detected: bool
    damage_type: str | None = None


class RefundResponse(BaseModel):
    status: str
    tx_id: str


class TraceEntry(BaseModel):
    agent: str
    action: str
    result: str


class MultiAgentDecision(BaseModel):
    trace_log: list[TraceEntry]
    final_action: str = Field(..., pattern="^(APPROVE_REFUND|MANUAL_ESCALATION|REJECT_FRAUD)$")
    confidence_score: float


class OrchestrateResponse(BaseModel):
    ticket_id: int
    ticket_status: str
    vision_match_score: float
    glm_decision: MultiAgentDecision
    rider_pod_url: str | None = None
