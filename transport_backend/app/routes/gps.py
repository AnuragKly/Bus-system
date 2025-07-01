from fastapi import APIRouter, Depends, HTTPException, status
from datetime import datetime
from typing import List, Optional
from ..database import get_database
from ..schemas.location import GPSData, LocationResponse, CurrentLocation
from ..utils.distance import haversine_distance, estimate_arrival_time
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
                timestamp_str = gps_data.timestamp.replace('Z', '+00:00') if 'Z' in gps_data.timestamp else gps_data.timestamp
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

@router.get("/estimate-arrival")
async def estimate_arrival(
    destination_lat: float,
    destination_lon: float,
    bus_id: str = "bus_001",
    db = Depends(get_database)
):
    """Estimate bus arrival time to destination"""
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
    
    # Calculate distance
    distance = haversine_distance(
        location["latitude"], location["longitude"],
        destination_lat, destination_lon
    )
    
    # Estimate arrival time
    eta_minutes = estimate_arrival_time(distance)
    
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
        "last_updated": nepal_timestamp  # Now shows Nepal time
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