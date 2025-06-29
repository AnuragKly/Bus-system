from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional
from datetime import datetime
from enum import Enum

class UserRole(str, Enum):
    STUDENT = "student"
    STAFF = "staff"
    ADMIN = "admin"

class UserStatus(str, Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    role: UserRole = UserRole.STUDENT
    
    @field_validator('email')
    @classmethod
    def validate_ku_email(cls, v):
        if not str(v).endswith('@ku.edu.np'):
            raise ValueError('Email must be a valid KU email (@ku.edu.np)')
        return v

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserResponse(BaseModel):
    id: str
    email: str
    role: UserRole
    status: UserStatus = UserStatus.APPROVED
    created_at: datetime

class Token(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse


