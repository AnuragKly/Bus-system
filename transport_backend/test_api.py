#!/usr/bin/env python3
"""
Simple test script to verify the GPS API endpoints work correctly
"""

import requests
import json
from datetime import datetime
import socket

def find_server_port():
    """Find which port the server is running on"""
    for port in range(8000, 8010):
        try:
            response = requests.get(f"http://localhost:{port}/health", timeout=1)
            if response.status_code == 200:
                return port
        except requests.exceptions.RequestException:
            continue
    return 8000  # Default fallback

# Try to detect the actual server port
SERVER_PORT = find_server_port()
BASE_URL = f"http://localhost:{SERVER_PORT}"

print(f"🔍 Detected server on port {SERVER_PORT}")
print(f"📡 Using base URL: {BASE_URL}")
print()

def test_root():
    """Test root endpoint"""
    print("Testing root endpoint...")
    try:
        response = requests.get(f"{BASE_URL}/")
        print(f"✅ Root: {response.json()}")
    except Exception as e:
        print(f"❌ Error: {e}")

def test_health():
    """Test health endpoint"""
    print("\nTesting health endpoint...")
    try:
        response = requests.get(f"{BASE_URL}/health")
        print(f"✅ Health: {response.json()}")
    except Exception as e:
        print(f"❌ Error: {e}")

def test_gps_data():
    """Test GPS data submission"""
    print("\nTesting GPS data submission...")
    gps_payload = {
        "bus_id": "bus_001",
        "latitude": 27.6176,  # Kathmandu coordinates
        "longitude": 85.5392,
        "speed": 25.5,
        "timestamp": datetime.utcnow().isoformat()
    }
    
    try:
        response = requests.post(f"{BASE_URL}/gps/data", json=gps_payload)
        if response.status_code == 200:
            print(f"✅ GPS Data Submitted: {response.json()}")
        else:
            print(f"❌ Error submitting GPS data: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"❌ Error: {e}")

def test_get_location():
    """Test get current bus location"""
    print("\nTesting get current bus location...")
    try:
        response = requests.get(f"{BASE_URL}/gps/bus-location?bus_id=bus_001")
        if response.status_code == 200:
            print(f"✅ Current Location: {response.json()}")
        else:
            print(f"❌ Error getting location: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"❌ Error: {e}")

def test_estimate_arrival():
    """Test arrival time estimation"""
    print("\nTesting arrival time estimation...")
    params = {
        "destination_lat": 27.6200,
        "destination_lon": 85.5400,
        "bus_id": "bus_001"
    }
    
    try:
        response = requests.get(f"{BASE_URL}/gps/estimate-arrival", params=params)
        if response.status_code == 200:
            print(f"✅ Arrival Estimate: {response.json()}")
        else:
            print(f"❌ Error estimating arrival: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"❌ Error: {e}")

def test_location_history():
    """Test location history"""
    print("\nTesting location history...")
    try:
        response = requests.get(f"{BASE_URL}/gps/location-history?bus_id=bus_001&limit=5")
        if response.status_code == 200:
            print(f"✅ Location History: {response.json()}")
        else:
            print(f"❌ Error getting history: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    print("🚌 GPS API Test Script")
    print("=" * 50)
    print("Make sure the server is running on http://localhost:8000")
    print("=" * 50)
    
    # Run all tests
    test_root()
    test_health()
    test_gps_data()
    test_get_location()
    test_estimate_arrival()
    test_location_history()
    
    print("\n" + "=" * 50)
    print("🎉 Test completed!")
