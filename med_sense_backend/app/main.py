import os
import uuid
from fastapi import FastAPI, HTTPException, status
from supabase import create_client, Client
from dotenv import load_dotenv
from ..schemas import PatientCreate, PatientUpdate, PatientResponse, PasswordUpdate
from ..security import get_password_hash

# 1. Load Environment Variables
load_dotenv()
url: str = os.environ.get("https://toqvutxnatkjxtpttjog.supabase.co")
key: str = os.environ.get("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRvcXZ1dHhuYXRranh0cHR0am9nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0ODg1OTEsImV4cCI6MjA3OTA2NDU5MX0.D8bzPRlqXhPrc28fUFSw5GVPkPMwvRd-iUOECkrQbm0")

# 2. Initialize Supabase Client
supabase: Client = create_client(url, key)

# 3. Initialize FastAPI
app = FastAPI(title="MedSense Patient Backend")

# --- ENDPOINTS ---

@app.post("/patients/", response_model=PatientResponse, status_code=status.HTTP_201_CREATED)
def create_patient(patient: PatientCreate):
    """
    Insert a new patient into the database.
    Hashes the password before storing.
    """
    # 1. Hash the password
    hashed_pw = get_password_hash(patient.password)

    # 2. Prepare data for Supabase
    patient_data = {
        "name": patient.name,
        "email": patient.email,
        "password_hash": hashed_pw,
        "dob": patient.dob.isoformat() if patient.dob else None,
        "phone_number": patient.phone_number,
        "is_oku": patient.is_oku
    }

    try:
        # 3. Insert into 'Patient' table
        response = supabase.table("Patient").insert(patient_data).execute()
        
        # Check if data was returned
        if not response.data:
            raise HTTPException(status_code=400, detail="Failed to create patient.")
            
        return response.data[0]

    except Exception as e:
        # Handle duplicate email or connection errors
        raise HTTPException(status_code=400, detail=str(e))


@app.get("/patients/{patient_id}", response_model=PatientResponse)
def get_patient(patient_id: uuid.UUID):
    """
    Retrieve a patient's profile information by ID.
    """
    response = supabase.table("Patient").select("*").eq("patient_id", str(patient_id)).execute()
    
    if not response.data:
        raise HTTPException(status_code=404, detail="Patient not found")
    
    return response.data[0]


@app.put("/patients/{patient_id}", response_model=PatientResponse)
def update_patient_info(patient_id: uuid.UUID, patient_update: PatientUpdate):
    """
    Edit personal information (Name, DOB, Phone, Is_OKU).
    Ignores fields that are not sent.
    """
    # Filter out None values so we only update what was sent
    update_data = {k: v for k, v in patient_update.dict(exclude_unset=True).items() if v is not None}
    
    if "dob" in update_data:
        update_data["dob"] = update_data["dob"].isoformat()

    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided for update")

    try:
        response = supabase.table("Patient").update(update_data).eq("patient_id", str(patient_id)).execute()
        
        if not response.data:
            raise HTTPException(status_code=404, detail="Patient not found or update failed")
            
        return response.data[0]

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.put("/patients/{patient_id}/password", status_code=status.HTTP_200_OK)
def update_password(patient_id: uuid.UUID, password_data: PasswordUpdate):
    """
    Specific endpoint to update ONLY the password.
    Hashes the new password before saving.
    """
    new_hash = get_password_hash(password_data.new_password)
    
    try:
        response = supabase.table("Patient").update(
            {"password_hash": new_hash}
        ).eq("patient_id", str(patient_id)).execute()

        if not response.data:
            raise HTTPException(status_code=404, detail="Patient not found")
            
        return {"message": "Password updated successfully"}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))