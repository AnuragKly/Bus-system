"""
Enhanced ETA calculation with Kalman filtering and advanced traffic analysis
"""
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List
import math

class KalmanETAFilter:
    """
    Kalman filter for ETA prediction that accounts for:
    - Vehicle speed variations
    - Traffic conditions
    - Historical data patterns
    """
    
    def __init__(self):
        # State: [position, velocity, acceleration]
        self.state = np.array([0.0, 0.0, 0.0])  # [km, km/h, km/h²]
        
        # State covariance matrix
        self.P = np.eye(3) * 100
        
        # Process noise covariance (accounts for unpredictable changes)
        self.Q = np.array([
            [0.1, 0.0, 0.0],    # Position uncertainty
            [0.0, 25.0, 0.0],   # Velocity uncertainty (speed changes)
            [0.0, 0.0, 5.0]     # Acceleration uncertainty
        ])
        
        # Measurement noise covariance
        self.R = np.array([
            [1.0, 0.0],         # Position measurement noise
            [0.0, 4.0]          # Speed measurement noise
        ])
        
        self.dt = 1/60  # 1-minute time steps
        
    def predict(self, dt: float = None) -> np.ndarray:
        """Predict next state using motion model"""
        if dt is None:
            dt = self.dt
            
        # State transition matrix (constant acceleration model)
        F = np.array([
            [1, dt, 0.5*dt**2],
            [0, 1, dt],
            [0, 0, 1]
        ])
        
        # Predict state
        self.state = F @ self.state
        self.P = F @ self.P @ F.T + self.Q
        
        return self.state
    
    def update(self, measurement: np.ndarray):
        """Update with GPS measurement [position, speed]"""
        H = np.array([
            [1, 0, 0],  # Observe position
            [0, 1, 0]   # Observe velocity
        ])
        
        # Innovation
        y = measurement - H @ self.state
        S = H @ self.P @ H.T + self.R
        
        # Kalman gain
        K = self.P @ H.T @ np.linalg.inv(S)
        
        # Update
        self.state = self.state + K @ y
        self.P = (np.eye(3) - K @ H) @ self.P

