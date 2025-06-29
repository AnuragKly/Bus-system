from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class BusStatusUpdate(BaseModel):
    is_tracking_enabled: bool

class BusStatusResponse(BaseModel):
    bus_id: str
    is_tracking_enabled: bool
    last_updated: datetime
    driver_id: Optional[str]