#!/usr/bin/env bash
set -euo pipefail

FLAVOR="ailn"
DEVICE=""
DURATION=60
VM_SERVICE_PORT=8181
DISCOVERY_TIMEOUT=60

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flavor) FLAVOR="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    --duration) DURATION="$2"; shift 2 ;;
    --vm-service-port) VM_SERVICE_PORT="$2"; shift 2 ;;
    --timeout) DISCOVERY_TIMEOUT="$2"; shift 2 ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$DEVICE" ]]; then
  echo "Usage: $0 --device <flutter-device-id> [--flavor ailn] [--duration 60]" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP="$(date -u +%Y%m%d_%H%M%S)"
SAFE_DEVICE="$(printf '%s' "$DEVICE" | tr -c 'A-Za-z0-9._-' '_')"
RUN_LOG="/tmp/flutter_run_launch_${FLAVOR}_${SAFE_DEVICE}_${TIMESTAMP}.log"
JSON_OUT="/tmp/flutter_perf_launch_${FLAVOR}_${SAFE_DEVICE}_${TIMESTAMP}.json"
VMSERVICE_FILE="/tmp/flutter_perf_vmservice_${SAFE_DEVICE}_${TIMESTAMP}.txt"

cleanup() {
  rm -f "$VMSERVICE_FILE"
  if [[ -n "${FLUTTER_PID:-}" ]] && kill -0 "$FLUTTER_PID" 2>/dev/null; then
    kill -INT "$FLUTTER_PID" 2>/dev/null || true
    wait "$FLUTTER_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT

echo "[launch] flavor=$FLAVOR device=$DEVICE duration=${DURATION}s"
echo "[launch] run log: $RUN_LOG"
echo "[launch] json out: $JSON_OUT"

flutter devices --device-timeout 30 >/dev/null 2>&1 || true

flutter run --flavor "$FLAVOR" --profile -d "$DEVICE" \
  --device-timeout 30 \
  --vm-service-port="$VM_SERVICE_PORT" \
  --vmservice-out-file="$VMSERVICE_FILE" >"$RUN_LOG" 2>&1 &
FLUTTER_PID=$!

WS_URL="$("$SCRIPT_DIR/discover_vmservice.sh" --vmservice-out-file "$VMSERVICE_FILE" --timeout "$DISCOVERY_TIMEOUT")"
DISCOVERED_ISO="$(python3 -c 'from datetime import datetime, timezone; print(datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"))')"

echo "[launch] vm service: $WS_URL"

dart run "$SCRIPT_DIR/collect_vm_performance.dart" \
  "$WS_URL" \
  --mode launch \
  --raw-startup \
  --timeline \
  --duration "$DURATION" \
  --vm-service-discovered-iso "$DISCOVERED_ISO" \
  --json >"$JSON_OUT"

echo "[launch] measurement complete"
echo "[launch] run log: $RUN_LOG"
echo "[launch] json out: $JSON_OUT"
