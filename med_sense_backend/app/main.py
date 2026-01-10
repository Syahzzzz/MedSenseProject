import os
import hashlib
from datetime import datetime
from typing import List, Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from supabase import create_client, Client, ClientOptions
from dotenv import load_dotenv
import httpx

# --- Configuration ---

# Try loading from parent directory (common structure) or current directory
load_dotenv(dotenv_path="../enviroment.env")
load_dotenv()

# Prefer environment variables, fall back to hardcoded (existing)
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://toqvutxnatkjxtpttjog.supabase.co")
SUPABASE_KEY = os.getenv(
    "SUPABASE_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRvcXZ1dHhuYXRranh0cHR0am9nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0ODg1OTEsImV4cCI6MjA3OTA2NDU5MX0.D8bzPRlqXhPrc28fUFSw5GVPkPMwvRd-iUOECkrQbm0",
)
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

app = FastAPI()

# Initialize Supabase Client (Standard/Anon) with increased timeout
supabase: Client = create_client(
    SUPABASE_URL,
    SUPABASE_KEY,
    options=ClientOptions(
        postgrest_client_timeout=60,
        storage_client_timeout=60,
    ),
)

# Manually increase Auth client timeout (default is 5s)
if hasattr(supabase.auth, "_http_client"):
    supabase.auth._http_client.timeout = httpx.Timeout(60.0)

# Initialize Admin Client (if key available) with increased timeout
supabase_admin: Optional[Client] = None
if SUPABASE_SERVICE_ROLE_KEY:
    supabase_admin = create_client(
        SUPABASE_URL,
        SUPABASE_SERVICE_ROLE_KEY,
        options=ClientOptions(
            postgrest_client_timeout=60,
            storage_client_timeout=60,
        ),
    )

    # Manually increase Admin Auth client timeout
    if hasattr(supabase_admin.auth, "_http_client"):
        supabase_admin.auth._http_client.timeout = httpx.Timeout(60.0)
else:
    print(
        "WARNING: SUPABASE_SERVICE_ROLE_KEY not found. "
        "Database insertions might fail due to RLS if email confirmation is enabled."
    )

# --- Pydantic Models (Data Transfer Objects) ---


class SignupRequest(BaseModel):
    full_name: str
    email: str
    phone: str
    dob: str
    password: str
    is_oku: bool


class AppointmentOut(BaseModel):
    appointment_id: str
    appointment_datetime: datetime
    status: str


class SupportRequest(BaseModel):
    patient_id: str
    message: str


class SupportResponse(BaseModel):
    message: str


class RescheduleRequest(BaseModel):
    appointment_id: str
    new_datetime: datetime


# --- Helper Functions ---


def hash_password(password: str) -> str:
    """Replicates the SHA256 hashing from the original Dart code"""
    return hashlib.sha256(password.encode("utf-8")).hexdigest()


# --- Endpoints ---


@app.post("/signup")
async def signup_user(user: SignupRequest):
    try:
        user_id = None

        # 1. Sign up with Supabase Auth
        if supabase_admin:
            # Use Admin API to create user and auto-confirm email
            admin_auth_response = supabase_admin.auth.admin.create_user(
                {
                    "email": user.email,
                    "password": user.password,
                    "email_confirm": True,
                    "user_metadata": {
                        "full_name": user.full_name,
                        "phone_number": user.phone,
                        "dob": user.dob,
                        "is_oku": user.is_oku,
                    },
                }
            )

            if not admin_auth_response.user:
                raise HTTPException(
                    status_code=400,
                    detail="Signup failed: No user returned from Admin API",
                )
            user_id = admin_auth_response.user.id
        else:
            # Fallback to standard flow (will trigger email confirmation)
            auth_response = supabase.auth.sign_up(
                {
                    "email": user.email,
                    "password": user.password,
                    "options": {
                        "data": {
                            "full_name": user.full_name,
                            "phone_number": user.phone,
                            "dob": user.dob,
                            "is_oku": user.is_oku,
                        }
                    },
                }
            )

            if not auth_response.user:
                raise HTTPException(
                    status_code=400, detail="Signup failed: No user returned"
                )
            user_id = auth_response.user.id

        # 2. Insert into custom Patient Table
        patient_data = {
            "patient_id": user_id,
            "name": user.full_name,
            "email": user.email,
            "password_hash": hash_password(user.password),
            "dob": user.dob,
            "phone_number": user.phone,
            "is_oku": user.is_oku,
        }

        client_to_use = supabase_admin if supabase_admin else supabase
        client_to_use.table("Patient").insert(patient_data).execute()

        return {
            "status": "success",
            "message": "Account created successfully.",
            "user_id": user_id,
        }

    except Exception as e:
        error_msg = str(e)
        if hasattr(e, "message"):
            error_msg = e.message
        elif hasattr(e, "detail"):
            error_msg = e.detail

        print(
            f"\n!!! SIGNUP ERROR DEBUG INFO !!!\n"
            f"Error Type: {type(e)}\n"
            f"Error Message: {error_msg}\n"
        )
        raise HTTPException(status_code=400, detail=error_msg)


@app.get("/appointments", response_model=List[AppointmentOut])
async def get_appointments(patient_id: str):
    db = supabase_admin if supabase_admin else supabase

    resp = (
        db.table("Appointment")
        .select("appointment_id, appointment_datetime, status")
        .eq("patient_id", patient_id)
        .in_("status", ["Scheduled", "Rescheduled", "Confirmed"])  # <‑ only active
        .order("appointment_datetime", desc=False)
        .execute()
    )

    # Supabase Python client returns an object with a .data attribute
    data = getattr(resp, "data", None)
    if data is None:
      data = []

    return data

@app.post("/appointments/reschedule")
async def reschedule_appointment(payload: RescheduleRequest):
    """
    Update an appointment's datetime and mark it as Rescheduled.
    """
    db = supabase_admin if supabase_admin else supabase

    resp = (
        db.table("Appointment")
        .update(
            {
                "appointment_datetime": payload.new_datetime.isoformat(),
                "status": "Rescheduled",
            }
        )
        .eq("appointment_id", payload.appointment_id)
        .execute()
    )

    data = getattr(resp, "data", None) or resp.get("data", [])
    if not data:
        raise HTTPException(status_code=404, detail="Appointment not found")

    return {"status": "success", "message": "Appointment rescheduled."}


@app.post("/support", response_model=SupportResponse)
async def send_support(request: SupportRequest):
    """
    Store a patient support/reschedule/refund request for clinic staff.
    Used by the Flutter BotSense 'support' / 'help' intent.
    """
    db = supabase_admin if supabase_admin else supabase

    db.table("Message").insert(
        {
            "sender_type": "patient",
            "sender_id": request.patient_id,
            "recipient_id": None,
            "message_content": request.message,
        }
    ).execute()

    db.table("Notification").insert(
        {
            "recipient_id": request.patient_id,
            "message_content": "Your request has been sent to the clinic.",
            "link": None,
        }
    ).execute()

    return SupportResponse(
        message=(
            "Your request has been sent to the clinic team. "
            "They will review your reschedule or support request and follow up soon."
        )
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
