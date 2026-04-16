from typing import Optional, List, Any
from pydantic import BaseModel, EmailStr
from datetime import datetime

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
