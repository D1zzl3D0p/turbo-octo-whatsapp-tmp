#!/bin/bash
set -e

load_env() {
    if [ -f .env ]; then
        set -a
        source .env
        set +a
    elif [ -f .env.example ]; then
        echo "Warning: .env file not found. Copy .env.example to .env and configure."
    fi
}

download() {
    load_env

    local token_file="${WHATSAPP_TOKEN_FILE:-./tokens/data_hxp_org_token.txt}"
    local master_token_file="${WHATSAPP_MASTER_TOKEN_FILE:-./tokens/data_hxp_org_mastertoken.txt}"

    if [ ! -f "$token_file" ]; then
        echo "Error: Token file not found: $token_file"
        echo "Run: wabdd token $WHATSAPP_EMAIL"
        exit 1
    fi

    echo "Downloading WhatsApp backup..."
    uv tool run wabdd download \
        --token-file "$token_file" \
        --master-token "$master_token_file" \
        --output ./backups/

    echo "Download complete."
}
