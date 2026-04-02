#!/usr/bin/env bash
set -euo pipefail

VMSERVICE_OUT_FILE=""
FLUTTER_LOG=""
TIMEOUT=30

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vmservice-out-file) VMSERVICE_OUT_FILE="$2"; shift 2 ;;
    --flutter-log) FLUTTER_LOG="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

http_to_ws() {
  local url="$1"
  url="${url/#http:\/\//ws://}"
  url="${url%/}"
  if [[ "$url" == */ws ]]; then
    echo "$url"
  else
    echo "${url}/ws"
  fi
}

strategy1() {
  local deadline=$(( $(date +%s) + TIMEOUT ))
  while [[ $(date +%s) -lt $deadline ]]; do
    if [[ -f "$VMSERVICE_OUT_FILE" ]]; then
      local raw
      raw=$(tr -d '[:space:]' < "$VMSERVICE_OUT_FILE")
      if [[ -n "$raw" ]]; then
        http_to_ws "$raw"
        return 0
      fi
    fi
    sleep 1
  done
  return 1
}

strategy2() {
  local deadline=$(( $(date +%s) + TIMEOUT ))
  while [[ $(date +%s) -lt $deadline ]]; do
    if [[ -f "$FLUTTER_LOG" ]]; then
      local match
      match=$(sed -nE 's/.*The Dart VM service is listening on ([^ ]+).*/\1/p' "$FLUTTER_LOG" 2>/dev/null | head -1 || true)
      if [[ -n "$match" ]]; then
        http_to_ws "$match"
        return 0
      fi
    fi
    sleep 1
  done
  return 1
}

strategy3() {
  local ports
  ports=$(lsof -i -sTCP:LISTEN -P 2>/dev/null | grep dart | grep -oE ':[0-9]+' | tr -d ':' | sort -u || true)
  for port in $ports; do
    if curl -s --max-time 1 "http://127.0.0.1:${port}/" 2>/dev/null | grep -q 'dart'; then
      echo "ws://127.0.0.1:${port}/ws"
      return 0
    fi
  done
  return 1
}

if [[ -n "$VMSERVICE_OUT_FILE" ]]; then
  echo "Strategy 1: waiting for $VMSERVICE_OUT_FILE" >&2
  if strategy1; then exit 0; fi
  echo "Strategy 1 failed" >&2
fi

if [[ -n "$FLUTTER_LOG" ]]; then
  echo "Strategy 2: parsing $FLUTTER_LOG" >&2
  if strategy2; then exit 0; fi
  echo "Strategy 2 failed" >&2
fi

echo "Strategy 3: scanning dart processes" >&2
if strategy3; then exit 0; fi
echo "Strategy 3 failed" >&2

exit 1
