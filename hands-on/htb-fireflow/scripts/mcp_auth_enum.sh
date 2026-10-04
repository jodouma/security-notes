#!/usr/bin/env bash
# Authenticate to the authorized Fireflow MCP registry, decode its JWT, and list tools.
set -euo pipefail

MCP_SERVER="${MCP_SERVER:-http://10.129.156.74:30080}"
MCP_USERNAME="${MCP_USERNAME:-langflow-bot}"
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/loot/mcp}"

for dependency in curl jq python3; do
  command -v "$dependency" >/dev/null || {
    echo "Missing dependency: $dependency" >&2
    exit 1
  }
done

read -r -s -p "MCP password for ${MCP_USERNAME}: " MCP_PASSWORD
printf '\n'
mkdir -p "$OUTPUT_DIR"
chmod 700 "$OUTPUT_DIR"

AUTH_FILE="$OUTPUT_DIR/auth-response.json"
HEADER_FILE="$OUTPUT_DIR/jwt-header.json"
PAYLOAD_FILE="$OUTPUT_DIR/jwt-payload.json"
TOOLS_FILE="$OUTPUT_DIR/tools.json"

printf 'Authenticating to %s ...\n' "$MCP_SERVER"
curl --fail-with-body -sS -X POST "$MCP_SERVER/api/v1/auth" \
  -H 'Content-Type: application/json' \
  --data "$(jq -nc --arg username "$MCP_USERNAME" --arg password "$MCP_PASSWORD" '{username:$username,password:$password}')" \
  -o "$AUTH_FILE"
unset MCP_PASSWORD
chmod 600 "$AUTH_FILE"

TOKEN="$(jq -r '.access_token // .token // .jwt // empty' "$AUTH_FILE")"
if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  echo "No access_token, token, or jwt field found. Inspect: $AUTH_FILE" >&2
  exit 1
fi

python3 - "$TOKEN" "$HEADER_FILE" "$PAYLOAD_FILE" <<'PY'
import base64
import json
import sys

token, header_path, payload_path = sys.argv[1:]
parts = token.split('.')
if len(parts) != 3:
    raise SystemExit('Authentication response does not contain a three-part JWT')

for part, path in zip(parts[:2], (header_path, payload_path)):
    part += '=' * (-len(part) % 4)
    value = json.loads(base64.urlsafe_b64decode(part))
    with open(path, 'w', encoding='utf-8') as output:
        json.dump(value, output, indent=2)
        output.write('\n')
PY
chmod 600 "$HEADER_FILE" "$PAYLOAD_FILE"

printf '\nJWT header:\n'
cat "$HEADER_FILE"
printf '\nJWT payload:\n'
cat "$PAYLOAD_FILE"

printf '\nListing registered tools ...\n'
curl --fail-with-body -sS "$MCP_SERVER/api/v1/tools" \
  -H "Authorization: Bearer $TOKEN" \
  -o "$TOOLS_FILE"
chmod 600 "$TOOLS_FILE"
jq . "$TOOLS_FILE"

printf '\nSaved sensitive artifacts under: %s\n' "$OUTPUT_DIR"
printf 'Do not paste the raw JWT or auth-response.json into chat.\n'
