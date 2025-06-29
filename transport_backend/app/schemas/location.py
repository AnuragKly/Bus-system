from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional

class GPSData(BaseModel):
    bus_id: str = Field(default="bus_001")  # For single bus initially
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    speed: float = Field(default=0.0, ge=0)
    timestamp: Optional[datetime] = None

class LocationResponse(BaseModel):
    id: str
    bus_id: str
    latitude: float
    longitude: float
    speed: float
    timestamp: datetime
    created_at: datetime

class CurrentLocation(BaseModel):
    bus_id: str
    latitude: float
    longitude: float
    speed: float
    last_updated: datetime