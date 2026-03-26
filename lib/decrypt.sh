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
        set -a; source .env; set +a
    fi
}

decrypt() {
    load_env

    local key_file="${WHATSAPP_KEY_FILE:-./keys/whatsapp_decrpt_key.key}"
    local backup_dir="./backups"
    local decrypted_dir="./backups-decrypted"
    local sentinel="${backup_dir}/Databases/msgstore.db.crypt15"

    if [ ! -f "$key_file" ]; then
        log "Error: Key file not found: $key_file"
        echo "Error: Key file not found: $key_file" >&2
        exit 1
    fi

    if [ ! -f "$sentinel" ]; then
        log "Error: No encrypted database found at ${sentinel}"
        echo "Error: No encrypted database found at ${sentinel}" >&2
        echo "       Has the download step completed?" >&2
        exit 1
    fi

    if [ -d "$decrypted_dir" ]; then
        log "Backup already decrypted at: $decrypted_dir"
        echo "Backup already decrypted at: $decrypted_dir" >&2
        echo "$decrypted_dir"
        return 0
    fi

    log "Decrypting backup: $backup_dir"
    uv tool run wabdd decrypt --key-file "$key_file" dump "$backup_dir" >&2

    local actual_dir
    actual_dir=$(find . -maxdepth 3 -name "msgstore.db" -path "*-decrypted/*" 2>/dev/null \
        | head -1 | sed 's|/Databases/msgstore.db||')

    if [ -z "$actual_dir" ]; then
        log "Error: wabdd ran successfully but no decrypted msgstore.db found"
        echo "Error: wabdd ran successfully but no decrypted msgstore.db found" >&2
        echo "       Expected a '*-decrypted/Databases/msgstore.db' to be created" >&2
        exit 1
    fi

    log "Decryption complete: $actual_dir"
    echo "$actual_dir"
}

get_latest_decrypted() {
    local decrypted_dir
    decrypted_dir=$(find . -maxdepth 3 -name "msgstore.db" -path "*-decrypted/*" 2>/dev/null \
        | head -1 | sed 's|/Databases/msgstore.db||')
    if [ -z "$decrypted_dir" ]; then
        log "Error: No decrypted backup found"
        echo "Error: No decrypted backup found (no *-decrypted/Databases/msgstore.db)" >&2
        exit 1
    fi
    echo "$decrypted_dir"
}
