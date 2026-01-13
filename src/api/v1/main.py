"""
Sentiment Analysis API - Version 1
Standard version of the sentiment analysis API
"""

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib
import os
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response
import time

# Initialize FastAPI app
app = FastAPI(
    title="Sentiment Analysis API v1",
    description="Standard sentiment analysis API",
    version="1.0.0"
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
    """Output schema for sentiment analysis"""
    sentence: str
    sentiment: str
    confidence: float
    version: str = "v1"


@app.get("/")
async def root():
    """Root endpoint - API information"""
    return {
        "message": "Sentiment Analysis API v1",
        "version": "1.0.0",
        "endpoints": {
            "/predict": "POST - Predict sentiment of a sentence",
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
        "version": "v1",
        "model_loaded": model is not None
    }


@app.post("/predict", response_model=SentimentOutput)
async def predict_sentiment(input_data: SentenceInput):
    """
    Predict sentiment of a given sentence
    
    Args:
        input_data: Input containing the sentence to analyze
        
    Returns:
        Sentiment prediction with confidence score
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
        
        # Predict sentiment (assuming model has predict_proba method)
        try:
            prediction = model.predict([sentence])[0]
            
            # Try to get confidence if model supports predict_proba
            try:
                probabilities = model.predict_proba([sentence])[0]
                confidence = float(max(probabilities))
            except:
                confidence = 0.95  # Default confidence if predict_proba not available
            
            sentiment = str(prediction)
            
        except Exception as e:
            REQUEST_COUNT.labels(method='POST', endpoint='/predict', status='500').inc()
            raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")
        
        # Record metrics
        duration = time.time() - start_time
        REQUEST_DURATION.labels(method='POST', endpoint='/predict').observe(duration)
        REQUEST_COUNT.labels(method='POST', endpoint='/predict', status='200').inc()
        
        return SentimentOutput(
            sentence=sentence,
            sentiment=sentiment,
            confidence=confidence,
            version="v1"
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

