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
        log "Warning: .env file not found"
    fi
}

check_snowsql() {
    if ! command -v snowsql &> /dev/null; then
        log "Error: snowsql not installed"
        echo "Error: snowsql not installed"
        echo "Download from: https://docs.snowflake.com/en/user-guide/snowsql-install-config"
        exit 1
    fi
}

_set_snowsql_args() {
    SNOWSQL_ARGS=(
        --accountname="$SNOWSQL_ACCOUNT"
        --username="$SNOWSQL_USER"
        --private-key-path="$SNOWSQL_PRIVATE_KEY_PATH"
        --warehouse="$SNOWSQL_WAREHOUSE"
        --dbname="$SNOWSQL_DATABASE"
        --schemaname="$SNOWSQL_SCHEMA"
    )
}

_validate_snowflake_env() {
    local missing=()
    for var in SNOWSQL_ACCOUNT SNOWSQL_USER SNOWSQL_PRIVATE_KEY_PATH SNOWSQL_WAREHOUSE SNOWSQL_DATABASE SNOWSQL_SCHEMA SNOWSQL_STAGE; do
        [ -z "${!var}" ] && missing+=("$var")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        log "Error: Missing Snowflake env vars: ${missing[*]}"
        echo "Error: Missing Snowflake env vars: ${missing[*]}"
        exit 1
    fi
    if [ ! -f "$SNOWSQL_PRIVATE_KEY_PATH" ]; then
        log "Error: Private key not found: $SNOWSQL_PRIVATE_KEY_PATH"
        echo "Error: Private key not found: $SNOWSQL_PRIVATE_KEY_PATH"
        exit 1
    fi
}

upload() {
    load_env
    check_snowsql
    _validate_snowflake_env

    local parquet_file="${1:-./parquet/messages.parquet}"

    if [ ! -f "$parquet_file" ]; then
        log "Error: Parquet file not found: $parquet_file"
        echo "Error: Parquet file not found: $parquet_file"
        exit 1
    fi

    log "Uploading $parquet_file to @${SNOWSQL_DATABASE}.${SNOWSQL_SCHEMA}.${SNOWSQL_STAGE}/"

    _set_snowsql_args
    SNOWSQL_PRIVATE_KEY_PASSPHRASE="${SNOWSQL_PRIVATE_KEY_PASSPHRASE:-}" \
    snowsql "${SNOWSQL_ARGS[@]}" -q \
        "PUT 'file://$(pwd)/$parquet_file' @${SNOWSQL_DATABASE}.${SNOWSQL_SCHEMA}.${SNOWSQL_STAGE}/ auto_compress=false overwrite=true;"

    log "Upload complete"
}

load() {
    load_env
    check_snowsql
    _validate_snowflake_env

    local parquet_file="${1:-./parquet/messages.parquet}"
    local filename=$(basename "$parquet_file")
    local table="${SNOWSQL_TABLE:-MESSAGES}"
    local full_table="${SNOWSQL_DATABASE}.${SNOWSQL_SCHEMA}.${table}"

    log "Truncating ${full_table} and loading ${filename}"

    _set_snowsql_args
    SNOWSQL_PRIVATE_KEY_PASSPHRASE="${SNOWSQL_PRIVATE_KEY_PASSPHRASE:-}" \
    snowsql "${SNOWSQL_ARGS[@]}" -q "
        TRUNCATE TABLE ${full_table};
        COPY INTO ${full_table}
        FROM @${SNOWSQL_DATABASE}.${SNOWSQL_SCHEMA}.${SNOWSQL_STAGE}/${filename}
        FILE_FORMAT = (TYPE = PARQUET)
        MATCH_BY_COLUMN_NAME = CASE_SENSITIVE;
    "

    log "Load complete"
}
