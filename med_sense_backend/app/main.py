import os
import hashlib
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from supabase import create_client, Client, ClientOptions
from dotenv import load_dotenv
import httpx

# --- Configuration ---
# Load environment variables
# Try loading from parent directory (common structure) or current directory
load_dotenv(dotenv_path="../enviroment.env")
load_dotenv()

# Prefer environment variables, fall back to hardcoded (existing)
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://toqvutxnatkjxtpttjog.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRvcXZ1dHhuYXRranh0cHR0am9nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0ODg1OTEsImV4cCI6MjA3OTA2NDU5MX0.D8bzPRlqXhPrc28fUFSw5GVPkPMwvRd-iUOECkrQbm0")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

app = FastAPI()

# Initialize Supabase Client (Standard/Anon) with increased timeout
supabase: Client = create_client(
    SUPABASE_URL, 
    SUPABASE_KEY,
    options=ClientOptions(postgrest_client_timeout=60, storage_client_timeout=60)
)
# Manually increase Auth client timeout (default is 5s)
if hasattr(supabase.auth, "_http_client"):
    supabase.auth._http_client.timeout = httpx.Timeout(60.0)


# Initialize Admin Client (if key available) with increased timeout
supabase_admin: Client = None
if SUPABASE_SERVICE_ROLE_KEY:
    supabase_admin = create_client(
        SUPABASE_URL, 
        SUPABASE_SERVICE_ROLE_KEY,
        options=ClientOptions(postgrest_client_timeout=60, storage_client_timeout=60)
    )
    # Manually increase Admin Auth client timeout
    if hasattr(supabase_admin.auth, "_http_client"):
        supabase_admin.auth._http_client.timeout = httpx.Timeout(60.0)
else:
    print("WARNING: SUPABASE_SERVICE_ROLE_KEY not found. Database insertions might fail due to RLS if email confirmation is enabled.")

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
        user_id = None
        
        # 1. Sign up with Supabase Auth
        if supabase_admin:
            # Use Admin API to create user and auto-confirm email (bypasses email sending limits/errors)
            # The 'create_user' method in the admin namespace allows explicit confirmation.
            admin_auth_response = supabase_admin.auth.admin.create_user({
                "email": user.email,
                "password": user.password,
                "email_confirm": True, # Auto-confirm the user
                "user_metadata": {
                    "full_name": user.full_name,
                    "phone_number": user.phone,
                    "dob": user.dob,
                    "is_oku": user.is_oku
                }
            })
            if not admin_auth_response.user:
                 raise HTTPException(status_code=400, detail="Signup failed: No user returned from Admin API")
            user_id = admin_auth_response.user.id
            
        else:
            # Fallback to standard flow (will trigger email confirmation)
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

        # Use admin client if available to bypass RLS, otherwise use standard client
        client_to_use = supabase_admin if supabase_admin else supabase
        
        db_response = client_to_use.table("Patient").insert(patient_data).execute()

        return {
            "status": "success", 
            "message": "Account created successfully.",
            "user_id": user_id
        }

    except Exception as e:
        # Check if it's a Supabase/API error and forward the message
        error_msg = str(e)
        if hasattr(e, 'message'):
            error_msg = e.message
        elif hasattr(e, 'detail'):
            error_msg = e.detail
            
        print(f"\n!!! SIGNUP ERROR DEBUG INFO !!!\nError Type: {type(e)}\nError Message: {error_msg}\n")
        
        raise HTTPException(status_code=400, detail=error_msg)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)