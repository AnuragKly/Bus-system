from fastapi import APIRouter, Depends, HTTPException, status
from datetime import datetime
from typing import List, Optional
from ..database import get_database
from ..schemas.location import GPSData, LocationResponse, CurrentLocation
from ..utils.distance import haversine_distance, estimate_arrival_time_with_traffic
from ..utils.traffic import get_live_traffic_factor
from ..utils.nepal_time import get_nepal_time, utc_to_nepal_time, parse_nepal_timestamp, format_nepal_time
from .websocket import broadcast_location_update

router = APIRouter(prefix="/gps", tags=["GPS"])

@router.post("/data")
async def receive_gps_data(
    gps_data: GPSData,
    db = Depends(get_database)
):
    """Receive GPS data from ESP32"""
    
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
                timestamp_str = str(gps_data.timestamp).replace('Z', '+00:00') if 'Z' in str(gps_data.timestamp) else str(gps_data.timestamp)
                utc_dt = datetime.fromisoformat(timestamp_str)
            else:
                utc_dt = gps_data.timestamp
            gps_data.timestamp = utc_to_nepal_time(utc_dt)
        
        print(f"✅ Final Nepal timestamp: {gps_data.timestamp}")
    
    # Create location document with Nepal timestamps
    location_doc = {
        "bus_id": gps_data.bus_id,
        "latitude": gps_data.latitude,
        "longitude": gps_data.longitude,
        "speed": gps_data.speed,
        "timestamp": gps_data.timestamp,  # Now guaranteed to be Nepal time
        "created_at": get_nepal_time()    # Current Nepal time
    }
    
    print(f"💾 Storing in MongoDB: timestamp={location_doc['timestamp']}, created_at={location_doc['created_at']}")

    # Insert into database
    result = await db.locations.insert_one(location_doc)
    
    # Update bus status last_updated
    await db.bus_status.update_one(
        {"bus_id": gps_data.bus_id},
        {"$set": {"last_updated": get_nepal_time()}},  # Use Nepal time
        upsert=True
    )
    
    # Broadcast location update to connected clients
    await broadcast_location_update({
        "bus_id": gps_data.bus_id,
        "latitude": gps_data.latitude,
        "longitude": gps_data.longitude,
        "speed": gps_data.speed,
        "timestamp": gps_data.timestamp.isoformat() if gps_data.timestamp else datetime.utcnow().isoformat()
    })
    
    return {"message": "GPS data received successfully", "id": str(result.inserted_id)}

@router.get("/bus-location", response_model=CurrentLocation)
async def get_current_bus_location(
    bus_id: str = "bus_001",
    db = Depends(get_database)
):
    """Get current bus location (automatically converts to Nepal time)"""
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
    
    return CurrentLocation(
        bus_id=location["bus_id"],
        latitude=location["latitude"],
        longitude=location["longitude"],
        speed=location["speed"],
        last_updated=nepal_timestamp  # Now shows Nepal time
    )

