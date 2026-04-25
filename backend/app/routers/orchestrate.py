import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session, joinedload
from pydantic import ValidationError

from app.database import get_db
from app.models import Order, Ticket, AuditLog, MerchantConfig
from app.schemas import OrchestrateRequest, OrchestrateResponse, MultiAgentDecision
from app.services.glm_client import call_glm
from app.routers.mock import vision_verify as _vision_logic
from app.schemas import VisionVerifyRequest

router = APIRouter(prefix="/api", tags=["orchestration"])


# ── Status mapping: backend ticket status → frontend ClaimStatus ──

_STATUS_MAP = {
    "pending": "submitted",
    "refunded": "resolved",
    "manual_review": "escalated",
    "fraud_rejected": "denied",
}


def _risk_level(vision_score: float | None) -> str:
    if vision_score is None:
        return "medium"
    if vision_score >= 0.85:
        return "low"
    if vision_score >= 0.50:
        return "medium"
    return "high"


def _claim_row(ticket: Ticket, order: Order | None) -> dict:
    status = _STATUS_MAP.get(ticket.status, "submitted")
    return {
        "id": f"CLM-{ticket.id:03d}",
        "orderId": str(order.id) if order else str(ticket.order_id),
        "merchant": order.merchant_name if order else "Unknown",
        "category": order.category if order else "General",
        "description": ticket.customer_claim_text,
        "evidenceUrls": [ticket.customer_image_url] if ticket.customer_image_url else [],
        "status": status,
        "riskLevel": _risk_level(ticket.vision_match_score),
        "confidence": ticket.vision_match_score,
        "claimAmount": order.amount if order else 0.0,
        "riderPodUrl": order.rider_pod_image_url if order else None,
        "createdAt": ticket.created_at.isoformat() if hasattr(ticket, 'created_at') and ticket.created_at else datetime.now(timezone.utc).isoformat(),
        "resolvedAt": datetime.now(timezone.utc).isoformat() if status in ("resolved", "denied") else None,
        "auditTrace": None,
    }


# ── POST /api/orchestrate ──


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
        customer_claim_text=req.complaint_text,
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

    # 5. Fetch merchant config for Auditor
    merchant_name = order.merchant_name if order else ""
    merchant_config = db.query(MerchantConfig).filter(MerchantConfig.merchant_name == merchant_name).first()
    auto_refund_limit = merchant_config.auto_refund_limit if merchant_config else 0.0
    order_amount = order.amount if order else 0.0

    # 6. Call GLM Multi-Agent
    try:
        glm_raw = await call_glm(
            complaint_text=req.complaint_text,
            user_category_selection=req.user_category_selection,
            vision_json=vision_json,
            merchant_name=merchant_name,
            auto_refund_limit=auto_refund_limit,
            order_amount=order_amount,
            rider_pod_url=order.rider_pod_image_url if order else "",
            customer_image_url=req.customer_image_url,
        )
        glm_decision = MultiAgentDecision(**glm_raw)
    except (ValidationError, Exception):
        glm_decision = MultiAgentDecision(
            trace_log=[
                {"agent": "Ingestor", "action": "Error", "result": "GLM response invalid or parse failure"},
                {"agent": "Investigator", "action": "Error", "result": "Skipped"},
                {"agent": "Auditor", "action": "Error", "result": "Defaulting to manual escalation"},
            ],
            final_action="MANUAL_ESCALATION",
            confidence_score=0.0,
        )

    # 7. Log GLM reasoning
    db.add(AuditLog(
        ticket_id=ticket.id,
        action="glm_reasoning",
        raw_json=json.dumps(glm_decision.model_dump()),
    ))
    db.commit()

    # 8. Vision-based override: if vision confirms damage at high confidence,
    #    but GLM returned MANUAL_ESCALATION due to low confidence (not due to error/fraud),
    #    override to APPROVE_REFUND since the vision model is authoritative.
    #    Do NOT override if GLM returned REJECT_FRAUD or if GLM errored out.
    _glm_had_error = any(
        e.action == "Error" for e in (glm_decision.trace_log or [])
    )
    if (not _glm_had_error
            and vision_result.match_confidence >= 0.85
            and vision_result.damage_detected
            and glm_decision.final_action == "MANUAL_ESCALATION"):
        glm_decision.final_action = "APPROVE_REFUND"
        glm_decision.confidence_score = vision_result.match_confidence

    # 9. Execute final action
    if glm_decision.final_action == "APPROVE_REFUND":
        from app.routers.mock import stripe_refund as _refund_logic
        refund_req = type("RefundRequest", (), {"order_id": req.order_id, "amount": order_amount})()
        _refund_logic(refund_req, db=db)
        ticket.status = "refunded"
        db.add(AuditLog(ticket_id=ticket.id, action="refund_triggered", raw_json=json.dumps({"order_id": req.order_id})))
    elif glm_decision.final_action == "REJECT_FRAUD":
        ticket.status = "fraud_rejected"
        db.add(AuditLog(ticket_id=ticket.id, action="fraud_rejected", raw_json=json.dumps({"order_id": req.order_id})))
    else:
        ticket.status = "manual_review"

    db.commit()
    db.refresh(ticket)

    return OrchestrateResponse(
        ticket_id=ticket.id,
        ticket_status=ticket.status,
        vision_match_score=vision_result.match_confidence,
        glm_decision=glm_decision,
        rider_pod_url=order.rider_pod_image_url if order else None,
    )


# ── GET /api/claims ──


@router.get("/claims")
def get_claims(merchant: str | None = Query(None), db: Session = Depends(get_db)):
    query = db.query(Ticket).options(joinedload(Ticket.order))
    tickets = query.order_by(Ticket.id.desc()).all()

    claims = []
    for t in tickets:
        order = t.order
        if merchant and (not order or order.merchant_name != merchant):
            continue
        claims.append(_claim_row(t, order))
    return claims


# ── GET /api/claims/{ticket_id}/trace ──


@router.get("/claims/{ticket_id}/trace")
def get_claim_trace(ticket_id: int, db: Session = Depends(get_db)):
    ticket = db.query(Ticket).filter(Ticket.id == ticket_id).first()
    if not ticket:
        return {"error": "Ticket not found"}

    logs = db.query(AuditLog).filter(AuditLog.ticket_id == ticket_id).all()

    # Find the GLM reasoning log
    glm_log = next((l for l in logs if l.action == "glm_reasoning"), None)
    vision_log = next((l for l in logs if l.action == "vision_check"), None)

    ingestor_result = {"intent": "", "damageType": "", "sentiment": "Neutral", "confidence": 0.0}
    investigator_confidence = 0.0
    investigator_summary = ""
    compliance_checks = []
    verdict = "Pending"
    reasoning_log = []

    if glm_log and glm_log.raw_json:
        try:
            decision = json.loads(glm_log.raw_json)
            trace = decision.get("trace_log", [])
            final_action = decision.get("final_action", "MANUAL_ESCALATION")
            confidence = decision.get("confidence_score", 0.0)

            # Build reasoning log from trace entries
            for i, entry in enumerate(trace):
                is_critical = "mismatch" in entry.get("result", "").lower() or "fraud" in entry.get("result", "").lower()
                reasoning_log.append({
                    "lineNumber": i + 1,
                    "agent": entry.get("agent", "System"),
                    "content": entry.get("result", ""),
                    "isCritical": is_critical,
                })

            # Extract Ingestor result
            for entry in trace:
                if entry.get("agent") == "Ingestor":
                    result_text = entry.get("result", "")
                    ingestor_result = {
                        "intent": "Refund" if "refund" in result_text.lower() else "Review",
                        "damageType": entry.get("action", "Entity Extraction"),
                        "sentiment": "Urgent" if "smash" in (ticket.customer_claim_text or "").lower() else "Neutral",
                        "confidence": confidence,
                    }
                    break

            # Extract Investigator result
            for entry in trace:
                if entry.get("agent") == "Investigator":
                    investigator_confidence = confidence
                    investigator_summary = entry.get("result", "")
                    break

            # Build compliance checks from Auditor
            for entry in trace:
                if entry.get("agent") == "Auditor":
                    compliance_checks.append({
                        "label": entry.get("action", "Policy Check"),
                        "detail": entry.get("result", ""),
                        "passed": "REJECT_FRAUD" not in final_action,
                    })

            # Verdict
            if final_action == "APPROVE_REFUND":
                verdict = "Autonomous Approval"
            elif final_action == "REJECT_FRAUD":
                verdict = "Fraud Rejected"
            else:
                verdict = "Manual Escalation"

        except json.JSONDecodeError:
            pass

    # Add vision check as reasoning step if no GLM data
    if not reasoning_log and vision_log and vision_log.raw_json:
        try:
            vdata = json.loads(vision_log.raw_json)
            reasoning_log.append({
                "lineNumber": 1, "agent": "Investigator",
                "content": f"Vision analysis: confidence={vdata.get('match_confidence', 0)}, damage={vdata.get('damage_detected', False)}",
                "isCritical": False,
            })
        except json.JSONDecodeError:
            pass

    return {
        "ingestorResult": ingestor_result,
        "investigatorConfidence": investigator_confidence,
        "investigatorSummary": investigator_summary,
        "complianceChecks": compliance_checks,
        "verdict": verdict,
        "reasoningLog": reasoning_log,
    }


# ── GET /api/merchants/policies ──


@router.get("/merchants/policies")
def get_merchant_policies(db: Session = Depends(get_db)):
    configs = db.query(MerchantConfig).all()
    # Category mapping per merchant
    _merchant_categories = {
        "Grab": ["Food", "Perishables", "Beverages"],
        "Zalora": ["Electronics", "Apparel", "Footwear"],
        "DHL": ["Apparel", "Accessories", "General"],
        "Shopee": ["Electronics", "Home & Living", "Fashion"],
    }
    return [
        {
            "merchantId": f"{c.merchant_name.lower()}_1",
            "merchantName": c.merchant_name,
            "region": "MY",
            "autoRefundThreshold": c.auto_refund_limit,
            "certaintyCutoff": 85.0,
            "maxAutoAmount": c.auto_refund_limit * 4,
            "categories": _merchant_categories.get(c.merchant_name, ["General"]),
            "isActive": True,
            "policyVersion": "v1.0",
        }
        for c in configs
    ]


# ── GET /api/audit-logs ──


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
