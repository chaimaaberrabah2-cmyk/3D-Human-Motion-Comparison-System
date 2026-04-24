from typing import Optional, List, Any, Dict
from pydantic import BaseModel, EmailStr
from datetime import datetime


# ==========================================
# ESTABLISHMENT SCHEMAS
# ==========================================

class EstablishmentBase(BaseModel):
    name: str
    code: str
    contact_email: Optional[EmailStr] = None

class EstablishmentCreate(EstablishmentBase):
    pass

class Establishment(EstablishmentBase):
    establishment_id: int
    calibration_data: Optional[Any] = None
    created_at: datetime

    class Config:
        from_attributes = True


# ==========================================
# USER SCHEMAS
# ==========================================

# Shared properties
class UserBase(BaseModel):
    email: EmailStr
    pseudo: str


# Properties to receive via API on creation
class UserCreate(UserBase):
    password: str
    establishment_code: str


# Properties to receive via API on Google Sign In
class UserGoogleAuth(BaseModel):
    id_token: str


# Properties to receive via API on login
class UserLogin(BaseModel):
    email: EmailStr
    password: str


# Properties to return via API
class UserInDBBase(UserBase):
    user_id: int
    role: str
    profile_json: Optional[Dict[str, Any]] = None

    class Config:
        from_attributes = True


class User(UserInDBBase):
    pass


class Token(BaseModel):
    access_token: str
    token_type: str
    user: User


# Properties to receive via API on update
class UserUpdate(BaseModel):
    old_email: EmailStr
    new_email: EmailStr
    pseudo: str


# Properties to receive via API on password update
class UserPasswordUpdate(BaseModel):
    email: EmailStr
    old_password: str
    new_password: str


# Properties to receive via API on password reset
class UserResetPassword(BaseModel):
    email: EmailStr
    new_password: str


# Properties for updating body measurements / profile data (stored in profile_json)
class UserProfileUpdate(BaseModel):
    email: EmailStr
    height: Optional[str] = None   # in cm
    weight: Optional[str] = None   # in kg
    age: Optional[str] = None
    gender: Optional[str] = None
