from fastapi import APIRouter, Depends, HTTPException, status
from motor.motor_asyncio import AsyncIOMotorDatabase
from datetime import datetime
from typing import List, Optional
from ..database import get_database
from ..schemas.location import GPSData, LocationResponse, CurrentLocation
from ..dependencies import get_current_user
from ..utils.distance import haversine_distance, estimate_arrival_time
from .websocket import broadcast_location_update

router = APIRouter(prefix="/gps", tags=["GPS"])

@router.post("/data")
async def receive_gps_data(
    gps_data: GPSData,
    db: AsyncIOMotorDatabase = Depends(get_database)
):
    """Receive GPS data from ESP32"""
    # Set timestamp if not provided
    if gps_data.timestamp is None:
        gps_data.timestamp = datetime.utcnow()
    
    # Create location document
    location_doc = {
        "bus_id": gps_data.bus_id,
        "latitude": gps_data.latitude,
        "longitude": gps_data.longitude,
        "speed": gps_data.speed,
        "timestamp": gps_data.timestamp,
        "created_at": datetime.utcnow()
    }
    
    # Insert into database
    result = await db.locations.insert_one(location_doc)
    
    # Update bus status last_updated
    await db.bus_status.update_one(
        {"bus_id": gps_data.bus_id},
        {"$set": {"last_updated": datetime.utcnow()}},
        upsert=True
    )
    
    return {"message": "GPS data received successfully", "id": str(result.inserted_id)}

@router.get("/bus-location", response_model=CurrentLocation)
async def get_current_bus_location(
    bus_id: str = "bus_001",
    current_user: dict = Depends(get_current_user),
    db: AsyncIOMotorDatabase = Depends(get_database)
):
    """Get current bus location"""
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
    
    return CurrentLocation(
        bus_id=location["bus_id"],
        latitude=location["latitude"],
        longitude=location["longitude"],
        speed=location["speed"],
        last_updated=location["timestamp"]
    )

@router.get("/estimate-arrival")
async def estimate_arrival(
    destination_lat: float,
    destination_lon: float,
    bus_id: str = "bus_001",
    current_user: dict = Depends(get_current_user),
    db: AsyncIOMotorDatabase = Depends(get_database)
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
        "last_updated": location["timestamp"]
    }

@router.get("/location-history", response_model=List[LocationResponse])
async def get_location_history(
    bus_id: str = "bus_001",
    limit: int = 100,
    current_user: dict = Depends(get_current_user),
    db: AsyncIOMotorDatabase = Depends(get_database)
):
    """Get location history for analytics"""
    cursor = db.locations.find(
        {"bus_id": bus_id}
    ).sort("timestamp", -1).limit(limit)
    
    locations = []
    async for location in cursor:
        locations.append(LocationResponse(
            id=str(location["_id"]),
            bus_id=location["bus_id"],
            latitude=location["latitude"],
            longitude=location["longitude"],
            speed=location["speed"],
            timestamp=location["timestamp"],
            created_at=location["created_at"]
        ))
    
    return locations