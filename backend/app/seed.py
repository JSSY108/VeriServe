"""Seed the dev database with test data for user_123 across multiple merchants."""
from app.database import engine, SessionLocal, Base
from app.models import User, Order

Base.metadata.create_all(bind=engine)

db = SessionLocal()
try:
    if not db.query(User).filter(User.id == 1).first():
        db.add(User(id=1, role="customer"))

    # Scenario A: Food (Grab)
    if not db.query(Order).filter(Order.id == 1).first():
        db.add(Order(
            id=1,
            customer_id=1,
            merchant_name="Grab",
            category="Food",
            amount=25.99,
            rider_pod_image_url="rider_pod_grab_food.jpg",
            status="delivered",
        ))

    # Scenario B: Electronics (Zalora)
    if not db.query(Order).filter(Order.id == 2).first():
        db.add(Order(
            id=2,
            customer_id=1,
            merchant_name="Zalora",
            category="Electronics",
            amount=499.00,
            rider_pod_image_url="rider_pod_zalora_electronics.jpg",
            status="delivered",
        ))

    # Scenario C: Apparel (DHL)
    if not db.query(Order).filter(Order.id == 3).first():
        db.add(Order(
            id=3,
            customer_id=1,
            merchant_name="DHL",
            category="Apparel",
            amount=89.50,
            rider_pod_image_url="rider_pod_dhl_apparel.jpg",
            status="delivered",
        ))

    db.commit()
    print("Seed data inserted successfully.")
except Exception as e:
    print(f"Error seeding: {e}")
finally:
    db.close()
