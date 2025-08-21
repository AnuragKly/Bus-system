"""
Advanced GPS Tracking with Kalman Filter
For accurate bus location tracking and ETA calculation
"""

import numpy as np
from typing import Tuple, List, Optional
from dataclasses import dataclass
from datetime import datetime, timedelta
import math

@dataclass
class GPSPoint:
    """GPS coordinate with timestamp"""
    latitude: float
    longitude: float
    speed: float
    timestamp: datetime
    accuracy: float = 5.0  # Default GPS accuracy in meters

@dataclass
class BusRoute:
    """Bus route definition with stops"""
    route_id: str
    route_name: str
    stops: List[Tuple[float, float, str]]  # (lat, lng, stop_name)
    average_speeds: List[float]  # Speed between each stop segment

class KalmanGPSFilter:
    """
    Kalman Filter for GPS tracking
    Reduces GPS noise and provides smooth position tracking
    """
    
    def __init__(self, process_noise: float = 1.0, measurement_noise: float = 5.0):
        """
        Initialize Kalman Filter
        
        Args:
            process_noise: How much we trust the prediction model (lower = more trust)
            measurement_noise: GPS measurement noise in meters (higher = less trust in GPS)
        """
        self.dt = 5.0  # Time interval (5 seconds between GPS updates)
        
        # State vector: [latitude, longitude, velocity_lat, velocity_lng]
        self.state = np.zeros(4)
        
        # State transition matrix (constant velocity model)
        self.F = np.array([
            [1, 0, self.dt, 0],      # lat = lat + velocity_lat * dt
            [0, 1, 0, self.dt],      # lng = lng + velocity_lng * dt
            [0, 0, 1, 0],            # velocity_lat remains constant
            [0, 0, 0, 1]             # velocity_lng remains constant
        ])
        
        # Measurement matrix (we only observe position, not velocity)
        self.H = np.array([
            [1, 0, 0, 0],  # We measure latitude
            [0, 1, 0, 0]   # We measure longitude
        ])
        
        # Process noise covariance
        self.Q = np.eye(4) * process_noise
        
        # Measurement noise covariance
        self.R = np.eye(2) * measurement_noise
        
        # Error covariance matrix
        self.P = np.eye(4) * 100  # Initial uncertainty
        
        self.initialized = False
    
    def update(self, gps_point: GPSPoint) -> Tuple[float, float, float, float]:
        """
        Update Kalman filter with new GPS measurement
        
        Returns:
            Tuple of (filtered_lat, filtered_lng, velocity_lat, velocity_lng)
        """
        measurement = np.array([gps_point.latitude, gps_point.longitude])
        
        if not self.initialized:
            # Initialize state with first measurement
            self.state[0] = gps_point.latitude
            self.state[1] = gps_point.longitude
            self.state[2] = 0  # Initial velocity
            self.state[3] = 0
            self.initialized = True
            return gps_point.latitude, gps_point.longitude, 0.0, 0.0
        
        # Prediction step
        predicted_state = self.F @ self.state
        predicted_P = self.F @ self.P @ self.F.T + self.Q
        
        # Update step
        innovation = measurement - self.H @ predicted_state
        innovation_covariance = self.H @ predicted_P @ self.H.T + self.R
        kalman_gain = predicted_P @ self.H.T @ np.linalg.inv(innovation_covariance)
        
        # Update state and covariance
        self.state = predicted_state + kalman_gain @ innovation
        self.P = (np.eye(4) - kalman_gain @ self.H) @ predicted_P
        
        return self.state[0], self.state[1], self.state[2], self.state[3]
    
    def predict_next_position(self, seconds_ahead: float) -> Tuple[float, float]:
        """
        Predict position after given seconds using current velocity
        Useful for ETA calculation during GPS signal loss
        """
        if not self.initialized:
            return 0.0, 0.0
        
        predicted_lat = self.state[0] + self.state[2] * seconds_ahead
        predicted_lng = self.state[1] + self.state[3] * seconds_ahead
        
        return predicted_lat, predicted_lng

