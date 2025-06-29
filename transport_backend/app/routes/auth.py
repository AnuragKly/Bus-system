from fastapi import APIRouter, Depends, HTTPException, status
from motor.motor_asyncio import AsyncIOMotorDatabase
from datetime import datetime, timedelta
from enum import Enum
from ..database import get_database
from ..schemas.user import UserCreate, UserLogin, Token, UserResponse
from ..dependencies import get_current_user
from ..utils.security import get_password_hash, verify_password, create_access_token
from ..config import settings

router = APIRouter(prefix="/auth", tags=["authentication"])

class UserStatus(str, Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"

@router.post("/register", response_model=dict)
async def register_user(
    user: UserCreate,
    db: AsyncIOMotorDatabase = Depends(get_database)
):
    """Register a new user"""
    # Check if user already exists
    existing_user = await db.users.find_one({"email": user.email})
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Create user document
    user_doc = {
        "email": user.email,
        "password_hash": get_password_hash(user.password),
        "role": user.role,
        "status": UserStatus.PENDING.value,  # <-- use .value here!
        "created_at": datetime.utcnow()
    }
    
    result = await db.users.insert_one(user_doc)
    
    return {
        "message": "User registered successfully. Waiting for admin approval.",
        "user_id": str(result.inserted_id)
    }

@router.post("/login", response_model=Token)
async def login_user(
    user: UserLogin,
    db: AsyncIOMotorDatabase = Depends(get_database)
):
    """Login user"""
    db_user = await db.users.find_one({"email": user.email})

    print("DEBUG: db_user['status'] =", db_user["status"], "| UserStatus.APPROVED.value =", UserStatus.APPROVED.value)

    if not db_user or not verify_password(user.password, db_user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )

    if db_user["status"] != UserStatus.APPROVED.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account not approved yet"
        )
    
    access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
    access_token = create_access_token(
        data={"sub": user.email}, expires_delta=access_token_expires
    )
    
    user_response = UserResponse(
        id=str(db_user["_id"]),
        email=db_user["email"],
        role=db_user["role"],
        status=db_user["status"],
        created_at=db_user["created_at"]
    )
    
    return Token(
        access_token=access_token,
        token_type="bearer",
        user=user_response
    )

@router.get("/me", response_model=UserResponse)
async def get_current_user_info(current_user: dict = Depends(get_current_user)):
    """Get current user information"""
    return UserResponse(
        id=str(current_user["_id"]),
        email=current_user["email"],
        role=current_user["role"],
        status=current_user["status"],
        created_at=current_user["created_at"]
    )