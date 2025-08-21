from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from .database import connect_to_mongo, close_mongo_connection
from .routes import gps, websocket
from .utils.nepal_time import get_nepal_time, format_nepal_time

# Import working advanced GPS routes
try:
    from .routes import gps_simple_advanced
    ADVANCED_GPS_AVAILABLE = True
    print("✅ Advanced GPS tracking (simple implementation) loaded")
except ImportError as e:
    print(f"⚠️ Advanced GPS routes not available: {e}")
    ADVANCED_GPS_AVAILABLE = False

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await connect_to_mongo()
    yield
    # Shutdown
    await close_mongo_connection()

app = FastAPI(
    title="Transport Management System API",
    description="GPS tracking system for Kathmandu University buses",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routes
app.include_router(gps.router)

# Include advanced GPS routes if available
if ADVANCED_GPS_AVAILABLE:
    app.include_router(gps_simple_advanced.router, prefix="/advanced")
    print("✅ Advanced GPS routes included at /advanced/gps/*")
else:
    print("⚠️ Advanced GPS routes not included - using basic GPS only")

app.include_router(websocket.router)

@app.get("/")
async def root():
    return {
        "message": "Transport Management System API",
        "version": "1.0.0",
        "status": "running"
    }

@app.get("/health")
async def health_check():
    algorithms = []
    endpoints = {"basic_gps": "/gps/*"}
    
    if ADVANCED_GPS_AVAILABLE:
        algorithms.extend([
            "Kalman Filter for GPS accuracy",
            "Route-based ETA calculation",
            "Real-time traffic integration"
        ])
        endpoints["advanced_gps"] = "/advanced/gps/*"
    else:
        algorithms.extend([
            "Basic GPS tracking",
            "Distance-based ETA calculation"
        ])
    
    return {
        "status": "healthy", 
        "timestamp": get_nepal_time().isoformat(),
        "timezone": "Nepal Standard Time (NST)",
        "formatted_time": format_nepal_time(),
        "algorithms": algorithms,
        "endpoints": endpoints,
        "advanced_tracking": ADVANCED_GPS_AVAILABLE
    }
