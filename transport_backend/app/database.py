from motor.motor_asyncio import AsyncIOMotorClient
from .config import settings

# Global variables for database connection
client = None
database = None

async def get_database():
    return database

async def connect_to_mongo():
    """Create database connection"""
    global client, database
    client = AsyncIOMotorClient(settings.mongodb_url)
    database = client[settings.database_name]
    
    # Create indexes for better performance
    await database.locations.create_index([("timestamp", -1)])
    await database.locations.create_index([("bus_id", 1)])

async def close_mongo_connection():
    """Close database connection"""
    global client
    if client:
        client.close()
    