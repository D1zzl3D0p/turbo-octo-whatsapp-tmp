#! /bin/bash

# WhatsApp Configuration
export WHATSAPP_EMAIL="data@hxp.org"
export WHATSAPP_TOKEN_FILE="./tokens/data_hxp_org_token.txt"
export WHATSAPP_MASTER_TOKEN_FILE="./tokens/data_hxp_org_mastertoken.txt"
export WHATSAPP_KEY_FILE="./keys/whatsapp_decrpt_key.key"

# Snowflake Configuration
export SNOWSQL_ACCOUNT="FJDKZWS-QTB95454" # Account identifier (e.g. xy12345 or xy12345.us-east-1)
export SNOWSQL_USER="n8n_user"
export SNOWSQL_PRIVATE_KEY_PATH="./tokens/n8n_snowflake_key.p8"
export SNOWSQL_PRIVATE_KEY_PASSPHRASE="" # Leave empty if key is unencrypted
export SNOWSQL_DATABASE="n8n_data"
export SNOWSQL_SCHEMA="whatsapp_data"
export SNOWSQL_WAREHOUSE="compute_wh"
export SNOWSQL_STAGE="whatsapp_stage"
export SNOWSQL_TABLE="messages"
