import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base, get_db
from app.models import User, Order, MerchantConfig
from app.main import app

TEST_DATABASE_URL = "sqlite:///./test_veriserve.db"

engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base.metadata.create_all(bind=engine)


def override_get_db():
    db = TestSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture
def db():
    Base.metadata.create_all(bind=engine)
    db = TestSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture
def seed_data(db):
    user = User(id=1, role="customer")
    db.add(user)
    db.commit()

    # Merchant configs
    for name, limit in [("Grab", 50.00), ("Zalora", 500.00), ("DHL", 100.00), ("Shopee", 50.00)]:
        db.add(MerchantConfig(merchant_name=name, auto_refund_limit=limit))
    db.commit()

    # Scenario 1: Food (Grab) — Success path
    order1 = Order(
        id=1, customer_id=1, merchant_name="Grab", category="Food",
        amount=25.99, rider_pod_image_url="https://placehold.co/600x400/4CAF50/white?text=Intact+Food+Box", status="delivered",
    )
    db.add(order1)

    # Scenario 2: Electronics (Zalora) — Fraud path
    order2 = Order(
        id=2, customer_id=1, merchant_name="Zalora", category="Electronics",
        amount=499.00, rider_pod_image_url="https://placehold.co/600x400/2196F3/white?text=Intact+Electronics", status="delivered",
    )
    db.add(order2)

    # Scenario 3: Apparel (DHL) — Pre-existing damage
    order3 = Order(
        id=3, customer_id=1, merchant_name="DHL", category="Apparel",
        amount=89.50, rider_pod_image_url="https://placehold.co/600x400/FF9800/white?text=Dented+Can", status="delivered",
    )
    db.add(order3)

    # Scenario 4: Electronics (Shopee) — Minor damage edge case
    order4 = Order(
        id=4, customer_id=1, merchant_name="Shopee", category="Electronics",
        amount=150.00, rider_pod_image_url="https://placehold.co/600x400/9C27B0/white?text=Intact+Package", status="delivered",
    )
    db.add(order4)

    db.commit()
    return {"user": user, "orders": [order1, order2, order3, order4]}


@pytest.fixture
def client():
    from httpx import ASGITransport, AsyncClient
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")