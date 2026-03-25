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

check_snowsql() {
    if ! command -v snowsql &> /dev/null; then
        echo "Error: snowsql not installed"
        echo "Download from: https://docs.snowflake.com/en/user-guide/snowsql-install-config"
        exit 1
    fi
}

_snowsql_connect_args() {
    local args=(
        --accountname="$SNOWSQL_ACCOUNT"
        --username="$SNOWSQL_USER"
        --private-key-path="$SNOWSQL_PRIVATE_KEY_PATH"
        --warehouse="$SNOWSQL_WAREHOUSE"
        --dbname="$SNOWSQL_DATABASE"
        --schemaname="$SNOWSQL_SCHEMA"
    )
    echo "${args[@]}"
}

_validate_snowflake_env() {
    local missing=()
    for var in SNOWSQL_ACCOUNT SNOWSQL_USER SNOWSQL_PRIVATE_KEY_PATH SNOWSQL_WAREHOUSE SNOWSQL_DATABASE SNOWSQL_SCHEMA SNOWSQL_STAGE; do
        [ -z "${!var}" ] && missing+=("$var")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Error: Missing Snowflake env vars: ${missing[*]}"
        exit 1
    fi
    if [ ! -f "$SNOWSQL_PRIVATE_KEY_PATH" ]; then
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
        echo "Error: Parquet file not found: $parquet_file"
        exit 1
    fi

    echo "Uploading $parquet_file to @${SNOWSQL_DATABASE}.${SNOWSQL_SCHEMA}.${SNOWSQL_STAGE}/ ..."

    SNOWSQL_PRIVATE_KEY_PASSPHRASE="${SNOWSQL_PRIVATE_KEY_PASSPHRASE:-}" \
    snowsql $(_snowsql_connect_args) -q \
        "PUT 'file://$(pwd)/$parquet_file' @${SNOWSQL_DATABASE}.${SNOWSQL_SCHEMA}.${SNOWSQL_STAGE}/ auto_compress=false overwrite=true;"

    echo "Upload complete."
}

load() {
    load_env
    check_snowsql
    _validate_snowflake_env

    local parquet_file="${1:-./parquet/messages.parquet}"
    local filename=$(basename "$parquet_file")
    local table="${SNOWSQL_TABLE:-MESSAGES}"
    local full_table="${SNOWSQL_DATABASE}.${SNOWSQL_SCHEMA}.${table}"

    echo "Truncating ${full_table} and loading ${filename} ..."

    SNOWSQL_PRIVATE_KEY_PASSPHRASE="${SNOWSQL_PRIVATE_KEY_PASSPHRASE:-}" \
    snowsql $(_snowsql_connect_args) -q "
        TRUNCATE TABLE ${full_table};
        COPY INTO ${full_table}
        FROM @${SNOWSQL_DATABASE}.${SNOWSQL_SCHEMA}.${SNOWSQL_STAGE}/${filename}
        FILE_FORMAT = (TYPE = PARQUET)
        MATCH_BY_COLUMN_NAME = CASE_SENSITIVE;
    "

    echo "Load complete."
}
