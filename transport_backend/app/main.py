from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from .database import connect_to_mongo, close_mongo_connection
from .routes import gps, websocket
from .utils.nepal_time import get_nepal_time, format_nepal_time

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
    return {
        "status": "healthy", 
        "timestamp": get_nepal_time().isoformat(),
        "timezone": "Nepal Standard Time (NST)",
        "formatted_time": format_nepal_time()
    }
