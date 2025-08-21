from fastapi import APIRouter, Depends, HTTPException, status, Query
from datetime import datetime, timedelta
from typing import List, Optional
from ..database import get_database
from ..schemas.location import GPSData, LocationResponse, CurrentLocation
from ..utils.distance import haversine_distance, estimate_arrival_time_with_traffic
from ..utils.traffic import get_live_traffic_factor
from ..utils.nepal_time import get_nepal_time, utc_to_nepal_time, parse_nepal_timestamp, format_nepal_time

# Try to import advanced tracking, fallback to simple tracking
try:
    from ..utils.advanced_tracking import AdvancedBusTracker, GPSPoint, BusRoute, initialize_ku_routes
    print("✅ Using NumPy-based advanced tracking")
    TRACKING_TYPE = "advanced"
except ImportError:
    from ..utils.simple_tracking import SimpleBusTracker as AdvancedBusTracker, GPSPoint, BusRoute, initialize_ku_routes
    print("✅ Using simple tracking (no NumPy dependency)")
    TRACKING_TYPE = "simple"

from .websocket import broadcast_location_updatet APIRouter, Depends, HTTPException, status, Query
from datetime import datetime
from typing import List, Optional
from ..database import get_database
from ..schemas.location import GPSData, LocationResponse, CurrentLocation
from ..utils.distance import haversine_distance, estimate_arrival_time_with_traffic
from ..utils.traffic import get_live_traffic_factor
from ..utils.nepal_time import get_nepal_time, utc_to_nepal_time, parse_nepal_timestamp, format_nepal_time

# Try to import advanced tracking, fallback to simple tracking
try:
    from ..utils.advanced_tracking import AdvancedBusTracker, GPSPoint, BusRoute, initialize_ku_routes
    print("✅ Using NumPy-based advanced tracking")
except ImportError:
    from ..utils.simple_tracking import SimpleBusTracker as AdvancedBusTracker, GPSPoint, BusRoute, initialize_ku_routes
    print("✅ Using simple tracking (no NumPy dependency)")

from .websocket import broadcast_location_update

router = APIRouter(prefix="/gps", tags=["GPS"])

# Initialize advanced tracking system
advanced_tracker = initialize_ku_routes()

@router.post("/data")
async def receive_gps_data(
    gps_data: GPSData,
    db = Depends(get_database)
):
    """Receive GPS data from ESP32 with Kalman filtering"""
    
    # Debug: Log the incoming timestamp format
    print(f"🔍 DEBUG: Received timestamp from ESP32: {gps_data.timestamp}")
    print(f"🔍 DEBUG: Timestamp type: {type(gps_data.timestamp)}")
    
    # Set timestamp if not provided (use Nepal time)
    if gps_data.timestamp is None:
        print("⚠️  No timestamp provided, using current Nepal time")
        gps_data.timestamp = get_nepal_time()
    else:
        # Parse the timestamp from ESP32 and ensure it's in Nepal time
        original_timestamp = str(gps_data.timestamp)
        print(f"🔄 Converting timestamp: {original_timestamp}")
        
        # If the timestamp is already in Nepal format (+05:45), keep it
        if "+05:45" in original_timestamp:
            print("✅ Timestamp already in Nepal format")
            gps_data.timestamp = parse_nepal_timestamp(original_timestamp)
        else:
            # If UTC timestamp, convert to Nepal time
            print("🔄 Converting UTC to Nepal time")
            if isinstance(gps_data.timestamp, str):
                # Handle string timestamps
                timestamp_str = gps_data.timestamp.replace('Z', '+00:00') if 'Z' in gps_data.timestamp else gps_data.timestamp
                utc_dt = datetime.fromisoformat(timestamp_str)
            else:
                utc_dt = gps_data.timestamp
            gps_data.timestamp = utc_to_nepal_time(utc_dt)
        
        print(f"✅ Final Nepal timestamp: {gps_data.timestamp}")
    
    # Process GPS data through Kalman filter
    gps_point = GPSPoint(
        latitude=gps_data.latitude,
        longitude=gps_data.longitude,
        speed=gps_data.speed,
        timestamp=gps_data.timestamp,
        accuracy=5.0  # ESP32 GPS accuracy
    )
    
    # Apply advanced tracking (Kalman filter)
    tracking_result = advanced_tracker.process_gps_update(gps_data.bus_id, gps_point)
    
    print(f"📡 Raw GPS: {gps_data.latitude:.6f}, {gps_data.longitude:.6f}")
    print(f"🎯 Filtered: {tracking_result['filtered_position']['latitude']:.6f}, {tracking_result['filtered_position']['longitude']:.6f}")
    
    # Store both raw and filtered data
    location_doc = {
        "bus_id": gps_data.bus_id,
        # Raw GPS data
        "latitude": gps_data.latitude,
        "longitude": gps_data.longitude,
        "speed": gps_data.speed,
        # Kalman-filtered data
        "filtered_latitude": tracking_result['filtered_position']['latitude'],
        "filtered_longitude": tracking_result['filtered_position']['longitude'],
        "filtered_speed": tracking_result['filtered_position']['speed'],
        # Velocity data from Kalman filter
        "velocity_lat": tracking_result['velocity']['lat_velocity'],
        "velocity_lng": tracking_result['velocity']['lng_velocity'],
        # Timestamps
        "timestamp": gps_data.timestamp,
        "created_at": get_nepal_time()
    }
    
    print(f"💾 Storing in MongoDB: filtered_lat={location_doc['filtered_latitude']:.6f}")

    # Insert into database
    result = await db.locations.insert_one(location_doc)
    
    # Update bus status last_updated
    await db.bus_status.update_one(
        {"bus_id": gps_data.bus_id},
        {"$set": {
            "last_updated": get_nepal_time(),
            "filtered_latitude": tracking_result['filtered_position']['latitude'],
            "filtered_longitude": tracking_result['filtered_position']['longitude']
        }},
        upsert=True
    )
    
    # Broadcast location update with filtered data
    await broadcast_location_update({
        "bus_id": gps_data.bus_id,
        "latitude": tracking_result['filtered_position']['latitude'],  # Use filtered position
        "longitude": tracking_result['filtered_position']['longitude'],
        "speed": tracking_result['filtered_position']['speed'],
        "raw_latitude": gps_data.latitude,  # Also include raw for debugging
        "raw_longitude": gps_data.longitude,
        "timestamp": gps_data.timestamp.isoformat() if gps_data.timestamp else datetime.utcnow().isoformat()
    })
    
    return {
        "message": "GPS data received and processed with Kalman filter",
        "id": str(result.inserted_id),
        "tracking_result": tracking_result
    }

