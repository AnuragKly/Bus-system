import math

def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate the great circle distance between two points 
    on the earth (specified in decimal degrees)
    Returns distance in kilometers
    """
    # Convert decimal degrees to radians
    lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])

    # Haversine formula
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
    c = 2 * math.asin(math.sqrt(a))
    
    # Radius of earth in kilometers
    r = 6371
    return c * r

def estimate_arrival_time(distance_km: float, avg_speed_kmh: float = 25.0) -> int:
    """
    Estimate arrival time in minutes based on distance and average speed
    Default average speed for Kathmandu traffic: 25 km/h
    """
    if distance_km <= 0:
        return 0
    
    time_hours = distance_km / avg_speed_kmh
    return int(time_hours * 60)  # Convert to minutes