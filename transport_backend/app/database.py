from motor.motor_asyncio import AsyncIOMotorClient
from .config import settings

class Database:
    client: AsyncIOMotorClient = None
    database = None

db = Database()

async def get_database():
    return db.database

async def connect_to_mongo():
    """Create database connection"""
    db.client = AsyncIOMotorClient(settings.mongodb_url)
    db.database = db.client[settings.database_name]
    
    # Create indexes for better performance
    await db.database.locations.create_index([("timestamp", -1)])
    await db.database.locations.create_index([("bus_id", 1)])
    await db.database.users.create_index([("email", 1)], unique=True)

async def close_mongo_connection():
    """Close database connection"""
    db.client.close()