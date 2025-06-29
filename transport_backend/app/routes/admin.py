from fastapi import APIRouter, Depends, HTTPException, status
from motor.motor_asyncio import AsyncIOMotorDatabase
from datetime import datetime
from typing import List
from ..database import get_database
from ..schemas.user import UserResponse, UserStatus
from ..schemas.bus_status import BusStatusUpdate, BusStatusResponse
from ..dependencies import get_admin_user

router = APIRouter(prefix="/admin", tags=["admin"])

@router.get("/users/pending", response_model=List[UserResponse])
async def get_pending_users(
    admin_user: dict = Depends(get_admin_user),
    db: AsyncIOMotorDatabase = Depends(get_database)
):
    """Get all pending users for approval"""
    cursor = db.users.find({"status": UserStatus.PENDING})
    
    users = []
    async for user in cursor:
        users.append(UserResponse(
            id=str(user["_id"]),
            email=user["email"],
            role=user["role"],
            status=user["status"],
            created_at=user["created_at"]
        ))
    
    return users

@router.put("/users/{user_id}/approve")
async def approve_user(
    user_id: str,
    admin_user: dict = Depends(get_admin_user),
    db: AsyncIOMotorDatabase = Depends(get_database)
):
    """Approve a pending user"""
    from bson import ObjectId
    
    result = await db.users.update_one(
        {"_id": ObjectId(user_id), "status": UserStatus.PENDING},
        {"$set": {"status": UserStatus.APPROVED}}
    )
    
    if result.matched_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found or already processed"
        )
    
    return {"message": "User approved successfully"}

@router.put("/users/{user_id}/reject")
async def reject_user(
    user_id: str,
    admin_user: dict = Depends(get_admin_user),
    db: AsyncIOMotorDatabase = Depends(get_database)
):
    """Reject a pending user"""
    from bson import ObjectId
    
    result = await db.users.update_one(
        {"_id": ObjectId(user_id), "status": UserStatus.PENDING},
        {"$set": {"status": UserStatus.REJECTED}}
    )
    
    if result.matched_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found or already processed"
        )
    
    return {"message": "User rejected successfully"}

@router.put("/tracking-status", response_model=BusStatusResponse)
async def update_tracking_status(
    status_update: BusStatusUpdate,
    bus_id: str = "bus_001",
    admin_user: dict = Depends(get_admin_user),
    db: AsyncIOMotorDatabase = Depends(get_database)
):
    """Update GPS tracking status"""
    result = await db.bus_status.update_one(
        {"bus_id": bus_id},
        {
            "$set": {
                "is_tracking_enabled": status_update.is_tracking_enabled,
                "last_updated": datetime.utcnow(),
                "driver_id": str(admin_user["_id"])
            }
        },
        upsert=True
    )
    
    # Get updated status
    bus_status = await db.bus_status.find_one({"bus_id": bus_id})
    
    return BusStatusResponse(
        bus_id=bus_status["bus_id"],
        is_tracking_enabled=bus_status["is_tracking_enabled"],
        last_updated=bus_status["last_updated"],
        driver_id=bus_status.get("driver_id")
    )

@router.get("/tracking-status", response_model=BusStatusResponse)
async def get_tracking_status(
    bus_id: str = "bus_001",
    admin_user: dict = Depends(get_admin_user),
    db: AsyncIOMotorDatabase = Depends(get_database)
):
    """Get current tracking status"""
    bus_status = await db.bus_status.find_one({"bus_id": bus_id})
    
    if not bus_status:
        # Create default status if doesn't exist
        default_status = {
            "bus_id": bus_id,
            "is_tracking_enabled": True,
            "last_updated": datetime.utcnow(),
            "driver_id": str(admin_user["_id"])
        }
        await db.bus_status.insert_one(default_status)
        bus_status = default_status
    
    return BusStatusResponse(
        bus_id=bus_status["bus_id"],
        is_tracking_enabled=bus_status["is_tracking_enabled"],
        last_updated=bus_status["last_updated"],
        driver_id=bus_status.get("driver_id")
    )
