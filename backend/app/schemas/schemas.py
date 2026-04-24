from pydantic import BaseModel, Field


# --- Request Schemas ---

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


# --- Response Schemas ---

class VisionVerifyResponse(BaseModel):
    match_confidence: float
    damage_detected: bool
    damage_type: str | None = None


class RefundResponse(BaseModel):
    status: str
    tx_id: str


class GLMDecision(BaseModel):
    action: str = Field(..., pattern="^(refund|escalate)$")
    reason: str
    confidence: float


class OrchestrateResponse(BaseModel):
    ticket_id: int
    ticket_status: str
    vision_match_score: float
    glm_decision: GLMDecision