def calculate_distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two points using Haversine formula"""
    R = 6371  # Earth's radius in km
    
    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    
    a = (math.sin(dlat/2)**2 + 
         math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon/2)**2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    
    return R * c

def get_nepal_time() -> datetime:
    """Get current time in Nepal timezone"""
    from datetime import timezone
    nepal_tz = timezone(timedelta(hours=5, minutes=45))
    return datetime.now(nepal_tz)

def analyze_historical_speed(locations: List[Dict], lookback_hours: int = 24) -> Dict:
    """Analyze historical speed patterns for better prediction"""
    if len(locations) < 2:
        return {"median_speed": 25.0, "speed_variance": 5.0, "confidence": 0.5}
    
    speeds = []
    current_time = get_nepal_time()
    cutoff_time = current_time - timedelta(hours=lookback_hours)
    
    for i in range(1, len(locations)):
        prev_loc = locations[i-1]
        curr_loc = locations[i]
        
        # Parse timestamps
        prev_time = datetime.fromisoformat(prev_loc['timestamp'].replace('Z', '+00:00'))
        curr_time = datetime.fromisoformat(curr_loc['timestamp'].replace('Z', '+00:00'))
        
        if prev_time < cutoff_time:
            continue
            
        # Calculate speed
        distance = calculate_distance_km(
            prev_loc['latitude'], prev_loc['longitude'],
            curr_loc['latitude'], curr_loc['longitude']
        )
        
        time_diff = (curr_time - prev_time).total_seconds() / 3600  # hours
        
        if time_diff > 0 and distance > 0:
            speed = distance / time_diff  # km/h
            if 5 <= speed <= 80:  # Reasonable speed range for buses
                speeds.append(speed)
    
    if not speeds:
        return {"median_speed": 25.0, "speed_variance": 5.0, "confidence": 0.5}
    
    speeds = np.array(speeds)
    median_speed = np.median(speeds)
    speed_variance = np.var(speeds)
    confidence = min(0.9, 0.5 + len(speeds) * 0.02)  # More data = higher confidence
    
    return {
        "median_speed": float(median_speed),
        "speed_variance": float(speed_variance),
        "confidence": float(confidence)
    }

def enhanced_eta_calculation(
    current_lat: float,
    current_lon: float,
    dest_lat: float,
    dest_lon: float,
    current_speed: float,
    historical_data: List[Dict],
    traffic_factor: float = 1.0
) -> Dict:
    """Enhanced ETA calculation using Kalman filtering and historical analysis"""
    
    # Calculate base distance
    distance_km = calculate_distance_km(current_lat, current_lon, dest_lat, dest_lon)
    
    # Analyze historical patterns
    hist_analysis = analyze_historical_speed(historical_data)
    
    # Initialize Kalman filter
    kf = KalmanETAFilter()
    kf.state = np.array([0, current_speed, 0])  # Start with current speed
    
    # If we have recent GPS data, update Kalman filter
    if len(historical_data) >= 2:
        recent_locations = historical_data[-5:]  # Use last 5 points
        
        for i in range(1, len(recent_locations)):
            prev_loc = recent_locations[i-1]
            curr_loc = recent_locations[i]
            
            # Calculate time difference
            prev_time = datetime.fromisoformat(prev_loc['timestamp'].replace('Z', '+00:00'))
            curr_time = datetime.fromisoformat(curr_loc['timestamp'].replace('Z', '+00:00'))
            dt = (curr_time - prev_time).total_seconds() / 3600  # hours
            
            # Calculate distance and speed
            distance_step = calculate_distance_km(
                prev_loc['latitude'], prev_loc['longitude'],
                curr_loc['latitude'], curr_loc['longitude']
            )
            speed = distance_step / dt if dt > 0 else 0
            
            # Predict and update
            kf.predict(dt)
            measurement = np.array([distance_step, speed])
            kf.update(measurement)
    
    # Enhanced speed calculation
    base_speed = max(hist_analysis["median_speed"], 20.0)  # Minimum realistic speed
    
    # Nepal-specific adjustments
    nepal_time = get_nepal_time()
    hour = nepal_time.hour
    
    # Time-of-day speed factors for Nepal
    if 7 <= hour <= 9 or 17 <= hour <= 19:  # Rush hours
        time_factor = 0.85  # 15% slower
    elif 12 <= hour <= 14:  # Lunch time
        time_factor = 1.0   # Normal speed
    elif 22 <= hour or hour <= 6:  # Night time
        time_factor = 1.2   # 20% faster
    else:  # Off-peak
        time_factor = 1.1   # 10% faster
    
    # Distance-based adjustments
    if distance_km > 10:  # Long distance - likely highway portions
        distance_factor = 1.1  # 10% faster
    elif distance_km < 3:  # Short distance - likely city traffic
        distance_factor = 0.9  # 10% slower
    else:
        distance_factor = 1.0
    
    # Calculate effective speed using Kalman filter prediction
    kalman_speed = max(kf.state[1], 15.0)  # Use Kalman predicted speed
    effective_speed = kalman_speed * traffic_factor * time_factor * distance_factor
    effective_speed = max(effective_speed, 15.0)  # Minimum 15 km/h
    effective_speed = min(effective_speed, 60.0)  # Maximum 60 km/h for buses
    
    # Calculate ETA
    eta_hours = distance_km / effective_speed
    eta_minutes = eta_hours * 60
    
    # Google Maps calibration (competitive accuracy)
    google_factor = 1.15  # Our estimates are 15% more conservative for safety
    eta_minutes = eta_minutes / google_factor
    
    # Confidence calculation using Kalman uncertainty
    kalman_uncertainty = np.trace(kf.P)  # Total uncertainty in Kalman filter
    base_confidence = hist_analysis["confidence"]
    
    # Adjust confidence based on Kalman filter uncertainty
    kalman_confidence = max(0.6, 1.0 - kalman_uncertainty / 1000)
    
    # Traffic-based confidence
    if traffic_factor <= 1.1:  # Light traffic
        traffic_confidence = 0.88
    elif traffic_factor <= 1.3:  # Moderate traffic
        traffic_confidence = 0.82
    else:  # Heavy traffic
        traffic_confidence = 0.75
    
    # Time-based confidence (rush hour patterns are well-known)
    if 7 <= hour <= 9 or 17 <= hour <= 19:
        time_confidence = 0.95  # Rush hour patterns are predictable
    else:
        time_confidence = 0.85
    
    # Final confidence (weighted average)
    final_confidence = (
        base_confidence * 0.2 +
        kalman_confidence * 0.3 +
        traffic_confidence * 0.25 +
        time_confidence * 0.25
    )
    
    # Cap confidence at realistic maximum
    final_confidence = min(final_confidence, 0.92)
    
    # Calculate uncertainty range
    uncertainty = (1 - final_confidence) * eta_minutes * 0.4
    
    return {
        "eta_minutes": round(eta_minutes, 1),
        "eta_range": {
            "min": round(eta_minutes - uncertainty, 1),
            "max": round(eta_minutes + uncertainty, 1)
        },
        "confidence": round(final_confidence * 100, 1),
        "effective_speed_kmh": round(effective_speed, 1),
        "factors": {
            "traffic": traffic_factor,
            "time_of_day": time_factor,
            "distance": distance_factor,
            "google_calibration": google_factor
        },
        "algorithm_details": {
            "base_speed": round(base_speed, 1),
            "kalman_speed": round(kalman_speed, 1),
            "historical_points": len(historical_data),
            "kalman_uncertainty": round(kalman_uncertainty, 2)
        }
    }
