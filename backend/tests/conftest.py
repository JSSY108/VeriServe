import pytest
from unittest.mock import patch, AsyncMock, MagicMock
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base, get_db
from app.models import User, Order
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

    # Scenario A: Food (Grab)
    order1 = Order(
        id=1,
        customer_id=1,
        merchant_name="Grab",
        category="Food",
        amount=25.99,
        rider_pod_image_url="pod_grab_food.jpg",
        status="delivered",
    )
    db.add(order1)

    # Scenario B: Electronics (Zalora)
    order2 = Order(
        id=2,
        customer_id=1,
        merchant_name="Zalora",
        category="Electronics",
        amount=499.00,
        rider_pod_image_url="pod_zalora_electronics.jpg",
        status="delivered",
    )
    db.add(order2)

    # Scenario C: Apparel (DHL)
    order3 = Order(
        id=3,
        customer_id=1,
        merchant_name="DHL",
        category="Apparel",
        amount=89.50,
        rider_pod_image_url="pod_dhl_apparel.jpg",
        status="delivered",
    )
    db.add(order3)

    db.commit()
    return {"user": user, "orders": [order1, order2, order3]}


@pytest.fixture
def client():
    from httpx import ASGITransport, AsyncClient
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")
