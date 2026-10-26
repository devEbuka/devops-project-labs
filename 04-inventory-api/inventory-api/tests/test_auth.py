import os
os.environ.setdefault('DATABASE_URL', 'sqlite+pysqlite:////tmp/inventory-auth-tests.sqlite')
os.environ.setdefault('JWT_SECRET', 'test-only-32-character-secret-not-for-deployments')

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from app.database import Base, get_db
from app.models import User
from app.auth import hash_password
from app.main import app

engine = create_engine('sqlite+pysqlite://', connect_args={'check_same_thread': False}, poolclass=StaticPool)
Base.metadata.create_all(engine)
Session = sessionmaker(bind=engine)

def db_override():
    with Session() as session:
        yield session

app.dependency_overrides[get_db] = db_override
client = TestClient(app)


def test_auth_flow():
    assert client.get('/health').status_code == 200
    assert client.get('/products').status_code == 401
    payload = {'email': 'viewer@example.com', 'password': 'a-good-long-password'}
    r = client.post('/auth/register', json=payload)
    assert r.status_code == 201, r.text
    assert r.json()['role'] == 'viewer'
    assert 'password_hash' not in r.text
    assert client.post('/auth/register', json=payload).status_code == 409
    assert client.post('/auth/login', json={**payload, 'password': 'wrong'}).status_code == 401
    r = client.post('/auth/login', json=payload)
    assert r.status_code == 200, r.text
    headers = {'Authorization': f"Bearer {r.json()['access_token']}"}
    assert client.get('/auth/me', headers=headers).json()['role'] == 'viewer'
    assert client.get('/products', headers=headers).status_code == 200
    assert client.post('/products', headers=headers, json={'sku': 'A', 'name': 'Test', 'price': '2', 'quantity': 5}).status_code == 403
    with Session.begin() as db:
        db.add(User(email='admin@example.com', password_hash=hash_password('a-secure-admin-password'), role='admin'))
    admin_token = client.post('/auth/login', json={'email': 'admin@example.com', 'password': 'a-secure-admin-password'}).json()['access_token']
    ah = {'Authorization': f'Bearer {admin_token}'}
    r = client.post('/products', headers=ah, json={'sku': 'A', 'name': 'Test', 'price': '2', 'quantity': 5})
    assert r.status_code == 201, r.text
    assert client.post(f"/products/{r.json()['id']}/stock", headers=ah, json={'delta': -2}).status_code == 200
    assert client.get('/inventory/summary', headers=headers).json()['total_units'] == 3
    assert client.get('/auth/me', headers={'Authorization': 'Bearer invalid'}).status_code == 401


def test_lockout():
    payload = {'email': 'locked@example.com', 'password': 'valid-long-password'}
    assert client.post('/auth/register', json=payload).status_code == 201
    for _ in range(5):
        assert client.post('/auth/login', json={**payload, 'password': 'incorrect'}).status_code == 401
    assert client.post('/auth/login', json=payload).status_code == 429
