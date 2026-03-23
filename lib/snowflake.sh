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

upload() {
    load_env
    check_snowsql

    local parquet_file="${1:-./parquet/messages.parquet}"

    if [ ! -f "$parquet_file" ]; then
        echo "Error: Parquet file not found: $parquet_file"
        exit 1
    fi

    local host="${SNOWSQL_HOST}"
    local user="${SNOWSQL_USER}"
    local private_key="${SNOWSQL_PRIVATE_KEY_PATH}"
    local database="${SNOWSQL_DATABASE}"
    local schema="${SNOWSQL_SCHEMA}"
    local stage="${SNOWSQL_STAGE}"

    if [ -z "$host" ] || [ -z "$user" ] || [ -z "$private_key" ]; then
        echo "Error: Snowflake credentials not configured in .env"
        exit 1
    fi

    echo "Uploading $parquet_file to Snowflake stage..."

    snowsql -q "PUT file://$(pwd)/$parquet_file @${database}.${schema}.${stage}/ auto_compress=false overwrite=true;" \
        --host="$host" \
        --username="$user" \
        --private-key-path="$private_key"

    echo "Upload complete."
}

load() {
    load_env
    check_snowsql

    local parquet_file="${1:-./parquet/messages.parquet}"
    local filename=$(basename "$parquet_file")

    local host="${SNOWSQL_HOST}"
    local user="${SNOWSQL_USER}"
    local private_key="${SNOWSQL_PRIVATE_KEY_PATH}"
    local database="${SNOWSQL_DATABASE}"
    local schema="${SNOWSQL_SCHEMA}"
    local stage="${SNOWSQL_STAGE}"

    if [ -z "$host" ] || [ -z "$user" ] || [ -z "$private_key" ]; then
        echo "Error: Snowflake credentials not configured in .env"
        exit 1
    fi

    echo "Loading data into Snowflake..."

    snowsql -q "
        TRUNCATE TABLE ${database}.${schema}.MESSAGES;
        COPY INTO ${database}.${schema}.MESSAGES
        FROM @${database}.${schema}.${stage}/${filename}
        FILE_FORMAT = (TYPE = PARQUET)
        MATCH_BY_COLUMN_NAME = CASE_SENSITIVE;
    " --host="$host" --username="$user" --private-key-path="$private_key"

    echo "Load complete."
}
