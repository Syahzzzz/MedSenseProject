from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import date
import uuid

# --- Base Model (Shared fields) ---
class PatientBase(BaseModel):
    name: str
    email: EmailStr
    dob: Optional[date] = None
    phone_number: Optional[str] = None
    is_oku: bool = False

# --- Input: Create Patient ---
class PatientCreate(PatientBase):
    password: str = Field(..., min_length=6, description="Raw password to be hashed")

# --- Input: Update Profile Info (No password here) ---
class PatientUpdate(BaseModel):
    name: Optional[str] = None
    dob: Optional[date] = None
    phone_number: Optional[str] = None
    is_oku: Optional[bool] = None
    # We typically don't allow email updates easily without re-verification logic, 
    # but you can add it here if needed.

# --- Input: Update Password ---
class PasswordUpdate(BaseModel):
    new_password: str = Field(..., min_length=6)

# --- Output: Patient Response (Hide password hash) ---
class PatientResponse(PatientBase):
    patient_id: uuid.UUID

    class Config:
        from_attributes = True