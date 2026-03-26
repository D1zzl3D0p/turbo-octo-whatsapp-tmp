#!/bin/bash
set -e

LOG_PREFIX="whatsapp-backup"

log() {
    local msg="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local logline="[${timestamp}] [info] ${msg}"
    
    echo "$msg" >&2

    if [ -n "$LOG_FILE" ]; then
        echo "$logline" >> "$LOG_FILE"
    fi

    if command -v logger &> /dev/null; then
        logger -t "$LOG_PREFIX" "$msg" 2>/dev/null &
    fi
}

load_env() {
    if [ -f .env ]; then
        set -a
        source .env
        set +a
    elif [ -f .env.example ]; then
        log "Warning: .env file not found. Copy .env.example to .env and configure."
    fi
}

download() {
    load_env

    local token_file="${WHATSAPP_TOKEN_FILE:-./tokens/data_hxp_org_token.txt}"
    local master_token_file="${WHATSAPP_MASTER_TOKEN_FILE:-./tokens/data_hxp_org_mastertoken.txt}"

    if [ ! -f "$token_file" ]; then
        log "Token file not found: $token_file"
        echo "Error: Token file not found: $token_file"
        echo "Run: wabdd token $WHATSAPP_EMAIL"
        exit 1
    fi

    log "Downloading WhatsApp backup..."
    uv tool run wabdd download \
        --token-file "$token_file" \
        --master-token "$master_token_file" \
        --output ./backups/

    log "Download complete"
}