class RouteBasedETA:
    """
    Route-based ETA calculation for bus system
    More accurate than Dijkstra for fixed-route buses
    """
    
    def __init__(self):
        self.routes = {}  # route_id -> BusRoute
        self.historical_speeds = {}  # route_id -> segment speeds
        
    def add_route(self, route: BusRoute):
        """Add a bus route to the system"""
        self.routes[route.route_id] = route
        self.historical_speeds[route.route_id] = route.average_speeds.copy()
    
    def find_nearest_stop(self, current_lat: float, current_lng: float, route_id: str) -> Tuple[int, float]:
        """
        Find the nearest bus stop on the route
        
        Returns:
            Tuple of (stop_index, distance_to_stop)
        """
        if route_id not in self.routes:
            return -1, float('inf')
        
        route = self.routes[route_id]
        min_distance = float('inf')
        nearest_stop_idx = 0
        
        for i, (stop_lat, stop_lng, _) in enumerate(route.stops):
            distance = self._haversine_distance(current_lat, current_lng, stop_lat, stop_lng)
            if distance < min_distance:
                min_distance = distance
                nearest_stop_idx = i
        
        return nearest_stop_idx, min_distance
    
    def calculate_eta_to_stop(self, current_lat: float, current_lng: float, 
                             target_stop_name: str, route_id: str, 
                             traffic_factor: float = 1.0) -> Optional[dict]:
        """
        Calculate ETA to a specific bus stop
        
        Args:
            current_lat, current_lng: Current bus position
            target_stop_name: Name of the destination stop
            route_id: Bus route identifier
            traffic_factor: Current traffic conditions (1.0 = normal, >1.0 = slower)
        
        Returns:
            Dictionary with ETA information or None if stop not found
        """
        if route_id not in self.routes:
            return None
        
        route = self.routes[route_id]
        
        # Find target stop
        target_stop_idx = None
        for i, (_, _, stop_name) in enumerate(route.stops):
            if stop_name.lower() == target_stop_name.lower():
                target_stop_idx = i
                break
        
        if target_stop_idx is None:
            return None
        
        # Find current position on route
        current_stop_idx, distance_to_nearest = self.find_nearest_stop(current_lat, current_lng, route_id)
        
        if current_stop_idx > target_stop_idx:
            # Bus has already passed the target stop
            return {
                "status": "passed",
                "message": f"Bus has already passed {target_stop_name}",
                "eta_minutes": 0
            }
        
        # Calculate total distance and time
        total_distance = 0.0
        total_time = 0.0
        
        # Distance from current position to next stop
        if current_stop_idx < len(route.stops):
            next_stop_lat, next_stop_lng, _ = route.stops[current_stop_idx]
            distance_to_next = self._haversine_distance(current_lat, current_lng, next_stop_lat, next_stop_lng)
            total_distance += distance_to_next
            
            # Use historical speed for this segment
            if current_stop_idx < len(self.historical_speeds[route_id]):
                segment_speed = self.historical_speeds[route_id][current_stop_idx] / traffic_factor
                total_time += (distance_to_next / segment_speed) * 60  # Convert to minutes
        
        # Add time for remaining segments
        for segment_idx in range(current_stop_idx, target_stop_idx):
            if segment_idx + 1 < len(route.stops):
                stop1_lat, stop1_lng, _ = route.stops[segment_idx]
                stop2_lat, stop2_lng, _ = route.stops[segment_idx + 1]
                segment_distance = self._haversine_distance(stop1_lat, stop1_lng, stop2_lat, stop2_lng)
                total_distance += segment_distance
                
                # Use historical speed for this segment
                if segment_idx < len(self.historical_speeds[route_id]):
                    segment_speed = self.historical_speeds[route_id][segment_idx] / traffic_factor
                    total_time += (segment_distance / segment_speed) * 60  # Convert to minutes
        
        return {
            "status": "approaching",
            "target_stop": target_stop_name,
            "current_stop": route.stops[current_stop_idx][2],
            "distance_km": round(total_distance, 2),
            "eta_minutes": round(total_time, 1),
            "stops_remaining": target_stop_idx - current_stop_idx,
            "traffic_factor": traffic_factor
        }
    
    def update_segment_speed(self, route_id: str, segment_idx: int, new_speed: float):
        """Update historical speed for a route segment based on recent data"""
        if route_id in self.historical_speeds and segment_idx < len(self.historical_speeds[route_id]):
            # Use exponential moving average to update speed
            current_speed = self.historical_speeds[route_id][segment_idx]
            alpha = 0.3  # Learning rate
            self.historical_speeds[route_id][segment_idx] = (1 - alpha) * current_speed + alpha * new_speed
    
    def _haversine_distance(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """Calculate distance between two GPS coordinates"""
        R = 6371  # Earth's radius in kilometers
        
        lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        
        a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
        c = 2 * math.asin(math.sqrt(a))
        
        return R * c

class AdvancedBusTracker:
    """
    Advanced bus tracking system combining Kalman filtering and route-based ETA
    """
    
    def __init__(self):
        self.kalman_filters = {}  # bus_id -> KalmanGPSFilter
        self.route_eta = RouteBasedETA()
        self.last_positions = {}  # bus_id -> last GPS point
        
    def add_bus_route(self, route: BusRoute):
        """Add a bus route to the tracking system"""
        self.route_eta.add_route(route)
    
    def process_gps_update(self, bus_id: str, gps_point: GPSPoint) -> dict:
        """
        Process new GPS data with Kalman filtering
        
        Returns:
            Dictionary with filtered position and movement data
        """
        # Initialize Kalman filter for new bus
        if bus_id not in self.kalman_filters:
            self.kalman_filters[bus_id] = KalmanGPSFilter()
        
        # Apply Kalman filter
        filtered_lat, filtered_lng, vel_lat, vel_lng = self.kalman_filters[bus_id].update(gps_point)
        
        # Calculate filtered speed
        filtered_speed = math.sqrt(vel_lat**2 + vel_lng**2) * 111320  # Convert to km/h (approximate)
        
        # Store last position
        self.last_positions[bus_id] = gps_point
        
        return {
            "bus_id": bus_id,
            "raw_position": {
                "latitude": gps_point.latitude,
                "longitude": gps_point.longitude,
                "speed": gps_point.speed
            },
            "filtered_position": {
                "latitude": filtered_lat,
                "longitude": filtered_lng,
                "speed": filtered_speed
            },
            "velocity": {
                "lat_velocity": vel_lat,
                "lng_velocity": vel_lng
            },
            "timestamp": gps_point.timestamp
        }
    
    def calculate_eta_to_stop(self, bus_id: str, target_stop: str, route_id: str, 
                             traffic_factor: float = 1.0) -> Optional[dict]:
        """Calculate ETA using filtered position and route-based algorithm"""
        if bus_id not in self.last_positions:
            return None
        
        last_pos = self.last_positions[bus_id]
        
        # Use Kalman-filtered position for ETA calculation
        if bus_id in self.kalman_filters:
            filtered_lat, filtered_lng, _, _ = self.kalman_filters[bus_id].state[:4]
        else:
            filtered_lat, filtered_lng = last_pos.latitude, last_pos.longitude
        
        return self.route_eta.calculate_eta_to_stop(
            filtered_lat, filtered_lng, target_stop, route_id, traffic_factor
        )
    
    def predict_position(self, bus_id: str, seconds_ahead: float) -> Optional[Tuple[float, float]]:
        """Predict bus position using Kalman filter"""
        if bus_id not in self.kalman_filters:
            return None
        
        return self.kalman_filters[bus_id].predict_next_position(seconds_ahead)

# Example usage and route definitions for Kathmandu University
def initialize_ku_routes() -> AdvancedBusTracker:
    """Initialize bus tracker with KU routes"""
    tracker = AdvancedBusTracker()
    
    # KU to Kathmandu route
    ku_to_kathmandu = BusRoute(
        route_id="KU_KTM_001",
        route_name="KU to Kathmandu",
        stops=[
            (27.6176, 85.5392, "KU Main Gate"),
            (27.6190, 85.5410, "Dhulikhel Road Junction"),
            (27.6250, 85.5500, "Banepa Chowk"),
            (27.6800, 85.3000, "Bhaktapur"),
            (27.7000, 85.3200, "Thimi"),
            (27.7172, 85.3240, "Kathmandu")
        ],
        average_speeds=[25.0, 30.0, 35.0, 40.0, 35.0]  # km/h for each segment
    )
    
    # Internal campus shuttle
    campus_shuttle = BusRoute(
        route_id="KU_INTERNAL",
        route_name="Campus Shuttle",
        stops=[
            (27.6180, 85.5395, "Main Gate"),
            (27.6175, 85.5400, "Engineering Block"),
            (27.6170, 85.5385, "Central Library"),
            (27.6165, 85.5380, "Hostel Area"),
            (27.6185, 85.5405, "Sports Ground")
        ],
        average_speeds=[15.0, 20.0, 15.0, 20.0]  # Slower campus speeds
    )
    
    tracker.add_bus_route(ku_to_kathmandu)
    tracker.add_bus_route(campus_shuttle)
    
    return tracker
