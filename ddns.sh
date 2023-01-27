#!/usr/bin/env bash
set -euo pipefail
# .env file content
DOMAIN=
SUBDOMAIN=
TTL=
SECRET_KEY=
API_KEY=

ENV_PATH=$(dirname "$0")/.env
export "$(grep -v '^#' "$ENV_PATH" | xargs)"

if [[ -z "$SECRET_KEY" && "$API_KEY" && "$DOMAIN" ]]; then
    echo "Please set the SECRET_KEY, API_KEY and DOMAIN variables in the .env file"
    exit 1
fi

check_response() {
    local status
    status=$(jq -r '.status' <<<"$1")
    if [[ $status != "SUCCESS" ]]; then
        echo "Error: $(jq -r '.error' <<<"$1")"
        exit 1
    fi
}

RESPONSE=$(curl -sL --request POST "https://api-ipv4.porkbun.com/api/json/v3/ping" \
    --header 'Content-Type: application/json' \
    --data-raw '{
    "secretapikey": "'"$SECRET_KEY"'",
    "apikey": "'"$API_KEY"'"
}')
check_response "$RESPONSE"
MYIP=$(jq -r '.yourIp' <<<"$RESPONSE")

RESPONSE=$(curl -sL --request POST "https://porkbun.com/api/json/v3/dns/retrieve/$DOMAIN" \
    --header 'Content-Type: application/json' \
    --data-raw '{
    "secretapikey": "'"$SECRET_KEY"'",
    "apikey": "'"$API_KEY"'"
}')
check_response "$RESPONSE"

if [ -n "$SUBDOMAIN" ]; then
    RECORD=$(jq -r '.records[] | select(.name == "'"$SUBDOMAIN.$DOMAIN"'")' <<<"$RESPONSE")
    if [ -z "$RECORD" ]; then
        echo "'$SUBDOMAIN.$DOMAIN' not found"
        exit 1
    fi
    NAME=$SUBDOMAIN
else
    RECORD=$(jq -r '.records[] | select(.name == "'"$DOMAIN"'" and .type == "A")' <<<"$RESPONSE")
    NAME=
fi

ID=$(jq -r '.id' <<<"$RECORD")
TYPE=$(jq -r '.type' <<<"$RECORD")
CONTENT=$(jq -r '.content' <<<"$RECORD")

if [ "$MYIP" != "$CONTENT" ]; then
    RESPONSE=$(curl -sL --request POST "https://porkbun.com/api/json/v3/dns/edit/$DOMAIN/$ID" \
        --header 'Content-Type: application/json' \
        --data-raw '{
                "secretapikey": "'"$SECRET_KEY"'",
                "apikey": "'"$API_KEY"'",
                "name": "'"$NAME"'",
                "type": "'"$TYPE"'",
                "content": "'"$MYIP"'",
                "ttl": "'"$TTL"'"
            }')
    check_response "$RESPONSE"
    echo "DNS record updated to $MYIP"
else
    echo "DNS record is already up-to-date"
fi
