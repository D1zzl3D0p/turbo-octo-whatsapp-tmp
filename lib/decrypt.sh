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

find_latest_backup() {
    local backup_dir=$(ls -d backups/*/ 2>/dev/null | grep -v decrypted | sort -r | head -1 | sed 's/\/$//')
    if [ -z "$backup_dir" ]; then
        echo "Error: No backup found in backups/ directory"
        exit 1
    fi
    echo "$backup_dir"
}

decrypt() {
    load_env

    local key_file="${WHATSAPP_KEY_FILE:-./keys/whatsapp_decrpt_key.key}"

    if [ ! -f "$key_file" ]; then
        echo "Error: Key file not found: $key_file"
        exit 1
    fi

    local backup_dir=$(find_latest_backup)
    local decrypted_dir="${backup_dir}-decrypted"

    if [ -d "$decrypted_dir" ]; then
        echo "Backup already decrypted at: $decrypted_dir"
        echo "$decrypted_dir"
        return 0
    fi

    echo "Decrypting backup: $backup_dir"
    uv tool run wabdd decrypt dump --key-file "$key_file" "$backup_dir"

    echo "Decryption complete: $decrypted_dir"
    echo "$decrypted_dir"
}

get_latest_decrypted() {
    local decrypted_dir=$(ls -d backups/*-decrypted/ 2>/dev/null | sort -r | head -1 | sed 's/\/$//')
    if [ -z "$decrypted_dir" ]; then
        echo "Error: No decrypted backup found"
        exit 1
    fi
    echo "$decrypted_dir"
}
