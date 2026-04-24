from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Order
from app.schemas import VisionVerifyRequest, VisionVerifyResponse, RefundRequest, RefundResponse

router = APIRouter(prefix="/api/mock", tags=["mock"])

# Multi-tenant mock scenarios keyed by keyword in customer_image_url
_VISION_RULES = [
    # Food
    ("smashed", 0.95, True, "Damaged packaging — food items compromised"),
    ("soggy", 0.88, True, "Moisture damage to food packaging"),
    # Electronics
    ("crushed", 0.92, True, "Crushed box — electronics integrity at risk"),
    ("dented", 0.70, True, "Dented packaging — possible impact damage"),
    # Apparel
    ("torn", 0.90, True, "Torn courier bag — apparel exposed"),
    ("stained", 0.75, True, "Stain detected on packaging"),
    # Fraud
    ("fake", 0.10, False, "No damage detected — claim unverifiable"),
]


@router.post("/vision/verify", response_model=VisionVerifyResponse)
def vision_verify(req: VisionVerifyRequest):
    url_lower = req.customer_image_url.lower()
    for keyword, confidence, damage, desc in _VISION_RULES:
        if keyword in url_lower:
            return VisionVerifyResponse(match_confidence=confidence, damage_detected=damage, damage_type=desc)
    return VisionVerifyResponse(match_confidence=0.50, damage_detected=False, damage_type="Inconclusive — requires manual inspection")


@router.post("/stripe/refund", response_model=RefundResponse)
def stripe_refund(req: RefundRequest, db: Session = Depends(get_db)):
    order = db.query(Order).filter(Order.id == req.order_id).first()
    if order:
        order.status = "refunded"
        db.commit()
    return RefundResponse(status="success", tx_id="mock_999")
