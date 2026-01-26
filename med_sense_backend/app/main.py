import os
import hashlib
from datetime import datetime
from typing import List, Optional

from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
from supabase import create_client, Client, ClientOptions
from dotenv import load_dotenv
import httpx

# --- Configuration ---

load_dotenv(dotenv_path="../.env")
load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError("SUPABASE_URL and SUPABASE_KEY must be set in the .env file")

app = FastAPI()

supabase: Client = create_client(
    SUPABASE_URL,
    SUPABASE_KEY,
    options=ClientOptions(
        postgrest_client_timeout=60,
        storage_client_timeout=60,
    ),
)

if hasattr(supabase.auth, "_http_client"):
    supabase.auth._http_client.timeout = httpx.Timeout(60.0)

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
    if hasattr(supabase_admin.auth, "_http_client"):
        supabase_admin.auth._http_client.timeout = httpx.Timeout(60.0)
else:
    print(
        "WARNING: SUPABASE_SERVICE_ROLE_KEY not found. "
        "Database insertions might fail due to RLS if email confirmation is enabled."
    )

# --- Pydantic Models ---

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

class RescheduleRequest(BaseModel):
    appointment_id: str
    new_datetime: datetime

class BookingRequest(BaseModel):
    patient_id: str
    preferred_datetime: datetime
    service_id: Optional[str] = None
    doctor_id: Optional[str] = None
    notes: Optional[str] = None

class SupportRequest(BaseModel):
    patient_id: str
    message: str

class SupportResponse(BaseModel):
    message: str

# --- Helper Functions ---

def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()

ACTIVE_QUEUE_STATUSES = ["Waiting", "In Progress"]

def is_within_working_hours(dt: datetime) -> bool:
    """
    Medsense clinic hours:
    09:00–21:30, Monday–Sunday.
    """
    # Allow all days, just clamp time
    start_minutes = 9 * 60          # 09:00
    end_minutes = 21 * 60 + 30      # 21:30

    m = dt.hour * 60 + dt.minute
    return start_minutes <= m <= end_minutes

def get_db() -> Client:
    return supabase_admin if supabase_admin else supabase

# --- Endpoints ---

# --- Endpoints ---

@app.post("/signup")
async def signup_user(user: SignupRequest):
    try:
        user_id = None

        if supabase_admin:
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

        patient_data = {
            "patient_id": user_id,
            "name": user.full_name,
            "email": user.email,
            "password_hash": hash_password(user.password),
            "dob": user.dob,
            "phone_number": user.phone,
            "is_oku": user.is_oku,
        }

        db = get_db()
        db.table("Patient").insert(patient_data).execute()

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
    db = get_db()

    resp = (
        db.table("Appointment")
        .select("appointment_id, appointment_datetime, status")
        .eq("patient_id", patient_id)
        .in_("status", ["Scheduled", "Rescheduled", "Confirmed"])
        .order("appointment_datetime", desc=False)
        .execute()
    )

    data = getattr(resp, "data", None)
    if data is None:
        data = []

    return data

@app.post("/appointments/reschedule")
async def reschedule_appointment(payload: RescheduleRequest):
    db = get_db()

    if not is_within_working_hours(payload.new_datetime):
        raise HTTPException(
            status_code=400,
            detail="New time is outside clinic working hours (9:00 AM – 9:30 PM).",
        )

    # Fetch existing appointment to get doctor/service
    appt_resp = (
        db.table("Appointment")
        .select("doctor_id, service_id")
        .eq("appointment_id", payload.appointment_id)
        .limit(1)
        .execute()
    )
    appt_data = getattr(appt_resp, "data", None) or []
    if not appt_data:
        raise HTTPException(status_code=404, detail="Appointment not found")

    doctor_id = appt_data[0].get("doctor_id")
    service_id = appt_data[0].get("service_id")

    # Check for double booking (same doctor/service, same time)
    conflict_query = (
        db.table("Appointment")
        .select("appointment_id")
        .eq("appointment_datetime", payload.new_datetime.isoformat())
        .in_("status", ["Scheduled", "Rescheduled", "Confirmed"])
    )
    if doctor_id:
        conflict_query = conflict_query.eq("doctor_id", doctor_id)
    if service_id:
        conflict_query = conflict_query.eq("service_id", service_id)

    conflict_resp = conflict_query.execute()
    conflicts = getattr(conflict_resp, "data", None) or []

    # Ignore self if same appointment_id; here we only used datetime+doc/service,
    # so better just ensure no conflict at all for that slot.
    if conflicts:
        raise HTTPException(
            status_code=400,
            detail="This time slot is already taken for this doctor. Please choose another time.",
        )

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

    data = getattr(resp, "data", None) or []
    if not data:
        raise HTTPException(status_code=404, detail="Appointment not found")

    return {"status": "success", "message": "Appointment rescheduled."}

@app.post("/appointments/book")
async def book_appointment(payload: BookingRequest):
    db = get_db()

    if not is_within_working_hours(payload.preferred_datetime):
        raise HTTPException(
            status_code=400,
            detail="Selected time is outside clinic working hours (9:00 AM – 9:30 PM).",
        )

    # Check for existing active appointment same doctor+time
    conflict_query = (
        db.table("Appointment")
        .select("appointment_id")
        .eq("appointment_datetime", payload.preferred_datetime.isoformat())
        .in_("status", ["Scheduled", "Rescheduled", "Confirmed"])
    )
    if payload.doctor_id:
        conflict_query = conflict_query.eq("doctor_id", payload.doctor_id)
    if payload.service_id:
        conflict_query = conflict_query.eq("service_id", payload.service_id)

    conflict_resp = conflict_query.execute()
    conflicts = getattr(conflict_resp, "data", None) or []
    if conflicts:
        raise HTTPException(
            status_code=400,
            detail="This time slot is already fully booked. Please choose another time.",
        )

    insert_data = {
        "patient_id": payload.patient_id,
        "appointment_datetime": payload.preferred_datetime.isoformat(),
        "status": "Requested",
        "service_id": payload.service_id,
        "doctor_id": payload.doctor_id,
        "notes": payload.notes,
    }

    resp = db.table("Appointment").insert(insert_data).execute()
    inserted = getattr(resp, "data", None) or []
    if not inserted:
        raise HTTPException(status_code=400, detail="Failed to create appointment")

    return {
        "status": "success",
        "appointment_id": inserted[0]["appointment_id"],
    }

@app.post("/support", response_model=SupportResponse)
async def send_support(request: SupportRequest):
    db = get_db()

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

@app.get("/queue_status")
async def get_queue_status(patient_id: str = Query(...)):
    """
    Returns the latest active queue entry for a patient plus people ahead
    and an optional estimated wait time (in minutes).
    """
    try:
        db = get_db()

        queue_query = (
            db.table("QueueEntry")
            .select("*")
            .eq("patient_id", patient_id)
            .in_("status", ACTIVE_QUEUE_STATUSES)
            .order("check_in_time", desc=True)
            .limit(1)
            .execute()
        )

        queue_data = getattr(queue_query, "data", None) or []
        if not queue_data:
            return {
                "status": "no_active_queue",
                "message": "You are not currently in the queue.",
            }

        queue_entry = queue_data[0]
        queue_number = queue_entry["queue_number"]
        doctor_id = queue_entry.get("doctor_id")
        service_id = queue_entry.get("service_id")
        appointment_id = queue_entry.get("appointment_id")
        queue_status = queue_entry["status"]

        ahead_query = (
            db.table("QueueEntry")
            .select("queue_number")
            .eq("status", "Waiting")
        )

        if doctor_id:
            ahead_query = ahead_query.eq("doctor_id", doctor_id)
        if service_id:
            ahead_query = ahead_query.eq("service_id", service_id)

        ahead_query = ahead_query.lt("queue_number", queue_number).execute()
        ahead_data = getattr(ahead_query, "data", None) or []
        people_ahead = len(ahead_data)

        est_wait_minutes: Optional[int] = None
        if appointment_id:
            appt_query = (
                db.table("Appointment")
                .select("predicted_wait_time_minutes")
                .eq("appointment_id", appointment_id)
                .limit(1)
                .execute()
            )
            appt_data = getattr(appt_query, "data", None) or []
            if appt_data:
                est_wait_minutes = appt_data[0].get("predicted_wait_time_minutes")

        return {
            "status": "ok",
            "queue_number": queue_number,
            "queue_status": queue_status,
            "people_ahead": people_ahead,
            "appointment_id": appointment_id,
            "doctor_id": doctor_id,
            "service_id": service_id,
            "estimated_wait_minutes": est_wait_minutes,
            "check_in_time": queue_entry.get("check_in_time"),
        }

    except Exception as e:
        print("QUEUE_STATUS ERROR:", e)
        raise HTTPException(status_code=500, detail="Failed to fetch queue status")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
