"""
Sentiment Analysis API - Version 2 (Debug)
Debug version with additional information
"""

from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
import joblib
import os
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response
import time
from datetime import datetime

# Initialize FastAPI app
app = FastAPI(
    title="Sentiment Analysis API v2 (Debug)",
    description="Debug version with additional information",
    version="2.0.0"
)

# Prometheus metrics
REQUEST_COUNT = Counter(
    'api_requests_total', 
    'Total API requests',
    ['method', 'endpoint', 'status']
)
REQUEST_DURATION = Histogram(
    'api_request_duration_seconds',
    'API request duration in seconds',
    ['method', 'endpoint']
)

# Load the ML model
MODEL_PATH = os.getenv("MODEL_PATH", "/app/models/model.joblib")

try:
    model = joblib.load(MODEL_PATH)
    print(f"✓ Model loaded successfully from {MODEL_PATH}")
except Exception as e:
    print(f"✗ Error loading model: {e}")
    model = None


class SentenceInput(BaseModel):
    """Input schema for sentiment analysis"""
    sentence: str
    
    class Config:
        json_schema_extra = {
            "example": {
                "sentence": "I love this product!"
            }
        }


class SentimentOutput(BaseModel):
    """Output schema for sentiment analysis (debug version)"""
    sentence: str
    sentiment: str
    confidence: float
    version: str = "v2-debug"
    debug_info: dict


@app.get("/")
async def root():
    """Root endpoint - API information"""
    return {
        "message": "Sentiment Analysis API v2 (Debug)",
        "version": "2.0.0",
        "mode": "debug",
        "endpoints": {
            "/predict": "POST - Predict sentiment with debug info",
            "/health": "GET - Health check",
            "/metrics": "GET - Prometheus metrics"
        }
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    return {
        "status": "healthy",
        "version": "v2-debug",
        "model_loaded": model is not None,
        "debug_mode": True
    }


@app.post("/predict", response_model=SentimentOutput)
async def predict_sentiment(input_data: SentenceInput, request: Request):
    """
    Predict sentiment of a given sentence with debug information
    
    Args:
        input_data: Input containing the sentence to analyze
        request: FastAPI request object
        
    Returns:
        Sentiment prediction with confidence score and debug info
    """
    start_time = time.time()
    
    try:
        if model is None:
            REQUEST_COUNT.labels(method='POST', endpoint='/predict', status='503').inc()
            raise HTTPException(status_code=503, detail="Model not available")
        
        # Make prediction
        sentence = input_data.sentence
        
        if not sentence or len(sentence.strip()) == 0:
            REQUEST_COUNT.labels(method='POST', endpoint='/predict', status='400').inc()
            raise HTTPException(status_code=400, detail="Sentence cannot be empty")
        
        # Predict sentiment
        try:
            prediction = model.predict([sentence])[0]
            
            # Try to get confidence and all probabilities
            try:
                probabilities = model.predict_proba([sentence])[0]
                confidence = float(max(probabilities))
                all_probabilities = {
                    f"class_{i}": float(prob) 
                    for i, prob in enumerate(probabilities)
                }
            except:
                confidence = 0.95
                all_probabilities = {"default": confidence}
            
            sentiment = str(prediction)
            
        except Exception as e:
            REQUEST_COUNT.labels(method='POST', endpoint='/predict', status='500').inc()
            raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")
        
        # Collect debug information
        duration = time.time() - start_time
        
        debug_info = {
            "timestamp": datetime.utcnow().isoformat(),
            "processing_time_ms": round(duration * 1000, 2),
            "sentence_length": len(sentence),
            "word_count": len(sentence.split()),
            "model_type": type(model).__name__,
            "all_probabilities": all_probabilities,
            "client_ip": request.client.host if request.client else "unknown",
            "headers": {
                "user-agent": request.headers.get("user-agent", "unknown"),
                "x-experiment-group": request.headers.get("x-experiment-group", "none")
            }
        }
        
        # Record metrics
        REQUEST_DURATION.labels(method='POST', endpoint='/predict').observe(duration)
        REQUEST_COUNT.labels(method='POST', endpoint='/predict', status='200').inc()
        
        return SentimentOutput(
            sentence=sentence,
            sentiment=sentiment,
            confidence=confidence,
            version="v2-debug",
            debug_info=debug_info
        )
        
    except HTTPException:
        raise
    except Exception as e:
        REQUEST_COUNT.labels(method='POST', endpoint='/predict', status='500').inc()
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

