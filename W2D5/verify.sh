#!/usr/bin/env bash
set -euo pipefail

# Load environment
set -a
source .env
set +a

BASE_URL="http://localhost:${HOST_PORT}"
FAIL=0

check() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" == "$expected" ]; then
    echo "✔ $desc (got $actual)"
  else
    echo "✘ $desc (expected $expected, got $actual)"
    FAIL=1
  fi
}

echo "== 1. Compose up =="
docker compose up -d

echo "== 2. Waiting for healthy status =="
for i in $(seq 1 30); do
  STATUS=$(docker compose ps --format json serving 2>/dev/null | grep -o '"Health":"[a-z]*"' | cut -d'"' -f4 || true)
  if [ "$STATUS" == "healthy" ]; then
    echo "✔ Service is healthy"
    break
  fi
  sleep 5
  if [ "$i" -eq 30 ]; then
    echo "✘ Service never became healthy"
    FAIL=1
  fi
done

echo "== 3. /health without key =="
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health")
check "/health without key" "200" "$CODE"

echo "== 4. /v1/models without key =="
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/v1/models")
check "/v1/models without key" "401" "$CODE"

echo "== 5. /v1/models with key =="
CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $API_KEY" "$BASE_URL/v1/models")
check "/v1/models with key" "200" "$CODE"

echo "== 6. Real authenticated completion =="
RESPONSE=$(curl -s "$BASE_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model":"'"$MODEL_ID"'",
    "messages":[{"role":"user","content":"Say hi."}],
    "max_tokens":16
  }')

if echo "$RESPONSE" | grep -q '"chat.completion"' && echo "$RESPONSE" | grep -q '"content"' && echo "$RESPONSE" | grep -q '"usage"'; then
  echo "✔ Completion response contains expected fields"
else
  echo "✘ Completion response missing expected fields"
  echo "$RESPONSE"
  FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "GREEN CHECK: PASS"
else
  echo "RED CHECK: FAIL"
  exit 1
fi
