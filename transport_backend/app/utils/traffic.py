import os
import httpx

OPENROUTESERVICE_API_KEY = os.getenv("OPENROUTESERVICE_API_KEY", "YOUR_API_KEY_HERE")

async def get_live_traffic_factor(start_lat, start_lon, end_lat, end_lon):
    """
    Fetch live traffic data from OpenRouteService and return a traffic factor.
    Returns a float: >1.0 means slower due to congestion, <1.0 means faster than normal.
    """
    url = "https://api.openrouteservice.org/v2/directions/driving-car"
    headers = {"Authorization": OPENROUTESERVICE_API_KEY}
    params = {
        "start": f"{start_lon},{start_lat}",
        "end": f"{end_lon},{end_lat}"
    }
    async with httpx.AsyncClient() as client:
        response = await client.get(url, headers=headers, params=params)
        if response.status_code == 200:
            data = response.json()
            summary = data["features"][0]["properties"]["summary"]
            duration_real = summary["duration"] / 60  # seconds to minutes
            distance_km = summary["distance"] / 1000  # meters to km
            # Assume normal speed is 25 km/h
            normal_time = (distance_km / 25.0) * 60
            traffic_factor = duration_real / normal_time if normal_time > 0 else 1.0
            return max(traffic_factor, 0.5)  # Clamp to avoid zero/negative
        else:
            # Zone-based TCF: high (Kathmandu), medium (Bhaktapur), low (Banepa/Dhulikhel)
            from datetime import datetime
            hour = datetime.now().hour
            # Define longitude boundaries (approximate)
            JADIBUTI_LON = 85.355
            SANGA_LON = 85.465
            # Use start_lon to determine zone (could also interpolate route for more accuracy)
            if start_lon < JADIBUTI_LON:
                # Kathmandu Valley (high congestion)
                if 7 <= hour <= 10 or 16 <= hour <= 20:
                    return 1.7  # Peak
                elif 10 < hour < 16:
                    return 1.3  # Off-peak
                else:
                    return 1.1  # Night/early morning
            elif JADIBUTI_LON <= start_lon < SANGA_LON:
                # Bhaktapur to Sanga (medium congestion)
                if 7 <= hour <= 10 or 16 <= hour <= 20:
                    return 1.4  # Peak (reduced)
                elif 10 < hour < 16:
                    return 1.15  # Off-peak (reduced)
                else:
                    return 1.05  # Night/early morning (reduced)
            else:
                # East of Sanga: Banepa, Dhulikhel (low congestion)
                if 7 <= hour <= 10 or 16 <= hour <= 20:
                    return 1.15  # Peak (minimal congestion)
                elif 10 < hour < 16:
                    return 1.05  # Off-peak (minimal congestion)
                else:
                    return 1.0  # Night/early morning (minimal congestion)