@router.get("/estimate-arrival-enhanced")
async def estimate_arrival_enhanced(
    destination_lat: float,
    destination_lon: float,
    bus_id: str = "ESP32_BUS_001",
    db = Depends(get_database)
):
    """Enhanced ETA calculation with speed and confidence metrics"""
    # Get current bus location
    current_location = await db.locations.find_one(
        {"bus_id": bus_id},
        sort=[("timestamp", -1)]
    )
    if not current_location:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No location data found for this bus"
        )
    
    # Get recent GPS data for speed analysis (last 5 points)
    historical_cursor = db.locations.find(
        {"bus_id": bus_id}
    ).sort("timestamp", -1).limit(5)
    
    recent_locations = []
    async for location in historical_cursor:
        recent_locations.append(location)
    
    # Calculate average speed from recent data
    total_speed = 0
    speed_count = 0
    for location in recent_locations:
        if location["speed"] > 0:  # Only count moving speeds
            total_speed += location["speed"]
            speed_count += 1
    
    average_speed = total_speed / speed_count if speed_count > 0 else 25.0  # Default 25 km/h
    current_speed = current_location["speed"]
    
    # Calculate effective speed (weighted average of current and historical)
    if current_speed > 0:
        effective_speed = (current_speed * 0.6) + (average_speed * 0.4)
    else:
        effective_speed = average_speed
    
    # Ensure minimum realistic speed
    effective_speed = max(effective_speed, 15.0)
    
    # Calculate distance
    distance = haversine_distance(
        current_location["latitude"], current_location["longitude"],
        destination_lat, destination_lon
    )
    
    # Get traffic factor
    traffic_factor = await get_live_traffic_factor(
        current_location["latitude"], current_location["longitude"],
        destination_lat, destination_lon
    )
    
    # Calculate ETA
    eta_minutes = (distance / effective_speed) * 60 * traffic_factor
    
    # Calculate confidence based on data quality
    confidence = 85.0  # Base confidence
    
    # Adjust confidence based on data availability
    if len(recent_locations) >= 3:
        confidence += 5.0  # More data points
    if speed_count >= 2:
        confidence += 5.0  # Moving data available
    if traffic_factor <= 1.2:
        confidence += 3.0  # Light traffic
    
    # Cap confidence at realistic maximum
    confidence = min(confidence, 92.0)
    
    # Convert timestamp to Nepal time
    nepal_timestamp = utc_to_nepal_time(current_location["timestamp"]) if current_location["timestamp"].tzinfo else current_location["timestamp"]
    
    return {
        "current_location": {
            "latitude": current_location["latitude"],
            "longitude": current_location["longitude"],
            "speed": current_location["speed"]
        },
        "destination": {
            "latitude": destination_lat,
            "longitude": destination_lon
        },
        "eta_minutes": round(eta_minutes, 1),
        "confidence_percent": round(confidence, 1),
        "effective_speed_kmh": round(effective_speed, 1),
        "distance_km": round(distance, 2),
        "traffic_factor": traffic_factor,
        "data_points_used": len(recent_locations),
        "moving_data_points": speed_count,
        "last_updated": nepal_timestamp,
        "algorithm": "Enhanced ETA with Speed Analysis"
    }

@router.get("/estimate-arrival")
async def estimate_arrival(
    destination_lat: float,
    destination_lon: float,
    bus_id: str = "ESP32_BUS_001",
    db = Depends(get_database)
):
    """Estimate bus arrival time to destination, using real-time traffic data (OpenRouteService, IEEE 2019)"""
    # Get current bus location
    location = await db.locations.find_one(
        {"bus_id": bus_id},
        sort=[("timestamp", -1)]
    )
    if not location:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No location data found for this bus"
        )
    
    # Get recent GPS data for enhanced calculations
    recent_cursor = db.locations.find(
        {"bus_id": bus_id}
    ).sort("timestamp", -1).limit(5)
    
    recent_locations = []
    async for loc in recent_cursor:
        recent_locations.append(loc)
    
    # Calculate average speed from recent data
    total_speed = 0
    speed_count = 0
    for loc in recent_locations:
        if loc["speed"] > 0:  # Only count moving speeds
            total_speed += loc["speed"]
            speed_count += 1
    
    average_speed = total_speed / speed_count if speed_count > 0 else 25.0  # Default 25 km/h
    current_speed = location["speed"]
    
    # Calculate effective speed (weighted average of current and historical)
    if current_speed > 0:
        effective_speed = (current_speed * 0.6) + (average_speed * 0.4)
    else:
        effective_speed = average_speed
    
    # Ensure minimum realistic speed
    effective_speed = max(effective_speed, 15.0)
    
    # Calculate distance
    distance = haversine_distance(
        location["latitude"], location["longitude"],
        destination_lat, destination_lon
    )
    # Fetch real-time traffic factor
    traffic_factor = await get_live_traffic_factor(
        location["latitude"], location["longitude"],
        destination_lat, destination_lon
    )
    # Estimate arrival time with real-time traffic
    eta_minutes = estimate_arrival_time_with_traffic(distance, traffic_factor=traffic_factor)
    
    # Calculate confidence based on data quality
    confidence = 85.0  # Base confidence
    
    # Adjust confidence based on data availability
    if len(recent_locations) >= 3:
        confidence += 5.0  # More data points
    if speed_count >= 2:
        confidence += 5.0  # Moving data available
    if traffic_factor <= 1.2:
        confidence += 3.0  # Light traffic
    
    # Cap confidence at realistic maximum
    confidence = min(confidence, 92.0)
    
    # Convert timestamp to Nepal time
    nepal_timestamp = utc_to_nepal_time(location["timestamp"]) if location["timestamp"].tzinfo else location["timestamp"]
    return {
        "current_location": {
            "latitude": location["latitude"],
            "longitude": location["longitude"]
        },
        "destination": {
            "latitude": destination_lat,
            "longitude": destination_lon
        },
        "distance_km": round(distance, 2),
        "estimated_arrival_minutes": eta_minutes,
        "effective_speed_kmh": round(effective_speed, 1),
        "confidence_percent": round(confidence, 1),
        "traffic_factor": traffic_factor,
        "data_points_used": len(recent_locations),
        "moving_data_points": speed_count,
        "last_updated": nepal_timestamp,  # Now shows Nepal time
        "_traffic_reference": "ETA adjusted for real-time traffic (OpenRouteService, IEEE 2019, https://ieeexplore.ieee.org/document/8713992)"
    }

