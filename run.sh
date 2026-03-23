#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/download.sh"
source "${SCRIPT_DIR}/lib/decrypt.sh"
source "${SCRIPT_DIR}/lib/snowflake.sh"

usage() {
    cat <<EOF
Usage: $0 [command]

Commands:
    all         Download, decrypt, transform, upload, and load to Snowflake (default)
    download    Download latest WhatsApp backup from Google Drive
    decrypt     Decrypt the latest backup
    transform   Transform SQLite to Parquet
    upload      Upload Parquet to Snowflake stage
    load        Load Parquet into Snowflake table

Environment variables (set in .env):
    WHATSAPP_EMAIL              - Google account email
    WHATSAPP_TOKEN_FILE        - Path to token file
    WHATSAPP_MASTER_TOKEN_FILE - Path to master token file
    WHATSAPP_KEY_FILE          - Path to decryption key
    SNOWSQL_HOST               - Snowflake account host
    SNOWSQL_USER               - Snowflake username
    SNOWSQL_PRIVATE_KEY_PATH  - Path to private key
    SNOWSQL_DATABASE           - Snowflake database
    SNOWSQL_SCHEMA             - Snowflake schema
    SNOWSQL_STAGE              - Snowflake stage name

Examples:
    $0 all              # Full pipeline
    $0 decrypt          # Decrypt only
    $0 transform        # Transform to parquet only
EOF
}

run_all() {
    echo "=== Running full pipeline ==="

    echo ""
    echo "=== Step 1: Download ==="
    download

    echo ""
    echo "=== Step 2: Decrypt ==="
    DECRYPTED_DIR=$(decrypt)
    echo "Decrypted directory: $DECRYPTED_DIR"

    echo ""
    echo "=== Step 3: Transform ==="
    local db_path="${DECRYPTED_DIR}/Databases/msgstore.db"
    local date_str=$(date +%Y%m%d_%H%M%S)
    local parquet_file="./parquet/messages_${date_str}.parquet"
    python3 "${SCRIPT_DIR}/lib/transform.py" "$db_path" "$parquet_file"

    echo ""
    echo "=== Step 4: Upload to Snowflake ==="
    upload "$parquet_file"

    echo ""
    echo "=== Step 5: Load to Snowflake ==="
    load "$parquet_file"

    echo ""
    echo "=== Pipeline complete ==="
}

run_transform() {
    local decrypted_dir=$(get_latest_decrypted)
    local db_path="${decrypted_dir}/Databases/msgstore.db"
    local date_str=$(date +%Y%m%d_%H%M%S)
    local parquet_file="./parquet/messages_${date_str}.parquet"

    echo "Transforming: $db_path"
    echo "Output: $parquet_file"
    python3 "${SCRIPT_DIR}/lib/transform.py" "$db_path" "$parquet_file"
}

COMMAND="${1:-all}"

case "$COMMAND" in
    all)
        run_all
        ;;
    download)
        download
        ;;
    decrypt)
        decrypt
        ;;
    transform)
        run_transform
        ;;
    upload)
        local latest_parquet=$(ls -t ./parquet/messages_*.parquet 2>/dev/null | head -1)
        if [ -z "$latest_parquet" ]; then
            echo "Error: No parquet file found in ./parquet/"
            exit 1
        fi
        upload "$latest_parquet"
        ;;
    load)
        local latest_parquet=$(ls -t ./parquet/messages_*.parquet 2>/dev/null | head -1)
        if [ -z "$latest_parquet" ]; then
            echo "Error: No parquet file found in ./parquet/"
            exit 1
        fi
        load "$latest_parquet"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac
