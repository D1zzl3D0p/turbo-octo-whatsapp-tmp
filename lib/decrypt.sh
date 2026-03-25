#!/bin/bash
set -e

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
        echo "Error: Key file not found: $key_file" >&2
        exit 1
    fi

    if [ ! -f "$sentinel" ]; then
        echo "Error: No encrypted database found at ${sentinel}" >&2
        echo "       Has the download step completed?" >&2
        exit 1
    fi

    if [ -d "$decrypted_dir" ]; then
        echo "Backup already decrypted at: $decrypted_dir" >&2
        echo "$decrypted_dir"
        return 0
    fi

    echo "Decrypting backup: $backup_dir" >&2
    uv tool run wabdd decrypt --key-file "$key_file" dump "$backup_dir" >&2

    # Discover what wabdd created rather than assuming the path.
    # wabdd appends -decrypted to the input path, but exact naming can vary.
    local actual_dir
    actual_dir=$(find . -maxdepth 3 -name "msgstore.db" -path "*-decrypted/*" 2>/dev/null \
        | head -1 | sed 's|/Databases/msgstore.db||')

    if [ -z "$actual_dir" ]; then
        echo "Error: wabdd ran successfully but no decrypted msgstore.db found" >&2
        echo "       Expected a '*-decrypted/Databases/msgstore.db' to be created" >&2
        exit 1
    fi

    echo "Decryption complete: $actual_dir" >&2
    echo "$actual_dir"
}

get_latest_decrypted() {
    local decrypted_dir
    decrypted_dir=$(find . -maxdepth 3 -name "msgstore.db" -path "*-decrypted/*" 2>/dev/null \
        | head -1 | sed 's|/Databases/msgstore.db||')
    if [ -z "$decrypted_dir" ]; then
        echo "Error: No decrypted backup found (no *-decrypted/Databases/msgstore.db)" >&2
        exit 1
    fi
    echo "$decrypted_dir"
}
