import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import ValidationError

from app.database import get_db
from app.models import Order, Ticket, AuditLog
from app.schemas import OrchestrateRequest, OrchestrateResponse, GLMDecision
from app.services.glm_client import call_glm
from app.routers.mock import vision_verify as _vision_logic
from app.schemas import VisionVerifyRequest

router = APIRouter(prefix="/api", tags=["orchestration"])


@router.post("/orchestrate", response_model=OrchestrateResponse)
async def orchestrate(req: OrchestrateRequest, db: Session = Depends(get_db)):
    # 1. Fetch order
    order = db.query(Order).filter(Order.id == req.order_id).first()

    # 2. Call mock vision API
    vision_req = VisionVerifyRequest(
        customer_image_url=req.customer_image_url,
        pod_image_url=order.rider_pod_image_url if order else "",
    )
    vision_result = _vision_logic(vision_req)
    vision_json = {
        "match_confidence": vision_result.match_confidence,
        "damage_detected": vision_result.damage_detected,
        "damage_type": vision_result.damage_type,
    }

    # 3. Create ticket
    ticket = Ticket(
        order_id=req.order_id,
        customer_claim_text=req.customer_claim,
        customer_image_url=req.customer_image_url,
        vision_match_score=vision_result.match_confidence,
        status="pending",
    )
    db.add(ticket)
    db.commit()
    db.refresh(ticket)

    # 4. Log vision check
    db.add(AuditLog(ticket_id=ticket.id, action="vision_check", raw_json=json.dumps(vision_json)))
    db.commit()

    # 5. Call GLM
    try:
        glm_raw = await call_glm(req.customer_claim, vision_json)
        glm_decision = GLMDecision(**glm_raw)
    except (ValidationError, Exception):
        glm_decision = GLMDecision(action="escalate", reason="GLM response invalid", confidence=0.0)
        ticket.status = "manual_review"

    # 6. Log GLM reasoning
    db.add(AuditLog(
        ticket_id=ticket.id,
        action="glm_reasoning",
        raw_json=json.dumps(glm_decision.model_dump()),
    ))
    db.commit()

    # 7. Execute GLM decision
    if glm_decision.action == "refund":
        from app.routers.mock import stripe_refund as _refund_logic
        refund_req = type("RefundRequest", (), {"order_id": req.order_id, "amount": order.amount if order else 0.0})()
        _refund_logic(refund_req, db=db)
        ticket.status = "refunded"
        db.add(AuditLog(ticket_id=ticket.id, action="refund_triggered", raw_json=json.dumps({"order_id": req.order_id})))
    else:
        ticket.status = "manual_review"

    db.commit()
    db.refresh(ticket)

    return OrchestrateResponse(
        ticket_id=ticket.id,
        ticket_status=ticket.status,
        vision_match_score=vision_result.match_confidence,
        glm_decision=glm_decision,
    )


@router.get("/audit-logs")
def get_audit_logs(db: Session = Depends(get_db)):
    logs = db.query(AuditLog).order_by(AuditLog.timestamp.desc()).limit(100).all()
    return [
        {
            "id": log.id,
            "ticket_id": log.ticket_id,
            "action": log.action,
            "timestamp": log.timestamp.isoformat() if log.timestamp else None,
            "raw_json": json.loads(log.raw_json) if log.raw_json else None,
        }
        for log in logs
    ]
