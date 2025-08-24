import requests
import time
import json
from datetime import datetime

# Configuration
API_URL = "http://localhost:8000/gps/data"
BUS_ID = "ESP32_BUS_001"

# Route: Exact Araniko Highway coordinates (5 minutes)
# Using user-provided precise GPS coordinates
route_points = [
    # Starting point - Exact coordinates provided by user
    {"lat": 27.67562, "lon": 85.35136, "speed": 0, "location": "Starting Point - Araniko Highway"},
    
    # First waypoint - User provided coordinate
    {"lat": 27.67533, "lon": 85.35665, "speed": 25, "location": "First Waypoint - Araniko Highway"},
    
    # Second waypoint - User provided coordinate  
    {"lat": 27.67497, "lon": 85.35973, "speed": 30, "location": "Second Waypoint - Araniko Highway"},
    
    # Final destination - User provided coordinate
    {"lat": 27.67436, "lon": 85.36421, "speed": 0, "location": "Final Destination - Araniko Highway"}
]

def send_gps_data(latitude, longitude, speed):
    """Send GPS data to the backend API"""
    data = {
        "bus_id": BUS_ID,
        "latitude": latitude,
        "longitude": longitude,
        "speed": speed,
        "timestamp": datetime.now().isoformat()
    }
    
    try:
        response = requests.post(API_URL, json=data)
        if response.status_code == 200:
            print(f"✅ GPS data sent: Lat {latitude:.6f}, Lon {longitude:.6f}, Speed {speed} km/h")
            return True
        else:
            print(f"❌ Failed to send GPS data: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Network error: {e}")
        return False

def interpolate_points(start_point, end_point, num_steps=3):
    """Create intermediate points between two GPS coordinates"""
    intermediate_points = []
    
    for i in range(1, num_steps + 1):
        ratio = i / (num_steps + 1)
        
        lat = start_point["lat"] + (end_point["lat"] - start_point["lat"]) * ratio
        lon = start_point["lon"] + (end_point["lon"] - start_point["lon"]) * ratio
        speed = start_point["speed"] + (end_point["speed"] - start_point["speed"]) * ratio
        
        intermediate_points.append({"lat": lat, "lon": lon, "speed": speed})
    
    return intermediate_points

def simulate_gps_journey():
    """Simulate 5-minute GPS journey using exact user coordinates"""
    print("🚌 ESP32 GPS Simulation: Exact Araniko Highway Route")
    print("📍 Route: User-provided precise coordinates")
    print("⏰ Duration: Exactly 5 minutes")
    print("🔄 ESP32 Mode: 5-second intervals")
    print("-" * 70)
    
    # Create route with interpolated points for 5-minute journey
    # 5 minutes = 300 seconds / 5 seconds per update = 60 total points
    all_points = []
    
    for i in range(len(route_points) - 1):
        all_points.append(route_points[i])
        # Add more intermediate points between each waypoint for 5-minute duration
        intermediate = interpolate_points(route_points[i], route_points[i + 1], 12)
        all_points.extend(intermediate)
    
    # Add final destination
    all_points.append(route_points[-1])
    
    # Ensure we have exactly 60 points for 5 minutes (adjust if needed)
    target_points = 60
    if len(all_points) != target_points:
        print(f"📊 Adjusting points: {len(all_points)} → {target_points}")
        # Simple resampling to get exactly 60 points
        step = len(all_points) / target_points
        all_points = [all_points[int(i * step)] for i in range(target_points)]
    
    print(f"📊 Total GPS points: {len(all_points)}")
    print(f"⏱️  ESP32 interval: 5 seconds")
    print(f"🕐 Total duration: {len(all_points) * 5 / 60:.1f} minutes")
    print("-" * 70)
    
    # Send GPS data for each point
    for i, point in enumerate(all_points):
        timestamp = datetime.now().strftime("%H:%M:%S")
        progress = (i + 1) / len(all_points) * 100
        
        print(f"[{timestamp}] Point {i+1}/{len(all_points)} ({progress:.1f}%)", end=" ")
        
        success = send_gps_data(point["lat"], point["lon"], point["speed"])
        
        if not success:
            print("⚠️  Retrying in 3 seconds...")
            time.sleep(3)
            send_gps_data(point["lat"], point["lon"], point["speed"])
        
        # ESP32 timing: Wait 5 seconds before next GPS reading
        if i < len(all_points) - 1:
            time.sleep(5)
    
    print("\n" + "=" * 70)
    print("🎉 GPS simulation completed!")
    print("📍 Final location: User-specified destination")
    print(f"⏰ Total simulation time: {len(all_points) * 5 / 60:.1f} minutes")
    print("🛣️  Route: Exact coordinates from user")
    print("=" * 70)

if __name__ == "__main__":
    try:
        simulate_gps_journey()
    except KeyboardInterrupt:
        print("\n⏹️  GPS simulation stopped by user")
    except Exception as e:
        print(f"\n❌ Simulation error: {e}")
