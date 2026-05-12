from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class EventStore:
    def __init__(self, db_path: str) -> None:
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _conn(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self) -> None:
        with self._conn() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    event_type TEXT NOT NULL,
                    severity TEXT NOT NULL,
                    message TEXT NOT NULL,
                    payload_json TEXT,
                    created_at TEXT NOT NULL
                )
                """
            )
            conn.commit()

    def add_event(
        self,
        *,
        event_type: str,
        severity: str,
        message: str,
        payload: dict[str, Any] | None = None,
    ) -> None:
        created_at = datetime.now(timezone.utc).isoformat()
        payload_json = json.dumps(payload or {}, ensure_ascii=True)
        with self._conn() as conn:
            conn.execute(
                """
                INSERT INTO events (event_type, severity, message, payload_json, created_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                (event_type, severity, message, payload_json, created_at),
            )
            conn.commit()

    def list_events(self, limit: int = 50) -> list[dict[str, Any]]:
        with self._conn() as conn:
            rows = conn.execute(
                """
                SELECT id, event_type, severity, message, payload_json, created_at
                FROM events
                ORDER BY id DESC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
        return [
            {
                "id": row["id"],
                "event_type": row["event_type"],
                "severity": row["severity"],
                "message": row["message"],
                "payload": json.loads(row["payload_json"] or "{}"),
                "created_at": row["created_at"],
            }
            for row in rows
        ]

