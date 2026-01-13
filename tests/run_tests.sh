#!/bin/bash

# Sentiment Analysis API - Comprehensive Test Suite
# Tests all required features: HTTPS, Load Balancing, Auth, Rate Limiting, A/B Testing, Monitoring

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Configuration
API_URL="https://localhost"
HTTP_URL="http://localhost"
PROMETHEUS_URL="http://localhost:9090"
USERNAME="admin"
PASSWORD="password123"

# Helper functions
print_test() {
    echo -e "${YELLOW}[TEST $1/$TOTAL_TESTS]${NC} $2"
}

print_success() {
    echo -e "${GREEN}✓ PASSED${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_failure() {
    echo -e "${RED}✗ FAILED${NC}: $1"
    echo -e "${RED}  Reason: $2${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_section() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

# Wait for services to be ready
wait_for_services() {
    echo "Waiting for services to be ready..."
    sleep 5
    
    # Check if containers are running
    if ! docker ps | grep -q "nginx"; then
        echo -e "${RED}ERROR: Nginx container is not running${NC}"
        exit 1
    fi
    
    echo "✓ Services are ready"
}

# Calculate total tests
TOTAL_TESTS=14

# Start tests
echo "=========================================="
echo "Sentiment Analysis API - Test Suite"
echo "=========================================="
echo "Total tests to run: $TOTAL_TESTS"
echo ""

wait_for_services

# ==========================================
# TEST 1: HTTP to HTTPS Redirect
# ==========================================
print_section "Feature 1: HTTPS Security"
print_test 1 "Testing HTTP to HTTPS redirect..."

response=$(curl -k -s -o /dev/null -w "%{http_code}" -L "$HTTP_URL/")
if [ "$response" = "200" ]; then
    location=$(curl -k -s -o /dev/null -w "%{redirect_url}" "$HTTP_URL/")
    if [[ "$location" == https* ]]; then
        print_success "HTTP redirects to HTTPS"
    else
        print_failure "HTTP to HTTPS redirect" "No HTTPS redirect detected"
    fi
else
    print_failure "HTTP to HTTPS redirect" "HTTP request failed with code $response"
fi

# ==========================================
# TEST 2: HTTPS Connection
# ==========================================
print_test 2 "Testing HTTPS connection..."

response=$(curl -k -s -o /dev/null -w "%{http_code}" "$API_URL/health")
if [ "$response" = "200" ]; then
    print_success "HTTPS connection works"
else
    print_failure "HTTPS connection" "Failed with status code $response"
fi

# ==========================================
# TEST 3: Health Check (No Auth)
# ==========================================
print_test 3 "Testing health check endpoint (no authentication required)..."

response=$(curl -k -s "$API_URL/health")
if echo "$response" | grep -q "healthy"; then
    print_success "Health check endpoint accessible without authentication"
else
    print_failure "Health check" "Response: $response"
fi

# ==========================================
# TEST 4: Authentication Required
# ==========================================
print_section "Feature 2: Access Control (Authentication)"
print_test 4 "Testing authentication requirement on /predict..."

response=$(curl -k -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/predict" \
    -H "Content-Type: application/json" \
    -d '{"sentence": "test"}')

if [ "$response" = "401" ]; then
    print_success "Authentication required for /predict endpoint"
else
    print_failure "Authentication requirement" "Expected 401, got $response"
fi

# ==========================================
# TEST 5: Authentication Works
# ==========================================
print_test 5 "Testing successful authentication..."

response=$(curl -k -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/predict" \
    -u "$USERNAME:$PASSWORD" \
    -H "Content-Type: application/json" \
    -d '{"sentence": "This is a test"}')

if [ "$response" = "200" ]; then
    print_success "Authentication successful with valid credentials"
else
    print_failure "Authentication" "Expected 200, got $response"
fi

# ==========================================
# TEST 6: Prediction Functionality
# ==========================================
print_test 6 "Testing sentiment prediction..."

response=$(curl -k -s -X POST "$API_URL/predict" \
    -u "$USERNAME:$PASSWORD" \
    -H "Content-Type: application/json" \
    -d '{"sentence": "I love this product!"}')

if echo "$response" | grep -q "sentiment"; then
    print_success "Sentiment prediction works"
else
    print_failure "Prediction" "Response: $response"
fi

# ==========================================
# TEST 7: Load Balancing
# ==========================================
print_section "Feature 3: Load Balancing"
print_test 7 "Testing load balancing across 3 API v1 instances..."

# Check if all 3 API v1 containers are running
v1_count=$(docker ps | grep "api-v1" | wc -l)
if [ "$v1_count" -eq 3 ]; then
    print_success "All 3 API v1 instances are running"
else
    print_failure "Load balancing setup" "Expected 3 API v1 instances, found $v1_count"
fi

# ==========================================
# TEST 8: Rate Limiting
# ==========================================
print_section "Feature 4: Rate Limiting"
print_test 8 "Testing rate limiting (10 req/s + burst 20)..."

# Send 30 requests rapidly
rate_limited=0
for i in {1..30}; do
    response=$(curl -k -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/predict" \
        -u "$USERNAME:$PASSWORD" \
        -H "Content-Type: application/json" \
        -d '{"sentence": "test"}')
    
    if [ "$response" = "429" ] || [ "$response" = "503" ]; then
        rate_limited=$((rate_limited + 1))
    fi
done

if [ "$rate_limited" -gt 0 ]; then
    print_success "Rate limiting is active (blocked $rate_limited requests)"
else
    print_failure "Rate limiting" "No requests were rate limited"
fi

# Wait for rate limit to reset
sleep 2

# ==========================================
# TEST 9: A/B Testing - Default (v1)
# ==========================================
print_section "Feature 5: A/B Testing"
print_test 9 "Testing default routing to API v1..."

response=$(curl -k -s -X POST "$API_URL/predict" \
    -u "$USERNAME:$PASSWORD" \
    -H "Content-Type: application/json" \
    -d '{"sentence": "test"}')

if echo "$response" | grep -q '"version":"v1"'; then
    print_success "Default requests route to API v1"
else
    print_failure "A/B Testing (v1 routing)" "Response: $response"
fi

# ==========================================
# TEST 10: A/B Testing - Debug Header (v2)
# ==========================================
print_test 10 "Testing routing to API v2 with X-Experiment-Group: debug..."

response=$(curl -k -s -X POST "$API_URL/predict" \
    -u "$USERNAME:$PASSWORD" \
    -H "Content-Type: application/json" \
    -H "X-Experiment-Group: debug" \
    -d '{"sentence": "test"}')

if echo "$response" | grep -q '"version":"v2-debug"'; then
    print_success "Debug header routes to API v2"
else
    print_failure "A/B Testing (v2 routing)" "Response: $response"
fi

# ==========================================
# TEST 11: Debug Info in v2
# ==========================================
print_test 11 "Testing debug information in API v2 response..."

response=$(curl -k -s -X POST "$API_URL/predict" \
    -u "$USERNAME:$PASSWORD" \
    -H "Content-Type: application/json" \
    -H "X-Experiment-Group: debug" \
    -d '{"sentence": "test"}')

if echo "$response" | grep -q "debug_info"; then
    print_success "API v2 returns debug information"
else
    print_failure "Debug info in v2" "Response: $response"
fi

# ==========================================
# TEST 12: Prometheus Monitoring
# ==========================================
print_section "Feature 6: Monitoring (Bonus)"
print_test 12 "Testing Prometheus availability..."

response=$(curl -s -o /dev/null -w "%{http_code}" "$PROMETHEUS_URL/-/healthy")
if [ "$response" = "200" ]; then
    print_success "Prometheus is running and healthy"
else
    print_failure "Prometheus availability" "Status code: $response"
fi

# ==========================================
# TEST 13: Prometheus Scraping
# ==========================================
print_test 13 "Testing Prometheus metrics collection..."

response=$(curl -s "$PROMETHEUS_URL/api/v1/targets")
if echo "$response" | grep -q "api-v1"; then
    print_success "Prometheus is scraping API metrics"
else
    print_failure "Prometheus scraping" "API targets not found"
fi

# ==========================================
# TEST 14: Nginx Status
# ==========================================
print_test 14 "Testing Nginx status endpoint..."

# This endpoint is only accessible from Docker network
nginx_container=$(docker ps --filter "name=nginx" --format "{{.Names}}")
if [ -n "$nginx_container" ]; then
    response=$(docker exec "$nginx_container" wget -qO- http://localhost/nginx_status 2>/dev/null || echo "")
    if echo "$response" | grep -q "Active connections"; then
        print_success "Nginx status endpoint is working"
    else
        print_failure "Nginx status" "Status endpoint not accessible"
    fi
else
    print_failure "Nginx status" "Nginx container not found"
fi

# ==========================================
# Test Summary
# ==========================================
print_section "Test Summary"
echo "Total Tests:  $TOTAL_TESTS"
echo -e "${GREEN}Passed:${NC}       $TESTS_PASSED"
echo -e "${RED}Failed:${NC}       $TESTS_FAILED"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}=========================================="
    echo "✓ ALL TESTS PASSED!"
    echo "==========================================${NC}"
    exit 0
else
    echo -e "${RED}=========================================="
    echo "✗ SOME TESTS FAILED"
    echo "==========================================${NC}"
    exit 1
fi
