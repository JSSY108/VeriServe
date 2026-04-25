"""Seed the dev database with test data for user_123 across multiple merchants."""
from app.database import engine, SessionLocal, Base
from app.models import User, Order, MerchantConfig

Base.metadata.create_all(bind=engine)

db = SessionLocal()
try:
    if not db.query(User).filter(User.id == 1).first():
        db.add(User(id=1, role="customer"))

    # Merchant auto-refund limits
    for name, limit in [("Grab", 50.00), ("Zalora", 500.00), ("DHL", 100.00), ("Shopee", 50.00)]:
        if not db.query(MerchantConfig).filter(MerchantConfig.merchant_name == name).first():
            db.add(MerchantConfig(merchant_name=name, auto_refund_limit=limit))

    # Scenario 1: Food (Grab) — Success path
    if not db.query(Order).filter(Order.id == 1).first():
        db.add(Order(
            id=1,
            customer_id=1,
            merchant_name="Grab",
            category="Food",
            amount=25.99,
            rider_pod_image_url="https://placehold.co/600x400/4CAF50/white?text=Intact+Food+Box",
            status="delivered",
        ))

    # Scenario 2: Electronics (Zalora) — Fraud path
    if not db.query(Order).filter(Order.id == 2).first():
        db.add(Order(
            id=2,
            customer_id=1,
            merchant_name="Zalora",
            category="Electronics",
            amount=499.00,
            rider_pod_image_url="https://placehold.co/600x400/2196F3/white?text=Intact+Electronics",
            status="delivered",
        ))

    # Scenario 3: Apparel (DHL) — Pre-existing damage
    if not db.query(Order).filter(Order.id == 3).first():
        db.add(Order(
            id=3,
            customer_id=1,
            merchant_name="DHL",
            category="Apparel",
            amount=89.50,
            rider_pod_image_url="https://placehold.co/600x400/FF9800/white?text=Dented+Can",
            status="delivered",
        ))

    # Scenario 4: Electronics (Shopee) — Minor damage edge case
    if not db.query(Order).filter(Order.id == 4).first():
        db.add(Order(
            id=4,
            customer_id=1,
            merchant_name="Shopee",
            category="Electronics",
            amount=150.00,
            rider_pod_image_url="https://placehold.co/600x400/9C27B0/white?text=Intact+Package",
            status="delivered",
        ))

    db.commit()
    print("Seed data inserted successfully.")
except Exception as e:
    print(f"Error seeding: {e}")
finally:
    db.close()
