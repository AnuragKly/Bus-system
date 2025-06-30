"""
Nepal Timezone Utilities
Handles Nepal Standard Time (NST) conversions and formatting
NST = UTC + 5:45
"""

from datetime import datetime, timedelta, timezone
from typing import Optional

# Nepal Standard Time timezone (UTC + 5:45)
NEPAL_TIMEZONE = timezone(timedelta(hours=5, minutes=45))

def get_nepal_time() -> datetime:
    """Get current time in Nepal Standard Time"""
    return datetime.now(NEPAL_TIMEZONE)

def utc_to_nepal_time(utc_dt: datetime) -> datetime:
    """Convert UTC datetime to Nepal Standard Time"""
    if utc_dt.tzinfo is None:
        # Assume naive datetime is UTC
        utc_dt = utc_dt.replace(tzinfo=timezone.utc)
    return utc_dt.astimezone(NEPAL_TIMEZONE)

def nepal_time_to_utc(nepal_dt: datetime) -> datetime:
    """Convert Nepal time to UTC"""
    if nepal_dt.tzinfo is None:
        # Assume naive datetime is Nepal time
        nepal_dt = nepal_dt.replace(tzinfo=NEPAL_TIMEZONE)
    return nepal_dt.astimezone(timezone.utc)

def format_nepal_time(dt: Optional[datetime] = None) -> str:
    """Format datetime as Nepal Standard Time string"""
    if dt is None:
        dt = get_nepal_time()
    elif dt.tzinfo is None:
        # Assume UTC if no timezone info
        dt = dt.replace(tzinfo=timezone.utc).astimezone(NEPAL_TIMEZONE)
    else:
        dt = dt.astimezone(NEPAL_TIMEZONE)
    
    return dt.strftime("%Y-%m-%d %H:%M:%S NST")

def parse_nepal_timestamp(timestamp_str: str) -> datetime:
    """Parse timestamp string that may be in various formats"""
    try:
        # Try parsing ESP32 format: "2025-06-30T17:00:54+05:45"
        if "+05:45" in timestamp_str:
            dt_str = timestamp_str.replace("+05:45", "")
            dt = datetime.fromisoformat(dt_str)
            return dt.replace(tzinfo=NEPAL_TIMEZONE)
        
        # Try parsing standard ISO format
        if "T" in timestamp_str:
            dt = datetime.fromisoformat(timestamp_str.replace("Z", "+00:00"))
            return dt.astimezone(NEPAL_TIMEZONE)
        
        # Fallback: assume UTC
        dt = datetime.fromisoformat(timestamp_str)
        return dt.replace(tzinfo=timezone.utc).astimezone(NEPAL_TIMEZONE)
        
    except Exception:
        # If all parsing fails, return current Nepal time
        return get_nepal_time()
