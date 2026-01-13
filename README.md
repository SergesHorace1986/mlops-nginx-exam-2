# Sentiment Analysis API - MLOps Project

Complete containerized architecture for sentiment analysis API with Nginx reverse proxy, load balancing, HTTPS security, authentication, rate limiting, A/B testing, and monitoring.

## 📋 Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Testing](#testing)
- [Monitoring](#monitoring)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)

## ✨ Features

### 1. **Reverse Proxy with Nginx**
- Single point of entry for all API traffic
- Routes requests to appropriate backend services
- HTTP/2 support for improved performance

### 2. **Load Balancing**
- 3 replicas of API v1 for high availability
- Least connections algorithm for optimal distribution
- Automatic failover with health checks

### 3. **HTTPS Security**
- All external communications encrypted via HTTPS
- Self-signed SSL certificates included
- Automatic HTTP to HTTPS redirection
- Modern TLS protocols (TLS 1.2, 1.3)

### 4. **Access Control**
- Basic authentication on `/predict` endpoint
- Username: `admin`
- Password: `password123`
- Health check accessible without authentication

### 5. **Rate Limiting**
- 10 requests per second per IP
- Burst capacity of 20 requests
- Prevents API overload and abuse

### 6. **A/B Testing**
- Two API versions: v1 (standard) and v2 (debug)
- Header-based routing: `X-Experiment-Group: debug`
- Debug version includes additional metrics

### 7. **Monitoring (Bonus)**
- Prometheus for metrics collection
- Grafana for visualization
- API and Nginx metrics exposed

## 🏗️ Architecture

```
                                Internet
                                   │
                                   ▼
                        ┌──────────────────┐
                        │   Nginx (443)    │
                        │  Reverse Proxy   │
                        │  Load Balancer   │
                        └────────┬─────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
         ┌──────────▼─────────┐    ┌─────────▼────────┐
         │  X-Experiment:     │    │    Default       │
         │    debug           │    │                  │
         │                    │    │                  │
    ┌────▼────┐         ┌────▼────┬────▼────┬────▼────┐
    │ API v2  │         │API v1-1 │API v1-2 │API v1-3 │
    │ (Debug) │         │         │         │         │
    └────┬────┘         └────┬────┴────┬────┴────┬────┘
         │                   │         │         │
         │                   │         │         │
         └───────────────────┴─────────┴─────────┘
                             │
                      ┌──────▼──────┐
                      │   ML Model  │
                      └─────────────┘
```

## 📁 Project Structure

```
.
├── Makefile                          # Build and deployment commands
├── README.md                         # This file
├── docker-compose.yml                # Service orchestration
├── deployments/
│   ├── nginx/
│   │   ├── Dockerfile                # Nginx container
│   │   ├── nginx.conf                # Nginx configuration
│   │   ├── .htpasswd                 # Basic auth credentials
│   │   └── certs/
│   │       ├── nginx.crt             # SSL certificate
│   │       └── nginx.key             # SSL private key
│   └── prometheus/
│       └── prometheus.yml            # Prometheus configuration
├── models/
│   └── model.joblib                  # Trained ML model
├── src/
│   └── api/
│       ├── requirements.txt          # Python dependencies
│       ├── v1/
│       │   ├── Dockerfile            # API v1 container
│       │   └── main.py               # API v1 application
│       └── v2/
│           ├── Dockerfile            # API v2 container
│           └── main.py               # API v2 application
└── tests/
    └── run_tests.sh                  # Automated test suite
```

## 🔧 Prerequisites

- Docker (>= 20.10)
- Docker Compose (>= 2.0)
- Make
- curl (for testing)
- bash

## 🚀 Quick Start

### 1. Clone and Setup

```bash
# Navigate to project directory
cd mlops-nginx-exam

# SSL certificates and auth file should already be present
# If not, generate them:
make generate-certs
make generate-auth
```

### 2. Build and Start

```bash
# Build all Docker images
make build

# Start all services
make start-project
```

This will start:
- Nginx (ports 80, 443)
- API v1 (3 instances)
- API v2 (1 instance)
- Prometheus (port 9090)
- Grafana (port 3000)

### 3. Verify Services

```bash
# Check service status
make status

# View logs
make logs
```

### 4. Run Tests

```bash
# Run comprehensive test suite
make test
```

## 📖 Usage

### API Endpoints

#### Root Endpoint
```bash
curl -k https://localhost/
```

#### Health Check (No Authentication)
```bash
curl -k https://localhost/health
```

#### Sentiment Prediction (With Authentication)

**API v1 (Standard):**
```bash
curl -k -u admin:password123 \
  -X POST https://localhost/predict \
  -H "Content-Type: application/json" \
  -d '{"sentence": "I love this product!"}'
```

**API v2 (Debug):**
```bash
curl -k -u admin:password123 \
  -X POST https://localhost/predict \
  -H "Content-Type: application/json" \
  -H "X-Experiment-Group: debug" \
  -d '{"sentence": "I love this product!"}'
```

### Response Examples

**API v1 Response:**
```json
{
  "sentence": "I love this product!",
  "sentiment": "positive",
  "confidence": 0.95,
  "version": "v1"
}
```

**API v2 Response (with debug info):**
```json
{
  "sentence": "I love this product!",
  "sentiment": "positive",
  "confidence": 0.95,
  "version": "v2-debug",
  "debug_info": {
    "timestamp": "2026-01-13T10:30:00",
    "processing_time_ms": 45.23,
    "sentence_length": 21,
    "word_count": 4,
    "model_type": "Pipeline",
    "all_probabilities": {
      "class_0": 0.95,
      "class_1": 0.03,
      "class_2": 0.02
    },
    "client_ip": "172.18.0.2",
    "headers": {
      "user-agent": "curl/7.81.0",
      "x-experiment-group": "debug"
    }
  }
}
```

## 🧪 Testing

### Automated Test Suite

The project includes a comprehensive test suite that validates all features:

```bash
make test
```

**Tests Included:**
1. HTTP to HTTPS redirect
2. HTTPS connection
3. Health check (no auth)
4. Authentication requirement
5. Successful authentication
6. Prediction functionality
7. Load balancing (3 instances)
8. Rate limiting
9. A/B testing (default v1)
10. A/B testing (debug header v2)
11. Debug info in v2
12. Prometheus availability
13. Prometheus scraping
14. Nginx status endpoint

### Manual Testing

#### Test Rate Limiting:
```bash
# Send multiple requests rapidly
for i in {1..30}; do
  curl -k -u admin:password123 \
    -X POST https://localhost/predict \
    -H "Content-Type: application/json" \
    -d '{"sentence": "test"}' &
done
# Some requests should return 429 (Too Many Requests)
```

#### Test Load Balancing:
```bash
# Check logs from different API instances
docker logs api-v1-1
docker logs api-v1-2
docker logs api-v1-3
# Requests should be distributed across instances
```

#### Test A/B Testing:
```bash
# Without header (routes to v1)
curl -k -u admin:password123 \
  -X POST https://localhost/predict \
  -H "Content-Type: application/json" \
  -d '{"sentence": "test"}' | jq '.version'

# With debug header (routes to v2)
curl -k -u admin:password123 \
  -X POST https://localhost/predict \
  -H "Content-Type: application/json" \
  -H "X-Experiment-Group: debug" \
  -d '{"sentence": "test"}' | jq '.version'
```

## 📊 Monitoring

### Prometheus

Access Prometheus at: http://localhost:9090

**Available Metrics:**
- `api_requests_total`: Total API requests by method, endpoint, and status
- `api_request_duration_seconds`: Request duration histogram

**Example Queries:**
```promql
# Request rate per endpoint
rate(api_requests_total[5m])

# Average response time
rate(api_request_duration_seconds_sum[5m]) / rate(api_request_duration_seconds_count[5m])

# Success rate
sum(rate(api_requests_total{status="200"}[5m])) / sum(rate(api_requests_total[5m]))
```

### Grafana

Access Grafana at: http://localhost:3000
- Username: `admin`
- Password: `admin123`

**Setup Prometheus Data Source:**
1. Go to Configuration → Data Sources
2. Add Prometheus
3. URL: `http://prometheus:9090`
4. Save & Test

### Nginx Metrics

Nginx stub_status is available at `/nginx_status` (accessible only from Docker network).

## ⚙️ Configuration

### Change Authentication Credentials

Edit `deployments/nginx/.htpasswd`:
```bash
make generate-auth
# Or manually:
htpasswd -c deployments/nginx/.htpasswd <username>
```

### Adjust Rate Limiting

Edit `deployments/nginx/nginx.conf`:
```nginx
# Change from 10r/s to 20r/s
limit_req_zone $binary_remote_addr zone=predict_limit:10m rate=20r/s;

# Change burst from 20 to 50
limit_req zone=predict_limit burst=50 nodelay;
```

### Scale API Instances

Edit `docker-compose.yml` to add more replicas:
```yaml
api-v1-4:
  build:
    context: ./src/api
    dockerfile: v1/Dockerfile
  # ... same config as other instances
```

Then update `deployments/nginx/nginx.conf`:
```nginx
upstream api_v1_backend {
    least_conn;
    server api-v1-1:8000;
    server api-v1-2:8000;
    server api-v1-3:8000;
    server api-v1-4:8000;  # Add new instance
}
```

### SSL Certificates

To use your own certificates:
```bash
# Replace self-signed certificates
cp your-cert.crt deployments/nginx/certs/nginx.crt
cp your-key.key deployments/nginx/certs/nginx.key

# Rebuild nginx
docker-compose up -d --build nginx
```

## 🐛 Troubleshooting

### Services Won't Start

```bash
# Check Docker status
docker ps -a

# View logs
docker-compose logs

# Rebuild from scratch
make clean
make build
make start-project
```

### SSL Certificate Errors

```bash
# Regenerate certificates
make generate-certs

# Rebuild nginx
docker-compose up -d --build nginx
```

### Authentication Not Working

```bash
# Regenerate .htpasswd
make generate-auth

# Verify credentials
cat deployments/nginx/.htpasswd

# Rebuild nginx
docker-compose up -d --build nginx
```

### Rate Limiting Too Strict

Edit `deployments/nginx/nginx.conf` and increase rate/burst:
```nginx
limit_req_zone $binary_remote_addr zone=predict_limit:10m rate=20r/s;
limit_req zone=predict_limit burst=50 nodelay;
```

Then reload Nginx:
```bash
docker exec nginx nginx -s reload
```

### Model Not Loading

```bash
# Check if model file exists
ls -lh models/model.joblib

# Check API logs
docker logs api-v1-1

# Verify volume mount
docker inspect api-v1-1 | grep -A 5 Mounts
```

### Port Already in Use

```bash
# Check what's using the ports
sudo lsof -i :80
sudo lsof -i :443
sudo lsof -i :9090
sudo lsof -i :3000

# Stop conflicting services or change ports in docker-compose.yml
```

## 🔄 Makefile Commands

```bash
make help           # Show all available commands
make build          # Build all Docker images
make start-project  # Start all services
make stop-project   # Stop all services
make restart        # Restart all services
make clean          # Remove all containers and volumes
make logs           # Show logs from all services
make test           # Run all tests
make status         # Show status of all services
make generate-certs # Generate SSL certificates
make generate-auth  # Generate .htpasswd file
```

## 📝 API Documentation

Once services are running, API documentation is available at:
- API v1: https://localhost/docs (requires auth)
- API v2: Access via debug header

## 🔐 Security Notes

1. **SSL Certificates**: Self-signed certificates are for testing only. Use proper CA-signed certificates in production.

2. **Authentication**: Change default credentials (`admin:password123`) before deployment.

3. **Rate Limiting**: Adjust limits based on your use case and expected traffic.

4. **Network**: Services communicate on an isolated Docker network for security.

5. **Secrets Management**: In production, use Docker secrets or environment variables for sensitive data.

## 📄 License

This project is for educational purposes as part of an MLOps exam.

## 👥 Authors

DataScientest MLOps Student

## 🙏 Acknowledgments

- FastAPI for the API framework
- Nginx for reverse proxy and load balancing
- Prometheus and Grafana for monitoring
- Docker for containerization