@router.get("/bus-location", response_model=CurrentLocation)
async def get_current_bus_location(
    bus_id: str = "bus_001",
    use_filtered: bool = True,
    db = Depends(get_database)
):
    """Get current bus location (option to use Kalman-filtered data)"""
    # Get latest location
    location = await db.locations.find_one(
        {"bus_id": bus_id},
        sort=[("timestamp", -1)]
    )
    
    if not location:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No location data found for this bus"
        )
    
    # Convert timestamp to Nepal time for user display
    nepal_timestamp = utc_to_nepal_time(location["timestamp"]) if location["timestamp"].tzinfo else location["timestamp"]
    
    # Choose between filtered or raw data
    if use_filtered and 'filtered_latitude' in location:
        lat = location['filtered_latitude']
        lng = location['filtered_longitude']
        speed = location.get('filtered_speed', location['speed'])
    else:
        lat = location['latitude']
        lng = location['longitude']
        speed = location['speed']
    
    return CurrentLocation(
        bus_id=location["bus_id"],
        latitude=lat,
        longitude=lng,
        speed=speed,
        last_updated=nepal_timestamp
    )

@router.get("/eta")
async def calculate_advanced_eta(
    bus_id: str = Query(..., description="Bus ID"),
    destination_stop: str = Query(..., description="Destination stop name"),
    route_id: str = Query(default="KU_KTM_001", description="Route ID"),
    db = Depends(get_database)
):
    """Calculate ETA using advanced route-based algorithm and Kalman-filtered position"""
    
    # Get traffic factor
    location = await db.locations.find_one(
        {"bus_id": bus_id},
        sort=[("timestamp", -1)]
    )
    
    if not location:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No location data found for this bus"
        )
    
    # Get current traffic conditions (simplified)
    current_lat = location.get('filtered_latitude', location['latitude'])
    current_lng = location.get('filtered_longitude', location['longitude'])
    
    traffic_factor = await get_live_traffic_factor(current_lat, current_lng, current_lat, current_lng)
    
    # Calculate ETA using advanced tracking
    eta_result = advanced_tracker.calculate_eta_to_stop(
        bus_id=bus_id,
        target_stop=destination_stop,
        route_id=route_id,
        traffic_factor=traffic_factor
    )
    
    if not eta_result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Could not calculate ETA for bus {bus_id} to stop {destination_stop}"
        )
    
    # Add current position information
    nepal_timestamp = utc_to_nepal_time(location["timestamp"]) if location["timestamp"].tzinfo else location["timestamp"]
    
    eta_result.update({
        "bus_id": bus_id,
        "current_position": {
            "latitude": current_lat,
            "longitude": current_lng,
            "filtered": 'filtered_latitude' in location
        },
        "last_updated": nepal_timestamp,
        "route_id": route_id,
        "algorithm": "Route-based ETA with Kalman filtering"
    })
    
    return eta_result

