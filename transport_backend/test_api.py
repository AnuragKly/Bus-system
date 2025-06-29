import requests
import json
import asyncio
import websockets

BASE_URL = "http://localhost:8000"

def test_register():
    """Test user registration"""
    data = {
        "email": "test@ku.edu.np",
        "password": "testpassword123",
        "role": "student"
    }
    response = requests.post(f"{BASE_URL}/auth/register", json=data)
    print("Register Response:", response.json())

def test_gps_data():
    """Test GPS data submission (from ESP32)"""
    data = {
        "bus_id": "bus_001",
        "latitude": 27.6181,  # KU location
        "longitude": 85.5385,
        "speed": 25.5
    }
    response = requests.post(f"{BASE_URL}/gps/data", json=data)
    print("GPS Data Response:", response.json())

def test_admin_register():
    """Register admin user"""
    data = {
        "email": "driver@ku.edu.np",
        "password": "driverpass123",
        "role": "admin"
    }
    response = requests.post(f"{BASE_URL}/auth/register", json=data)
    print("Admin Register Response:", response.json())

def test_login_and_get_location():
    """Test login and get bus location"""
    # First login
    login_data = {
        "email": "test@ku.edu.np",
        "password": "testpassword123"
    }
    response = requests.post(f"{BASE_URL}/auth/login", json=login_data)
    
    if response.status_code != 200:
        print("Login failed:", response.json())
        return
    
    token = response.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    # Get bus location
    location_response = requests.get(f"{BASE_URL}/gps/bus-location", headers=headers)
    print("Bus Location:", location_response.json())
    
    # Test arrival estimation
    eta_response = requests.get(
        f"{BASE_URL}/gps/estimate-arrival?destination_lat=27.6299&destination_lon=85.5430",
        headers=headers
    )
    print("ETA Response:", eta_response.json())

async def test_websocket():
    """Test WebSocket connection"""
    uri = "ws://localhost:8000/ws/location"
    try:
        async with websockets.connect(uri) as websocket:
            print("WebSocket connected")
            # Send keepalive
            await websocket.send("ping")
            
            # Listen for messages
            message = await websocket.recv()
            print(f"Received: {message}")
    except Exception as e:
        print(f"WebSocket error: {e}")

if __name__ == "__main__":
    print("Testing Transport Management System API")
    print("=" * 50)
    
    # Test registration
    test_register()
    
    # Test admin registration
    test_admin_register()
    
    # Test GPS data
    test_gps_data()

    # Test login and get bus location
    test_login_and_get_location()
    # Test WebSocket (run this separately)
    asyncio.run(test_websocket())