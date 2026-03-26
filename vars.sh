#! /bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LOG_FILE="${SCRIPT_DIR}/logs/whatsapp-backup.log"

mkdir -p "${SCRIPT_DIR}/logs"

# WhatsApp Configuration
export WHATSAPP_EMAIL="data@hxp.org"
export WHATSAPP_TOKEN_FILE="${SCRIPT_DIR}/tokens/data_hxp_org_token.txt"
export WHATSAPP_MASTER_TOKEN_FILE="${SCRIPT_DIR}/tokens/data_hxp_org_mastertoken.txt"
export WHATSAPP_KEY_FILE="${SCRIPT_DIR}/keys/whatsapp_decrpt_key.key"

# Snowflake Configuration
export SNOWSQL_ACCOUNT="FJDKZWS-QTB95454"
export SNOWSQL_USER="n8n_user"
export SNOWSQL_PRIVATE_KEY_PATH="${SCRIPT_DIR}/tokens/n8n_snowflake_key.p8"
export SNOWSQL_PRIVATE_KEY_PASSPHRASE=""
export SNOWSQL_DATABASE="n8n_data"
export SNOWSQL_SCHEMA="whatsapp_data"
export SNOWSQL_WAREHOUSE="compute_wh"
export SNOWSQL_STAGE="whatsapp_stage"
export SNOWSQL_TABLE="messages"