@router.get("/predict-position")
async def predict_bus_position(
    bus_id: str = Query(..., description="Bus ID"),
    seconds_ahead: float = Query(default=300, description="Seconds to predict ahead"),
    db = Depends(get_database)
):
    """Predict bus position using Kalman filter"""
    
    predicted_pos = advanced_tracker.predict_position(bus_id, seconds_ahead)
    
    if not predicted_pos:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Cannot predict position for bus {bus_id}"
        )
    
    # Get last known position for comparison
    location = await db.locations.find_one(
        {"bus_id": bus_id},
        sort=[("timestamp", -1)]
    )
    
    nepal_timestamp = utc_to_nepal_time(location["timestamp"]) if location and location["timestamp"].tzinfo else datetime.now()
    predicted_time = nepal_timestamp + datetime.timedelta(seconds=seconds_ahead)
    
    return {
        "bus_id": bus_id,
        "prediction": {
            "latitude": predicted_pos[0],
            "longitude": predicted_pos[1],
            "predicted_time": predicted_time.isoformat(),
            "seconds_ahead": seconds_ahead
        },
        "current_position": {
            "latitude": location.get('filtered_latitude', location['latitude']) if location else None,
            "longitude": location.get('filtered_longitude', location['longitude']) if location else None,
            "timestamp": nepal_timestamp.isoformat() if location else None
        },
        "algorithm": "Kalman Filter Position Prediction"
    }

@router.get("/route-info")
async def get_route_information():
    """Get information about available bus routes"""
    
    routes_info = []
    
    # KU to Kathmandu route
    routes_info.append({
        "route_id": "KU_KTM_001",
        "route_name": "KU to Kathmandu",
        "stops": [
            "KU Main Gate",
            "Dhulikhel Road Junction", 
            "Banepa Chowk",
            "Bhaktapur",
            "Thimi",
            "Kathmandu"
        ],
        "total_stops": 6,
        "estimated_duration": "90-120 minutes",
        "average_speed": "35 km/h"
    })
    
    # Internal campus shuttle
    routes_info.append({
        "route_id": "KU_INTERNAL",
        "route_name": "Campus Shuttle",
        "stops": [
            "Main Gate",
            "Engineering Block",
            "Central Library", 
            "Hostel Area",
            "Sports Ground"
        ],
        "total_stops": 5,
        "estimated_duration": "15-20 minutes",
        "average_speed": "18 km/h"
    })
    
    return {
        "routes": routes_info,
        "total_routes": len(routes_info),
        "algorithms_used": [
            "Kalman Filter for GPS accuracy",
            "Route-based ETA calculation",
            "Historical speed analysis"
        ]
    }

# Keep existing endpoints for backward compatibility
@router.get("/bus-location-nepal")
async def get_current_bus_location_nepal(
    bus_id: str = "bus_001",
    use_filtered: bool = True,
    db = Depends(get_database)
):
    """Get current bus location with Nepal timezone formatting"""
    # Get latest location
    location = await db.locations.find_one(
        {"bus_id": bus_id},
        sort=[("timestamp", -1)]
    )
    
    if not location:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No location data found for this bus"
        )
    
    # Format timestamp in Nepal time
    nepal_time = utc_to_nepal_time(location["timestamp"]) if location["timestamp"].tzinfo else location["timestamp"]
    
    # Choose between filtered or raw data
    if use_filtered and 'filtered_latitude' in location:
        lat = location['filtered_latitude']
        lng = location['filtered_longitude'] 
        speed = location.get('filtered_speed', location['speed'])
        data_type = "Kalman-filtered"
    else:
        lat = location['latitude']
        lng = location['longitude']
        speed = location['speed']
        data_type = "Raw GPS"
    
    return {
        "bus_id": location["bus_id"],
        "latitude": lat,
        "longitude": lng,
        "speed": speed,
        "data_type": data_type,
        "last_updated": nepal_time.isoformat(),
        "last_updated_nepal": format_nepal_time(nepal_time),
        "timezone": "Nepal Standard Time (NST)",
        "algorithms": "Kalman Filter + Route-based ETA"
    }

@router.get("/location-history", response_model=List[LocationResponse])
async def get_location_history(
    bus_id: str = "bus_001",
    limit: int = 100,
    use_filtered: bool = True,
    db = Depends(get_database)
):
    """Get location history with option for filtered data"""
    cursor = db.locations.find(
        {"bus_id": bus_id}
    ).sort("timestamp", -1).limit(limit)
    
    locations = []
    async for location in cursor:
        # Convert timestamps to Nepal time for user display
        nepal_timestamp = utc_to_nepal_time(location["timestamp"]) if location["timestamp"].tzinfo else location["timestamp"]
        nepal_created = utc_to_nepal_time(location["created_at"]) if location["created_at"].tzinfo else location["created_at"]
        
        # Choose between filtered or raw data
        if use_filtered and 'filtered_latitude' in location:
            lat = location['filtered_latitude']
            lng = location['filtered_longitude']
            speed = location.get('filtered_speed', location['speed'])
        else:
            lat = location['latitude']
            lng = location['longitude']
            speed = location['speed']
        
        locations.append(LocationResponse(
            id=str(location["_id"]),
            bus_id=location["bus_id"],
            latitude=lat,
            longitude=lng,
            speed=speed,
            timestamp=nepal_timestamp,
            created_at=nepal_created
        ))
    
    return locations

@router.get("/tracking-comparison")
async def compare_tracking_methods(
    bus_id: str = Query(..., description="Bus ID"),
    limit: int = Query(default=10, description="Number of recent points to compare"),
    db = Depends(get_database)
):
    """Compare raw GPS vs Kalman-filtered tracking data"""
    
    cursor = db.locations.find(
        {"bus_id": bus_id}
    ).sort("timestamp", -1).limit(limit)
    
    comparisons = []
    total_raw_error = 0
    total_filtered_error = 0
    count = 0
    
    locations = []
    async for location in cursor:
        locations.append(location)
    
    for i, location in enumerate(locations):
        if 'filtered_latitude' not in location:
            continue
            
        nepal_time = utc_to_nepal_time(location["timestamp"]) if location["timestamp"].tzinfo else location["timestamp"]
        
        comparison = {
            "timestamp": nepal_time.isoformat(),
            "raw_gps": {
                "latitude": location['latitude'],
                "longitude": location['longitude'],
                "speed": location['speed']
            },
            "kalman_filtered": {
                "latitude": location['filtered_latitude'],
                "longitude": location['filtered_longitude'],
                "speed": location.get('filtered_speed', location['speed'])
            }
        }
        
        # Calculate difference between raw and filtered
        lat_diff = abs(location['latitude'] - location['filtered_latitude'])
        lng_diff = abs(location['longitude'] - location['filtered_longitude'])
        
        comparison["difference"] = {
            "latitude_diff": lat_diff,
            "longitude_diff": lng_diff,
            "distance_meters": haversine_distance(
                location['latitude'], location['longitude'],
                location['filtered_latitude'], location['filtered_longitude']
            ) * 1000
        }
        
        comparisons.append(comparison)
        count += 1
    
    return {
        "bus_id": bus_id,
        "comparison_points": comparisons,
        "total_points": count,
        "algorithm_info": {
            "kalman_filter": "Reduces GPS noise and provides smooth tracking",
            "route_based_eta": "Uses predefined routes instead of shortest path",
            "benefits": [
                "Eliminates GPS jumping between readings",
                "Provides velocity estimation",
                "Enables position prediction during signal loss",
                "More accurate ETA for fixed bus routes"
            ]
        }
    }

# Legacy endpoints for backward compatibility
@router.get("/estimate-arrival")
async def estimate_arrival(
    destination_lat: float,
    destination_lon: float,
    bus_id: str = "bus_001",
    db = Depends(get_database)
):
    """Legacy ETA endpoint - redirects to advanced ETA with closest stop"""
    # This is kept for backward compatibility
    # In a real implementation, you might map coordinates to stop names
    
    # For now, return a simple distance-based calculation
    location = await db.locations.find_one(
        {"bus_id": bus_id},
        sort=[("timestamp", -1)]
    )
    if not location:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No location data found for this bus"
        )
    
    # Use filtered position if available
    current_lat = location.get('filtered_latitude', location['latitude'])
    current_lng = location.get('filtered_longitude', location['longitude'])
    
    # Calculate distance
    distance = haversine_distance(current_lat, current_lng, destination_lat, destination_lon)
    
    # Fetch traffic factor
    traffic_factor = await get_live_traffic_factor(current_lat, current_lng, destination_lat, destination_lon)
    
    # Estimate arrival time
    eta_minutes = estimate_arrival_time_with_traffic(distance, traffic_factor=traffic_factor)
    
    nepal_timestamp = utc_to_nepal_time(location["timestamp"]) if location["timestamp"].tzinfo else location["timestamp"]
    
    return {
        "current_location": {
            "latitude": current_lat,
            "longitude": current_lng,
            "data_type": "Kalman-filtered" if 'filtered_latitude' in location else "Raw GPS"
        },
        "destination": {
            "latitude": destination_lat,
            "longitude": destination_lon
        },
        "distance_km": round(distance, 2),
        "estimated_arrival_minutes": eta_minutes,
        "traffic_factor": traffic_factor,
        "last_updated": nepal_timestamp,
        "algorithm": "Enhanced with Kalman filtering",
        "recommendation": "Use /gps/eta endpoint for route-based ETA calculation"
    }