@router.get("/location-history", response_model=List[LocationResponse])
async def get_location_history(
    bus_id: str = "bus_001",
    limit: int = 100,
    db = Depends(get_database)
):
    """Get location history for analytics (automatically converts to Nepal time)"""
    cursor = db.locations.find(
        {"bus_id": bus_id}
    ).sort("timestamp", -1).limit(limit)
    
    locations = []
    async for location in cursor:
        # Convert timestamps to Nepal time for user display
        nepal_timestamp = utc_to_nepal_time(location["timestamp"]) if location["timestamp"].tzinfo else location["timestamp"]
        nepal_created = utc_to_nepal_time(location["created_at"]) if location["created_at"].tzinfo else location["created_at"]
        
        locations.append(LocationResponse(
            id=str(location["_id"]),
            bus_id=location["bus_id"],
            latitude=location["latitude"],
            longitude=location["longitude"],
            speed=location["speed"],
            timestamp=nepal_timestamp,  # Now shows Nepal time
            created_at=nepal_created    # Now shows Nepal time
        ))
    
    return locations

@router.get("/bus-location-nepal")
async def get_current_bus_location_nepal(
    bus_id: str = "bus_001",
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
    
    return {
        "bus_id": location["bus_id"],
        "latitude": location["latitude"],
        "longitude": location["longitude"],
        "speed": location["speed"],
        "last_updated": nepal_time.isoformat(),
        "last_updated_nepal": format_nepal_time(nepal_time),
        "timezone": "Nepal Standard Time (NST)"
    }

@router.get("/location-history-nepal")
async def get_location_history_nepal(
    bus_id: str = "bus_001",
    limit: int = 100,
    db = Depends(get_database)
):
    """Get location history with Nepal timezone formatting"""
    cursor = db.locations.find(
        {"bus_id": bus_id}
    ).sort("timestamp", -1).limit(limit)
    
    locations = []
    async for location in cursor:
        # Convert timestamp to Nepal time
        nepal_time = utc_to_nepal_time(location["timestamp"]) if location["timestamp"].tzinfo else location["timestamp"]
        created_nepal = utc_to_nepal_time(location["created_at"]) if location["created_at"].tzinfo else location["created_at"]
        
        locations.append({
            "id": str(location["_id"]),
            "bus_id": location["bus_id"],
            "latitude": location["latitude"],
            "longitude": location["longitude"],
            "speed": location["speed"],
            "timestamp": nepal_time.isoformat(),
            "timestamp_nepal": format_nepal_time(nepal_time),
            "created_at": created_nepal.isoformat(),
            "created_nepal": format_nepal_time(created_nepal),
            "timezone": "Nepal Standard Time (NST)"
        })
    
    return {
        "locations": locations,
        "count": len(locations),
        "timezone": "Nepal Standard Time (NST)"
    }

@router.get("/test-nepal-time")
async def test_nepal_time():
    """Test endpoint to verify Nepal timezone conversion"""
    from datetime import datetime, timezone
    
    utc_now = datetime.now(timezone.utc)
    nepal_now = get_nepal_time()
    
    sample_utc = datetime.fromisoformat("2025-06-30T11:35:17")
    sample_nepal = utc_to_nepal_time(sample_utc)
    
    return {
        "utc_now": utc_now.isoformat(),
        "nepal_now": nepal_now.isoformat(),
        "nepal_formatted": format_nepal_time(nepal_now),
        "sample_conversion": {
            "utc": sample_utc.isoformat(),
            "nepal": sample_nepal.isoformat(),
            "formatted": format_nepal_time(sample_nepal)
        },
        "timezone_info": "Nepal Standard Time = UTC + 5:45"
    }