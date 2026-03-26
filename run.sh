#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_PREFIX="whatsapp-backup"
LOG_FILE="${SCRIPT_DIR}/logs/${LOG_PREFIX}.log"

mkdir -p "${SCRIPT_DIR}/logs"

LOCK_FILE="${SCRIPT_DIR}/.run.lock"

acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            log "Lock exists (PID $pid), exiting" "error"
            echo "Error: Script already running (PID $pid), exiting" >&2
            exit 1
        fi
        log "Stale lock found, removing" "warn"
        rm -f "$LOCK_FILE"
    fi
    trap 'rm -f "$LOCK_FILE"' EXIT
    echo $$ > "$LOCK_FILE"
    log "Started" "info"
}

log() {
    local level="${2:-info}"
    local msg="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local logline="[${timestamp}] [${level}] ${msg}"
    
    echo "$msg"
    echo "$logline" >> "$LOG_FILE"
    
    if command -v logger &> /dev/null; then
        logger -t "$LOG_PREFIX" "$msg" 2>/dev/null &
    fi
}

acquire_lock

set -e

source vars.sh
source "${SCRIPT_DIR}/lib/download.sh"
source "${SCRIPT_DIR}/lib/decrypt.sh"
source "${SCRIPT_DIR}/lib/snowflake.sh"

VENV_DIR="${SCRIPT_DIR}/.venv"
PYTHON="${VENV_DIR}/bin/python"

setup_venv() {
  if [ ! -f "${VENV_DIR}/bin/activate" ]; then
    log "Creating virtual environment at ${VENV_DIR} ..."
    python3 -m venv "$VENV_DIR"
  fi
  local req_file="${SCRIPT_DIR}/requirements.txt"
  local stamp_file="${VENV_DIR}/.installed"
  if [ ! -f "$stamp_file" ] || [ "$req_file" -nt "$stamp_file" ]; then
    log "Installing Python dependencies ..."
    "${VENV_DIR}/bin/pip" install --quiet -r "$req_file"
    touch "$stamp_file"
  fi
}

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
    SNOWSQL_ACCOUNT            - Snowflake account identifier (e.g. xy12345 or xy12345.us-east-1)
    SNOWSQL_USER               - Snowflake username
    SNOWSQL_PRIVATE_KEY_PATH  - Path to private key (.p8)
    SNOWSQL_PRIVATE_KEY_PASSPHRASE - Passphrase for encrypted key (leave empty if unencrypted)
    SNOWSQL_DATABASE           - Snowflake database
    SNOWSQL_SCHEMA             - Snowflake schema
    SNOWSQL_WAREHOUSE          - Snowflake warehouse (required for COPY INTO)
    SNOWSQL_STAGE              - Snowflake stage name
    SNOWSQL_TABLE              - Target table name (default: MESSAGES)

Cron usage:
    # Weekly backup (Sundays at 3am)
    0 3 * * 0 /path/to/run.sh >> /dev/stdout 2>&1

    # View logs
    journalctl -t whatsapp-backup -f
    journalctl -t whatsapp-backup --since "1 week ago"

Examples:
    $0 all              # Full pipeline
    $0 decrypt          # Decrypt only
    $0 transform        # Transform to parquet only
EOF
}

run_all() {
  log "=== Running full pipeline ==="
  setup_venv

  log "=== Step 1: Download ==="
  download

  log "=== Step 2: Decrypt ==="
  DECRYPTED_DIR=$(decrypt)
  if [ -z "$DECRYPTED_DIR" ] || [ ! -d "$DECRYPTED_DIR" ]; then
    log "Error: decrypt() returned invalid directory: '${DECRYPTED_DIR}'" "error"
    exit 1
  fi
  log "Decrypted directory: $DECRYPTED_DIR"
  local raw_backup_dir="./backups"

  log "=== Step 3: Transform ==="
  local db_path="${DECRYPTED_DIR}/Databases/msgstore.db"
  local date_str=$(date +%Y%m%d_%H%M%S)
  local parquet_file="./parquet/messages_${date_str}.parquet"
  "$PYTHON" "${SCRIPT_DIR}/lib/transform.py" "$db_path" "$parquet_file"

  log "Cleaning up decrypted backup: $DECRYPTED_DIR"
  rm -rf "$DECRYPTED_DIR"

  log "Cleaning up raw encrypted backup: $raw_backup_dir"
  rm -rf "$raw_backup_dir"

  log "=== Step 4: Upload to Snowflake ==="
  upload "$parquet_file"

  log "=== Step 5: Load to Snowflake ==="
  load "$parquet_file"

  log "Cleaning up parquet file: $parquet_file"
  rm -f "$parquet_file"

  log "=== Pipeline complete ==="
}

run_transform() {
  setup_venv
  local decrypted_dir=$(get_latest_decrypted)
  local db_path="${decrypted_dir}/Databases/msgstore.db"
  local date_str=$(date +%Y%m%d_%H%M%S)
  local parquet_file="./parquet/messages_${date_str}.parquet"

  log "Transforming: $db_path"
  log "Output: $parquet_file"
  "$PYTHON" "${SCRIPT_DIR}/lib/transform.py" "$db_path" "$parquet_file"
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
  latest_parquet=$(ls -t ./parquet/messages_*.parquet 2>/dev/null | head -1)
  if [ -z "$latest_parquet" ]; then
    echo "Error: No parquet file found in ./parquet/"
    exit 1
  fi
  upload "$latest_parquet"
  ;;
load)
  latest_parquet=$(ls -t ./parquet/messages_*.parquet 2>/dev/null | head -1)
  if [ -z "$latest_parquet" ]; then
    echo "Error: No parquet file found in ./parquet/"
    exit 1
  fi
  load "$latest_parquet"
  ;;
help | --help | -h)
  usage
  ;;
*)
  echo "Unknown command: $COMMAND"
  usage
  exit 1
  ;;
esac
