import os
import hashlib
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from supabase import create_client, Client

# --- Configuration ---
# Replace these with your actual Supabase credentials
SUPABASE_URL = "https://toqvutxnatkjxtpttjog.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRvcXZ1dHhuYXRranh0cHR0am9nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0ODg1OTEsImV4cCI6MjA3OTA2NDU5MX0.D8bzPRlqXhPrc28fUFSw5GVPkPMwvRd-iUOECkrQbm0"

app = FastAPI()

# Initialize Supabase Client
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# --- Pydantic Models (Data Transfer Objects) ---
class SignupRequest(BaseModel):
    full_name: str
    email: str
    phone: str
    dob: str
    password: str
    is_oku: bool

# --- Helper Functions ---
def hash_password(password: str) -> str:
    """Replicates the SHA256 hashing from the original Dart code"""
    return hashlib.sha256(password.encode('utf-8')).hexdigest()

# --- Endpoints ---
@app.post("/signup")
async def signup_user(user: SignupRequest):
    try:
        # 1. Sign up with Supabase Auth
        # Note: We pass metadata so it lives in auth.users as well
        auth_response = supabase.auth.sign_up({
            "email": user.email,
            "password": user.password,
            "options": {
                "data": {
                    "full_name": user.full_name,
                    "phone_number": user.phone,
                    "dob": user.dob,
                    "is_oku": user.is_oku
                }
            }
        })

        if not auth_response.user:
            raise HTTPException(status_code=400, detail="Signup failed: No user returned")

        user_id = auth_response.user.id

        # 2. Insert into custom Patient Table
        # We handle the hashing here on the backend now
        patient_data = {
            "patient_id": user_id,
            "name": user.full_name,
            "email": user.email,
            "password_hash": hash_password(user.password),
            "dob": user.dob,
            "phone_number": user.phone,
            "is_oku": user.is_oku
        }

        db_response = supabase.table("Patient").insert(patient_data).execute()

        return {
            "status": "success", 
            "message": "Account created successfully",
            "user_id": user_id
        }

    except Exception as e:
        # Check if it's a Supabase/API error and forward the message
        error_msg = str(e)
        if hasattr(e, 'message'):
            error_msg = e.message
        elif hasattr(e, 'detail'):
            error_msg = e.detail
            
        raise HTTPException(status_code=400, detail=error_msg)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)