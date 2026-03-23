#!/usr/bin/env python3
import sqlite3
import pandas as pd
import sys
import os
from datetime import datetime, timezone
from pathlib import Path

QUERY = """
SELECT
    m._id,
    m.chat_row_id,
    c.subject AS chat_subject,
    m.from_me,
    j.raw_string AS sender_jid,
    m.key_id,
    m.timestamp,
    m.received_timestamp,
    m.message_type,
    m.text_data,
    m.starred,
    m.status,
    m.broadcast,
    CASE m.message_type
        WHEN 0 THEN 'text'
        WHEN 1 THEN 'image'
        WHEN 2 THEN 'audio'
        WHEN 3 THEN 'video'
        WHEN 4 THEN 'contact'
        WHEN 5 THEN 'location'
        WHEN 7 THEN 'document'
        WHEN 9 THEN 'voice_call'
        WHEN 15 THEN 'sticker'
        WHEN 90 THEN 'system'
        WHEN 99 THEN 'group_invite'
        ELSE 'unknown'
    END AS message_type_name
FROM message m
LEFT JOIN chat c ON m.chat_row_id = c._id
LEFT JOIN jid j ON m.sender_jid_row_id = j._id
ORDER BY m._id ASC
"""


def transform(db_path: str, output_path: str) -> None:
    conn = sqlite3.connect(db_path)
    df = pd.read_sql_query(QUERY, conn)
    conn.close()

    df["_loaded_at"] = datetime.now(timezone.utc)

    if df["timestamp"].dtype == "int64":
        df["timestamp_dt"] = pd.to_datetime(df["timestamp"], unit="ms", utc=True)
    if df["received_timestamp"].dtype == "int64":
        df["received_timestamp_dt"] = pd.to_datetime(
            df["received_timestamp"], unit="ms", utc=True
        )

    for col in df.select_dtypes(include=["object"], exclude=["string"]).columns:
        df[col] = df[col].fillna("")

    df = df.astype(
        {
            "_id": "Int64",
            "chat_row_id": "Int64",
            "from_me": "Int64",
            "starred": "Int64",
            "status": "Int64",
            "broadcast": "Int64",
            "message_type": "Int64",
        }
    )

    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_parquet(str(output_path), index=False)

    print(f"Wrote {len(df)} rows to {output_path}")
    print(f"Columns: {', '.join(df.columns.tolist())}")


def main():
    if len(sys.argv) < 3:
        print("Usage: transform.py <db_path> <output_parquet>")
        sys.exit(1)

    db_path = sys.argv[1]
    output_path = sys.argv[2]

    if not os.path.exists(db_path):
        print(f"Error: Database not found: {db_path}")
        sys.exit(1)

    transform(db_path, output_path)


if __name__ == "__main__":
    main()
