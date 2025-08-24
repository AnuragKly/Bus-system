import requests
import time
import json
from datetime import datetime

# Configuration
API_URL = "http://localhost:8000/gps/data"
BUS_ID = "ESP32_BUS_001"

# Route: Current location near Kathmandu to Koteshwor Traffic Police Station
# This simulates a realistic bus route with multiple stops
route_points = [
    # Starting point (current location)
    {"lat": 27.7234335, "lon": 85.2725605, "speed": 0},  # Starting point
    
    # Route to Koteshwor via Ring Road
    {"lat": 27.7220, "lon": 85.2740, "speed": 15},  # Moving towards ring road
    {"lat": 27.7200, "lon": 85.2760, "speed": 25},  # Ring road entry
    {"lat": 27.7180, "lon": 85.2800, "speed": 30},  # Ring road
    {"lat": 27.7160, "lon": 85.2850, "speed": 35},  # Ring road
    {"lat": 27.7140, "lon": 85.2900, "speed": 40},  # Ring road - faster section
    
    # Traffic area - slower speeds
    {"lat": 27.7120, "lon": 85.2950, "speed": 20},  # Traffic congestion
    {"lat": 27.7100, "lon": 85.3000, "speed": 15},  # Heavy traffic
    {"lat": 27.7080, "lon": 85.3050, "speed": 25},  # Traffic clearing
    
    # Approaching Koteshwor
    {"lat": 27.7060, "lon": 85.3100, "speed": 30},  # Normal flow
    {"lat": 27.7040, "lon": 85.3150, "speed": 35},  # Good speed
    {"lat": 27.7020, "lon": 85.3200, "speed": 30},  # Approaching destination
    
    # Near Koteshwor Traffic Police Station
    {"lat": 27.7000, "lon": 85.3250, "speed": 20},  # Slowing down
    {"lat": 27.6980, "lon": 85.3280, "speed": 15},  # Near destination
    {"lat": 27.6960, "lon": 85.3300, "speed": 10},  # Very close
    {"lat": 27.6950, "lon": 85.3320, "speed": 5},   # Arriving
    {"lat": 27.6945, "lon": 85.3330, "speed": 0},   # Koteshwor Traffic Police Station
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

def interpolate_points(start_point, end_point, num_steps=5):
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
    """Simulate a complete GPS journey with realistic timing"""
    print("🚌 Starting GPS simulation from current location to Koteshwor Traffic Police Station")
    print(f"📍 Route has {len(route_points)} main waypoints")
    print("⏰ Simulation will run for approximately 30 minutes with updates every 10 seconds")
    print("-" * 70)
    
    all_points = []
    
    # Create detailed route with interpolated points
    for i in range(len(route_points) - 1):
        all_points.append(route_points[i])
        # Add intermediate points for smoother movement
        intermediate = interpolate_points(route_points[i], route_points[i + 1], 3)
        all_points.extend(intermediate)
    
    # Add final destination
    all_points.append(route_points[-1])
    
    print(f"📊 Total simulation points: {len(all_points)}")
    print(f"⏱️  Update interval: 10 seconds")
    print(f"🕐 Total duration: {len(all_points) * 10 / 60:.1f} minutes")
    print("-" * 70)
    
    # Send GPS data for each point
    for i, point in enumerate(all_points):
        timestamp = datetime.now().strftime("%H:%M:%S")
        progress = (i + 1) / len(all_points) * 100
        
        print(f"[{timestamp}] Point {i+1}/{len(all_points)} ({progress:.1f}%)", end=" ")
        
        success = send_gps_data(point["lat"], point["lon"], point["speed"])
        
        if not success:
            print("⚠️  Retrying in 5 seconds...")
            time.sleep(5)
            send_gps_data(point["lat"], point["lon"], point["speed"])
        
        # Wait before sending next point (10 seconds for realistic simulation)
        if i < len(all_points) - 1:  # Don't wait after the last point
            time.sleep(10)
    
    print("\n" + "=" * 70)
    print("🎉 GPS simulation completed!")
    print(f"📍 Final location: Koteshwor Traffic Police Station")
    print(f"⏰ Total simulation time: {len(all_points) * 10 / 60:.1f} minutes")
    print("=" * 70)

if __name__ == "__main__":
    try:
        simulate_gps_journey()
    except KeyboardInterrupt:
        print("\n⏹️  GPS simulation stopped by user")
    except Exception as e:
        print(f"\n❌ Simulation error: {e}")
