#!/usr/bin/env bash
# Green-check verifier for W2D3 Extra Lab (Multi-Stage Build Golf)

set -u

TARGET_MB=300
MIN_SAVINGS_PCT=20
NAME="registry-verify"
PORT="${PORT:-8000}"

fail() {
  echo "GREEN CHECK: FAIL ($1)"
  cleanup
  exit 1
}

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
}

cleanup

if ! docker image inspect registry:naive >/dev/null 2>&1; then
  echo "building naive image..."
  docker build -f Dockerfile.naive -t registry:naive . >/dev/null 2>&1 || fail "naive image build failed"
fi

if ! docker image inspect registry:multistage >/dev/null 2>&1; then
  echo "building multi-stage image..."
  docker build -t registry:multistage . >/dev/null 2>&1 || fail "multi-stage image build failed"
fi

naive_size=$(docker images registry:naive --format "{{.Size}}")
multi_size=$(docker images registry:multistage --format "{{.Size}}")

result=$(python3 size_check.py "$naive_size" "$multi_size" "$TARGET_MB" "$MIN_SAVINGS_PCT")

multi_mb=$(echo "$result" | cut -d'|' -f1)
savings_pct=$(echo "$result" | cut -d'|' -f2)
fits_target=$(echo "$result" | cut -d'|' -f3)
enough_savings=$(echo "$result" | cut -d'|' -f4)

echo "naive size:  $naive_size"
echo "multi size:  $multi_size"
echo "savings:     ${savings_pct}%"

[ "$fits_target" = "1" ] || fail "multi-stage image (${multi_mb}MB) exceeds target (${TARGET_MB}MB)"
[ "$enough_savings" = "1" ] || fail "savings (${savings_pct}%) below minimum (${MIN_SAVINGS_PCT}%)"

if ! docker run -d --name "$NAME" -p "${PORT}:8000" registry:multistage >/dev/null 2>&1; then
  fail "container failed to start"
fi

echo "waiting for /health..."
deadline=$(( $(date +%s) + 30 ))
healthy=0
while [ "$(date +%s)" -lt "$deadline" ]; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/health" 2>/dev/null || echo 000)
  if [ "$code" = "200" ]; then healthy=1; break; fi
  if [ -z "$(docker ps -q -f name=$NAME)" ]; then
    docker logs --tail 20 "$NAME" 2>&1
    fail "container exited before /health came up"
  fi
  sleep 1
done
[ "$healthy" -eq 1 ] || fail "/health did not return 200 in time"

reg_resp=$(curl -s "http://localhost:${PORT}/registry")
echo "$reg_resp" | grep -q "Qwen2.5-0.5B-Instruct" || fail "/registry did not list expected model"

lookup_resp=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/registry/Qwen2.5-0.5B-Instruct")
[ "$lookup_resp" = "200" ] || fail "model lookup did not return 200"

notfound_resp=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/registry/does-not-exist")
[ "$notfound_resp" = "404" ] || fail "unknown model did not return 404"

cleanup
echo "GREEN CHECK: PASS"
exit 0