from fastapi import FastAPI, HTTPException, Header, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
from typing import Optional, List
from auth import verify_jwt, require_admin

app = FastAPI(title="EyeVLM Inference Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False, # Bearer tokens don't require cookies/credentials
    allow_methods=["*"],
    allow_headers=["*"],
)

class InferenceRequest(BaseModel):
    image_url: str
    symptoms: str
    language: Optional[str] = "en"

class InferenceResult(BaseModel):
    predicted_class: str
    confidence: dict
    explanation_text: str

@app.get("/")
def health_check():
    return {"status": "ok", "message": "EyeVLM Backend Running"}

@app.post("/infer", response_model=InferenceResult)
def run_inference(
    request: InferenceRequest,
    payload: dict = Depends(verify_jwt) # Protects endpoint
):
    """
    Phase 1: Dummy Inference Logic.
    This behaves exactly like the final model will, but returns static data.
    """
    
    # In Phase 2, we will load the model here.
    
    print(f"Processing image: {request.image_url}")
    print(f"Symptoms: {request.symptoms}")
    print(f"Language: {request.language}")
    
    explanation = "The image shows clouding of the clear lens of the eye which is characteristic of a cataract. Your reported symptoms of 'blurred vision' align with this indication."
    
    if request.language == 'bn':
        explanation = "ছবিটিতে চোখের লেন্সের ঘোলাটে ভাব দেখা যাচ্ছে যা ছানি (Cataract) এর লক্ষণ। আপনার বর্ণিত 'ঝাপসা দৃষ্টি' লক্ষণটি এর সাথে সামঞ্জস্যপূর্ণ।"

    return {
        "predicted_class": "Cataract",
        "confidence": {
            "Cataract": 0.78,
            "Keratitis": 0.10,
            "Uveitis": 0.05,
            "Pterygium": 0.04,
            "Conjunctivitis": 0.03
        },
        "explanation_text": explanation
    }

@app.post("/admin/retrain")
def retrain_model(
    payload: dict = Depends(verify_jwt)
):
    require_admin(payload) # Only admin can trigger
    return {"status": "started", "message": "Retraining job queued."}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
