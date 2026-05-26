#!/usr/bin/env python3
"""Prepare and profile Editor performance datasets.

This script intentionally treats the user's live Editor store as read-only.
It copies the store into an isolated app-support root whose layout matches
EDITOR_APP_SUPPORT_DIR, then optionally scales relational rows by cloning the
real dataset while preserving foreign-key shape.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import sys
import tempfile
import time
from typing import Any, Iterable


KNOWN_TABLES = [
    "workspaces",
    "notebooks",
    "pages",
    "blocks",
    "tags",
    "page_tags",
    "attachments",
    "attachment_text_recognition",
    "diary_entries",
    "diary_pages",
    "page_parent_links",
    "page_origin",
    "page_import_metadata",
    "links",
    "conflict_versions",
    "page_versions",
    "search_index",
    "sync_changes",
    "sync_records",
    "sync_server_change_tokens",
    "runtime_diagnostics",
]

RELATIONAL_TABLES = [
    "notebooks",
    "tags",
    "diary_entries",
    "pages",
    "attachments",
    "blocks",
    "attachment_text_recognition",
    "diary_pages",
    "page_tags",
    "page_parent_links",
    "page_origin",
    "page_import_metadata",
    "links",
    "conflict_versions",
    "page_versions",
    "sync_records",
    "sync_changes",
]


def eprint(message: str) -> None:
    print(message, file=sys.stderr)


def connect(path: Path, readonly: bool = False) -> sqlite3.Connection:
    if readonly:
        uri = f"file:{path}?mode=ro"
        conn = sqlite3.connect(uri, uri=True)
    else:
        conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn


def query_scalar(conn: sqlite3.Connection, sql: str, args: Iterable[Any] = ()) -> Any:
    row = conn.execute(sql, tuple(args)).fetchone()
    return None if row is None else row[0]


def table_exists(conn: sqlite3.Connection, table: str) -> bool:
    return bool(
        query_scalar(
            conn,
            "SELECT 1 FROM sqlite_master WHERE type IN ('table', 'view') AND name = ?",
            [table],
        )
    )


def table_columns(conn: sqlite3.Connection, table: str) -> list[str]:
    return [row["name"] for row in conn.execute(f"PRAGMA table_info({quote_ident(table)})")]


def quote_ident(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def app_support_candidates() -> list[Path]:
    home = Path.home()
    env_root = os.environ.get("EDITOR_APP_SUPPORT_DIR")
    candidates: list[Path] = []
    if env_root:
        candidates.append(Path(env_root) / "Editor" / "editor.sqlite")
    candidates.extend(
        [
            home
            / "Library/Containers/com.liangzhang.editor.mac/Data/Library/Application Support/Editor/editor.sqlite",
            home / "Library/Application Support/Editor/editor.sqlite",
        ]
    )
    return candidates


def is_valid_editor_db(path: Path) -> tuple[bool, int, int]:
    if not path.exists() or path.stat().st_size == 0:
        return (False, 0, 0)
    try:
        with connect(path, readonly=True) as conn:
            if not table_exists(conn, "pages") or not table_exists(conn, "blocks"):
                return (False, 0, 0)
            pages = int(query_scalar(conn, "SELECT COUNT(*) FROM pages") or 0)
            blocks = int(query_scalar(conn, "SELECT COUNT(*) FROM blocks") or 0)
            return (pages > 0 and blocks > 0, pages, blocks)
    except sqlite3.Error:
        return (False, 0, 0)


def locate_db() -> Path:
    scored: list[tuple[int, int, Path]] = []
    for path in app_support_candidates():
        valid, pages, blocks = is_valid_editor_db(path)
        if valid:
            scored.append((blocks, pages, path))
    if not scored:
        raise SystemExit("No valid Editor database found in known app-support locations.")
    scored.sort(reverse=True)
    return scored[0][2]


def sha256_prefix(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()[:16]


def percentile(values: list[int], pct: float) -> int:
    if not values:
        return 0
    sorted_values = sorted(values)
    index = min(len(sorted_values) - 1, round((len(sorted_values) - 1) * pct))
    return sorted_values[index]


def percentile_float(values: list[float], pct: float) -> float:
    if not values:
        return 0.0
    sorted_values = sorted(values)
    index = min(len(sorted_values) - 1, round((len(sorted_values) - 1) * pct))
    return sorted_values[index]


def count_table(conn: sqlite3.Connection, table: str) -> int | None:
    if not table_exists(conn, table):
        return None
    try:
        return int(query_scalar(conn, f"SELECT COUNT(*) FROM {quote_ident(table)}") or 0)
    except sqlite3.Error:
        return None


def profile_db(path: Path, label: str) -> dict[str, Any]:
    with connect(path, readonly=True) as conn:
        integrity = query_scalar(conn, "PRAGMA integrity_check")
        counts = {table: count_table(conn, table) for table in KNOWN_TABLES}
        block_counts = [
            int(row[0])
            for row in conn.execute(
                """
                SELECT COUNT(blocks.id)
                FROM pages
                LEFT JOIN blocks ON blocks.page_id = pages.id AND blocks.is_deleted = 0
                GROUP BY pages.id
                """
            )
        ]
        max_page = conn.execute(
            """
            SELECT pages.id,
                   length(pages.title) AS title_length,
                   pages.is_encrypted,
                   COUNT(blocks.id) AS block_count
            FROM pages
            LEFT JOIN blocks ON blocks.page_id = pages.id AND blocks.is_deleted = 0
            GROUP BY pages.id
            ORDER BY block_count DESC
            LIMIT 1
            """
        ).fetchone()
        block_type_counts = {
            row["type"]: row["count"]
            for row in conn.execute(
                """
                SELECT type, COUNT(*) AS count
                FROM blocks
                WHERE is_deleted = 0
                GROUP BY type
                ORDER BY count DESC
                """
            )
        }
        page_flags = conn.execute(
            """
            SELECT
                SUM(is_archived) AS archived,
                SUM(is_favorite) AS favorite,
                SUM(is_pinned) AS pinned,
                SUM(is_encrypted) AS encrypted
            FROM pages
            """
        ).fetchone()
        longest_block = conn.execute(
            """
            SELECT id, page_id, type, length(text_plain) AS text_length
            FROM blocks
            WHERE is_deleted = 0
            ORDER BY text_length DESC
            LIMIT 1
            """
        ).fetchone()
        return {
            "label": label,
            "db_path": str(path),
            "db_size_bytes": path.stat().st_size,
            "db_sha256_prefix": sha256_prefix(path),
            "integrity_check": integrity,
            "counts": counts,
            "blocks_per_page": {
                "p50": percentile(block_counts, 0.50),
                "p95": percentile(block_counts, 0.95),
                "p99": percentile(block_counts, 0.99),
                "max": max(block_counts) if block_counts else 0,
            },
            "max_page": dict(max_page) if max_page else None,
            "longest_block": dict(longest_block) if longest_block else None,
            "page_flags": dict(page_flags) if page_flags else {},
            "block_type_counts": block_type_counts,
        }


def copy_store(source_db: Path, destination_root: Path) -> Path:
    if destination_root.exists():
        shutil.rmtree(destination_root)
    store_dir = destination_root / "Editor"
    store_dir.mkdir(parents=True)
    source_store_dir = source_db.parent

    for child in source_store_dir.iterdir():
        if child.name == "editor.sqlite" or child.name.startswith("editor.sqlite-"):
            continue
        target = store_dir / child.name
        if child.is_dir():
            shutil.copytree(child, target, symlinks=True)
        else:
            shutil.copy2(child, target)

    destination_db = store_dir / "editor.sqlite"
    with connect(source_db, readonly=True) as source_conn:
        with connect(destination_db, readonly=False) as dest_conn:
            source_conn.backup(dest_conn)
    return destination_db


def prefixed(value: Any, clone_index: int) -> Any:
    if value is None:
        return None
    return f"perf{clone_index}-{value}"


def shifted_diary_date(value: Any, clone_index: int) -> Any:
    if value is None:
        return None
    text = str(value)
    try:
        parsed = dt.date.fromisoformat(text)
        return (parsed + dt.timedelta(days=10_000 * clone_index)).isoformat()
    except ValueError:
        return f"{text}-perf{clone_index}"


def rewrite_payload_json(raw: Any, clone_index: int) -> Any:
    if raw is None:
        return raw
    try:
        value = json.loads(raw)
    except (TypeError, json.JSONDecodeError):
        return raw

    reference_keys = {
        "attachment_id",
        "target_page_id",
        "target_block_id",
        "page_id",
        "block_id",
        "parent_page_id",
        "child_page_id",
        "source_block_id",
    }

    def rewrite(node: Any) -> Any:
        if isinstance(node, dict):
            rewritten: dict[str, Any] = {}
            for key, child in node.items():
                if key in reference_keys and isinstance(child, str) and child:
                    rewritten[key] = prefixed(child, clone_index)
                else:
                    rewritten[key] = rewrite(child)
            return rewritten
        if isinstance(node, list):
            return [rewrite(child) for child in node]
        return node

    return json.dumps(rewrite(value), ensure_ascii=False, separators=(",", ":"))


def rewrite_snapshot_json(raw: Any, clone_index: int) -> Any:
    if raw is None:
        return raw
    # Snapshot JSON is not on hot paths for the current database, but keep the
    # obvious IDs internally consistent if page versions exist in future stores.
    return rewrite_payload_json(raw, clone_index)


def clone_row(table: str, row: sqlite3.Row, columns: list[str], clone_index: int) -> list[Any]:
    values = {column: row[column] for column in columns}

    def replace(column: str, value: Any) -> None:
        if column in values:
            values[column] = value

    if table in {"notebooks", "tags", "diary_entries", "pages", "attachments", "blocks",
                 "links", "conflict_versions", "page_versions", "sync_changes"}:
        replace("id", prefixed(values.get("id"), clone_index))

    if table == "notebooks":
        replace("parent_notebook_id", prefixed(values.get("parent_notebook_id"), clone_index))
    elif table == "tags":
        replace("parent_tag_id", prefixed(values.get("parent_tag_id"), clone_index))
    elif table == "pages":
        replace("notebook_id", prefixed(values.get("notebook_id"), clone_index))
        if values.get("title"):
            replace("title", f"{values['title']} [perf {clone_index}]")
    elif table == "blocks":
        replace("page_id", prefixed(values.get("page_id"), clone_index))
        replace("parent_block_id", prefixed(values.get("parent_block_id"), clone_index))
        replace("payload_json", rewrite_payload_json(values.get("payload_json"), clone_index))
    elif table == "attachment_text_recognition":
        replace("attachment_id", prefixed(values.get("attachment_id"), clone_index))
    elif table == "diary_pages":
        replace("page_id", prefixed(values.get("page_id"), clone_index))
        replace("diary_date", shifted_diary_date(values.get("diary_date"), clone_index))
    elif table == "page_tags":
        replace("page_id", prefixed(values.get("page_id"), clone_index))
        replace("tag_id", prefixed(values.get("tag_id"), clone_index))
    elif table == "page_parent_links":
        replace("parent_page_id", prefixed(values.get("parent_page_id"), clone_index))
        replace("child_page_id", prefixed(values.get("child_page_id"), clone_index))
        replace("source_block_id", prefixed(values.get("source_block_id"), clone_index))
    elif table == "page_origin":
        replace("page_id", prefixed(values.get("page_id"), clone_index))
        replace("promoted_from_diary_entry_id", prefixed(values.get("promoted_from_diary_entry_id"), clone_index))
    elif table == "page_import_metadata":
        replace("page_id", prefixed(values.get("page_id"), clone_index))
        if values.get("source_path"):
            replace("source_path", f"{values['source_path']}#perf{clone_index}")
    elif table == "links":
        replace("source_page_id", prefixed(values.get("source_page_id"), clone_index))
        replace("source_block_id", prefixed(values.get("source_block_id"), clone_index))
        replace("target_page_id", prefixed(values.get("target_page_id"), clone_index))
        replace("target_block_id", prefixed(values.get("target_block_id"), clone_index))
    elif table == "conflict_versions":
        replace("block_id", prefixed(values.get("block_id"), clone_index))
    elif table == "page_versions":
        replace("page_id", prefixed(values.get("page_id"), clone_index))
        replace("snapshot_json", rewrite_snapshot_json(values.get("snapshot_json"), clone_index))
    elif table == "sync_records":
        replace("id", prefixed(values.get("id"), clone_index))
        replace("entity_id", prefixed(values.get("entity_id"), clone_index))
        if values.get("record_name"):
            replace("record_name", prefixed(values.get("record_name"), clone_index))
    elif table == "sync_changes":
        replace("entity_id", prefixed(values.get("entity_id"), clone_index))

    return [values[column] for column in columns]


def insert_rows(conn: sqlite3.Connection, table: str, columns: list[str], rows: list[list[Any]]) -> None:
    if not rows:
        return
    placeholders = ", ".join("?" for _ in columns)
    column_sql = ", ".join(quote_ident(column) for column in columns)
    conn.executemany(
        f"INSERT INTO {quote_ident(table)} ({column_sql}) VALUES ({placeholders})",
        rows,
    )


def original_row_where_clause(table: str, columns: list[str]) -> str:
    if "id" in columns:
        return "id NOT LIKE 'perf%-%'"
    if table in {"attachment_text_recognition"}:
        return "attachment_id NOT LIKE 'perf%-%'"
    if table in {"diary_pages", "page_tags", "page_origin", "page_import_metadata"}:
        return "page_id NOT LIKE 'perf%-%'"
    if table == "page_parent_links":
        return "parent_page_id NOT LIKE 'perf%-%'"
    return "1 = 1"


def rebuild_search_index(conn: sqlite3.Connection) -> None:
    if not table_exists(conn, "search_index"):
        return
    conn.execute("DELETE FROM search_index")
    conn.execute(
        """
        INSERT INTO search_index(entity_type, entity_id, title, body)
        SELECT 'page', id, title, title
        FROM pages
        WHERE is_archived = 0 AND is_encrypted = 0 AND title != ''
        """
    )
    conn.execute(
        """
        INSERT INTO search_index(entity_type, entity_id, title, body)
        SELECT 'block', blocks.id, pages.title, blocks.text_plain
        FROM blocks
        INNER JOIN pages ON pages.id = blocks.page_id
        WHERE blocks.is_deleted = 0
          AND blocks.text_plain != ''
          AND pages.is_archived = 0
          AND pages.is_encrypted = 0
        """
    )
    conn.execute(
        """
        INSERT INTO search_index(entity_type, entity_id, title, body)
        SELECT 'attachment', attachments.id, attachments.original_filename, attachments.original_filename
        FROM attachments
        """
    )


def scale_database(path: Path, factor: int) -> None:
    if factor <= 1:
        return
    with connect(path, readonly=False) as conn:
        conn.execute("PRAGMA foreign_keys = OFF")
        conn.execute("BEGIN IMMEDIATE")
        try:
            for clone_index in range(2, factor + 1):
                eprint(f"scaling {path.name}: clone {clone_index}/{factor}")
                for table in RELATIONAL_TABLES:
                    if not table_exists(conn, table):
                        continue
                    columns = table_columns(conn, table)
                    where_clause = original_row_where_clause(table, columns)
                    source_rows = list(
                        conn.execute(
                            f"SELECT * FROM {quote_ident(table)} WHERE {where_clause}"
                        )
                    )
                    cloned = [clone_row(table, row, columns, clone_index) for row in source_rows]
                    insert_rows(conn, table, columns, cloned)
            rebuild_search_index(conn)
            conn.execute("COMMIT")
        except Exception:
            conn.execute("ROLLBACK")
            raise
        finally:
            conn.execute("PRAGMA foreign_keys = ON")
        fk_rows = list(conn.execute("PRAGMA foreign_key_check"))
        if fk_rows:
            first = dict(fk_rows[0])
            raise RuntimeError(f"foreign_key_check failed with {len(fk_rows)} rows; first={first}")
        conn.execute("VACUUM")


def prepare_datasets(source_db: Path, output_root: Path, factors: list[int]) -> dict[str, dict[str, Any]]:
    if not source_db.exists():
        raise SystemExit(f"Source database does not exist: {source_db}")
    if output_root.exists():
        shutil.rmtree(output_root)
    output_root.mkdir(parents=True)

    reports: dict[str, dict[str, Any]] = {}
    for factor in factors:
        label = "Current" if factor == 1 else f"Current_x{factor}"
        dataset_root = output_root / label
        db_path = copy_store(source_db, dataset_root)
        if factor > 1:
            scale_database(db_path, factor)
        reports[label] = profile_db(db_path, label)
        reports[label]["editor_app_support_dir"] = str(dataset_root)
    return reports


def benchmark_summary(values: list[float]) -> dict[str, float]:
    return {
        "count": float(len(values)),
        "min_ms": min(values) if values else 0.0,
        "p50_ms": percentile_float(values, 0.50),
        "p95_ms": percentile_float(values, 0.95),
        "p99_ms": percentile_float(values, 0.99),
        "max_ms": max(values) if values else 0.0,
    }


def time_operation(operation) -> tuple[float, dict[str, Any]]:
    started = time.perf_counter_ns()
    metadata = operation()
    duration_ms = (time.perf_counter_ns() - started) / 1_000_000
    return duration_ms, metadata


def active_pages(conn: sqlite3.Connection, workspace_id: str) -> list[sqlite3.Row]:
    return list(
        conn.execute(
            """
            SELECT pages.id,
                   pages.workspace_id,
                   pages.notebook_id,
                   pages.title,
                   pages.is_favorite,
                   pages.is_pinned,
                   pages.is_encrypted,
                   pages.created_at,
                   pages.updated_at
            FROM pages
            LEFT JOIN notebooks ON notebooks.id = pages.notebook_id
            LEFT JOIN diary_pages ON diary_pages.page_id = pages.id
            WHERE pages.workspace_id = ?
              AND pages.is_archived = 0
            ORDER BY pages.is_pinned DESC, pages.updated_at DESC, pages.created_at DESC
            """,
            [workspace_id],
        )
    )


def active_pages_limited(
    conn: sqlite3.Connection,
    workspace_id: str,
    limit: int | None,
) -> list[sqlite3.Row]:
    if limit is None:
        return active_pages(conn, workspace_id)
    return list(
        conn.execute(
            """
            SELECT pages.id,
                   pages.workspace_id,
                   pages.notebook_id,
                   pages.title,
                   pages.is_favorite,
                   pages.is_pinned,
                   pages.is_encrypted,
                   pages.created_at,
                   pages.updated_at
            FROM pages
            LEFT JOIN notebooks ON notebooks.id = pages.notebook_id
            LEFT JOIN diary_pages ON diary_pages.page_id = pages.id
            WHERE pages.workspace_id = ?
              AND pages.is_archived = 0
            ORDER BY pages.is_pinned DESC, pages.updated_at DESC, pages.created_at DESC
            LIMIT ?
            """,
            [workspace_id, max(0, limit)],
        )
    )


def archived_pages(conn: sqlite3.Connection, workspace_id: str) -> list[sqlite3.Row]:
    return list(
        conn.execute(
            """
            SELECT pages.id,
                   pages.workspace_id,
                   pages.notebook_id,
                   pages.title,
                   pages.is_favorite,
                   pages.is_pinned,
                   pages.is_encrypted,
                   pages.created_at,
                   pages.updated_at
            FROM pages
            LEFT JOIN notebooks ON notebooks.id = pages.notebook_id
            WHERE pages.workspace_id = ?
              AND pages.is_archived = 1
            ORDER BY pages.updated_at DESC
            """,
            [workspace_id],
        )
    )


def archived_pages_limited(
    conn: sqlite3.Connection,
    workspace_id: str,
    limit: int | None,
) -> list[sqlite3.Row]:
    if limit is None:
        return archived_pages(conn, workspace_id)
    return list(
        conn.execute(
            """
            SELECT pages.id,
                   pages.workspace_id,
                   pages.notebook_id,
                   pages.title,
                   pages.is_favorite,
                   pages.is_pinned,
                   pages.is_encrypted,
                   pages.created_at,
                   pages.updated_at
            FROM pages
            LEFT JOIN notebooks ON notebooks.id = pages.notebook_id
            WHERE pages.workspace_id = ?
              AND pages.is_archived = 1
            ORDER BY pages.updated_at DESC
            LIMIT ?
            """,
            [workspace_id, max(0, limit)],
        )
    )


def load_page_list_preview_blocks_current(
    conn: sqlite3.Connection,
    page_ids: list[str],
) -> list[sqlite3.Row]:
    if not page_ids:
        return []

    placeholders = ", ".join("?" for _ in page_ids)
    return list(
        conn.execute(
            f"""
            SELECT blocks.id AS id,
                   blocks.page_id AS page_id,
                   blocks.parent_block_id AS parent_block_id,
                   blocks.order_key AS order_key,
                   blocks.type AS type,
                   blocks.payload_json AS payload_json,
                   blocks.text_plain AS text_plain,
                   pages.is_encrypted AS is_encrypted
            FROM blocks
            INNER JOIN pages ON pages.id = blocks.page_id
            WHERE blocks.page_id IN ({placeholders})
              AND blocks.is_deleted = 0
              AND pages.is_encrypted = 0
              AND (
                  blocks.id = (
                      SELECT candidate.id
                      FROM blocks AS candidate
                      WHERE candidate.page_id = blocks.page_id
                        AND candidate.is_deleted = 0
                        AND candidate.type = 'paragraph'
                        AND length(trim(candidate.text_plain)) > 0
                      ORDER BY candidate.order_key ASC
                      LIMIT 1
                  )
                  OR blocks.id = (
                      SELECT candidate.id
                      FROM blocks AS candidate
                      WHERE candidate.page_id = blocks.page_id
                        AND candidate.is_deleted = 0
                        AND candidate.type = 'attachmentImage'
                      ORDER BY candidate.order_key ASC
                      LIMIT 1
                  )
                  OR blocks.id = (
                      SELECT candidate.id
                      FROM blocks AS candidate
                      WHERE candidate.page_id = blocks.page_id
                        AND candidate.is_deleted = 0
                        AND candidate.type = 'attachmentFile'
                      ORDER BY candidate.order_key ASC
                      LIMIT 1
                  )
              )
            ORDER BY blocks.page_id ASC, blocks.order_key ASC
            """,
            page_ids,
        )
    )


def load_page_list_preview_blocks_window(
    conn: sqlite3.Connection,
    page_ids: list[str],
) -> list[sqlite3.Row]:
    if not page_ids:
        return []

    placeholders = ", ".join("?" for _ in page_ids)
    return list(
        conn.execute(
            f"""
            WITH preview_candidates AS (
                SELECT blocks.id AS id,
                       blocks.page_id AS page_id,
                       blocks.parent_block_id AS parent_block_id,
                       blocks.order_key AS order_key,
                       blocks.type AS type,
                       blocks.payload_json AS payload_json,
                       blocks.text_plain AS text_plain,
                       pages.is_encrypted AS is_encrypted,
                       ROW_NUMBER() OVER (
                           PARTITION BY blocks.page_id, blocks.type
                           ORDER BY blocks.order_key ASC
                       ) AS preview_rank
                FROM blocks
                INNER JOIN pages ON pages.id = blocks.page_id
                WHERE blocks.page_id IN ({placeholders})
                  AND blocks.is_deleted = 0
                  AND pages.is_encrypted = 0
                  AND (
                      (blocks.type = 'paragraph' AND length(trim(blocks.text_plain)) > 0)
                      OR blocks.type IN ('attachmentImage', 'attachmentFile')
                  )
            )
            SELECT id,
                   page_id,
                   parent_block_id,
                   order_key,
                   type,
                   payload_json,
                   text_plain,
                   is_encrypted
            FROM preview_candidates
            WHERE preview_rank = 1
            ORDER BY page_id ASC, order_key ASC
            """,
            page_ids,
        )
    )


def load_largest_page_blocks(conn: sqlite3.Connection) -> tuple[list[sqlite3.Row], str, int]:
    largest = conn.execute(
        """
        SELECT pages.id AS page_id, COUNT(blocks.id) AS block_count
        FROM pages
        LEFT JOIN blocks ON blocks.page_id = pages.id AND blocks.is_deleted = 0
        GROUP BY pages.id
        ORDER BY block_count DESC
        LIMIT 1
        """
    ).fetchone()
    if largest is None:
        return ([], "", 0)
    page_id = largest["page_id"]
    rows = list(
        conn.execute(
            """
            SELECT blocks.id AS id,
                   blocks.page_id AS page_id,
                   blocks.parent_block_id AS parent_block_id,
                   blocks.order_key AS order_key,
                   blocks.type AS type,
                   blocks.payload_json AS payload_json,
                   blocks.text_plain AS text_plain,
                   pages.is_encrypted AS is_encrypted
            FROM blocks
            INNER JOIN pages ON pages.id = blocks.page_id
            WHERE blocks.page_id = ? AND blocks.is_deleted = 0
            ORDER BY blocks.page_id ASC, blocks.order_key ASC
            """,
            [page_id],
        )
    )
    return (rows, page_id, int(largest["block_count"] or 0))


def largest_page_id(conn: sqlite3.Connection) -> tuple[str, int]:
    largest = conn.execute(
        """
        SELECT pages.id AS page_id, COUNT(blocks.id) AS block_count
        FROM pages
        LEFT JOIN blocks ON blocks.page_id = pages.id AND blocks.is_deleted = 0
        GROUP BY pages.id
        ORDER BY block_count DESC
        LIMIT 1
        """
    ).fetchone()
    if largest is None:
        return ("", 0)
    return (largest["page_id"], int(largest["block_count"] or 0))


def load_blocks_for_page(conn: sqlite3.Connection, page_id: str) -> list[sqlite3.Row]:
    if not page_id:
        return []
    return list(
        conn.execute(
            """
            SELECT blocks.id AS id,
                   blocks.page_id AS page_id,
                   blocks.parent_block_id AS parent_block_id,
                   blocks.order_key AS order_key,
                   blocks.type AS type,
                   blocks.payload_json AS payload_json,
                   blocks.text_plain AS text_plain,
                   pages.is_encrypted AS is_encrypted
            FROM blocks
            INNER JOIN pages ON pages.id = blocks.page_id
            WHERE blocks.page_id = ? AND blocks.is_deleted = 0
            ORDER BY blocks.page_id ASC, blocks.order_key ASC
            """,
            [page_id],
        )
    )


def search_benchmark_term(conn: sqlite3.Connection) -> tuple[str, str]:
    if not table_exists(conn, "search_index"):
        return ("", "")
    row = conn.execute(
        """
        SELECT body
        FROM search_index
        WHERE length(body) >= 4
        ORDER BY length(body) DESC
        LIMIT 1
        """
    ).fetchone()
    if row is None or row["body"] is None:
        return ("", "")
    words = re.findall(r"[\w-]{4,}", row["body"], flags=re.UNICODE)
    term = words[0] if words else ""
    return (term, hashlib.sha256(term.encode("utf-8")).hexdigest()[:12] if term else "")


def run_search_query(conn: sqlite3.Connection, term: str) -> list[sqlite3.Row]:
    if not term or not table_exists(conn, "search_index"):
        return []
    return list(
        conn.execute(
            """
            SELECT entity_type, entity_id
            FROM search_index
            WHERE search_index MATCH ?
            LIMIT 50
            """,
            [term],
        )
    )


def run_workspace_overview_current(conn: sqlite3.Connection) -> dict[str, Any]:
    workspace = conn.execute(
        """
        SELECT id, name
        FROM workspaces
        ORDER BY created_at ASC
        LIMIT 1
        """
    ).fetchone()
    workspace_id = workspace["id"] if workspace else ""
    notebooks = list(
        conn.execute(
            """
            SELECT id, workspace_id, parent_notebook_id, name, order_key
            FROM notebooks
            WHERE workspace_id = ?
            ORDER BY order_key ASC
            """,
            [workspace_id],
        )
    )
    pages = active_pages(conn, workspace_id)
    archived = archived_pages(conn, workspace_id)
    attachments = list(
        conn.execute(
            """
            SELECT id,
                   workspace_id,
                   original_filename,
                   uti_type,
                   byte_size,
                   content_hash,
                   local_path,
                   thumbnail_path
            FROM attachments
            WHERE workspace_id = ?
            ORDER BY created_at ASC
            """,
            [workspace_id],
        )
    )
    page_ids = [row["id"] for row in pages] + [row["id"] for row in archived]
    previews = load_page_list_preview_blocks_current(conn, page_ids)
    tags = list(
        conn.execute(
            """
            SELECT id, workspace_id, parent_tag_id, name
            FROM tags
            WHERE workspace_id = ?
            ORDER BY name ASC
            """,
            [workspace_id],
        )
    )
    page_tags = list(conn.execute("SELECT page_id, tag_id FROM page_tags ORDER BY page_id ASC, tag_id ASC"))
    diary_pages = list(
        conn.execute(
            """
            SELECT page_id, workspace_id, diary_date
            FROM diary_pages
            WHERE workspace_id = ?
            ORDER BY diary_date DESC
            """,
            [workspace_id],
        )
    )
    empty_diary_page_ids = list(
        conn.execute(
            """
            SELECT diary_pages.page_id
            FROM diary_pages
            WHERE diary_pages.workspace_id = ?
              AND NOT EXISTS (
                  SELECT 1
                  FROM blocks
                  WHERE blocks.page_id = diary_pages.page_id
                    AND blocks.is_deleted = 0
                    AND (
                        length(trim(blocks.text_plain)) > 0
                        OR blocks.type IN (
                            'table',
                            'divider',
                            'pageReference',
                            'blockReference',
                            'attachmentImage',
                            'attachmentVideo',
                            'attachmentFile',
                            'drawing'
                        )
                    )
              )
            """,
            [workspace_id],
        )
    )
    page_parent_links = list(
        conn.execute(
            """
            SELECT parent_page_id, child_page_id, source_block_id, order_key
            FROM page_parent_links
            ORDER BY parent_page_id ASC, order_key ASC
            """
        )
    )
    return {
        "workspace_id": workspace_id,
        "notebooks": len(notebooks),
        "pages": len(pages),
        "archived_pages": len(archived),
        "attachments": len(attachments),
        "preview_blocks": len(previews),
        "tags": len(tags),
        "page_tags": len(page_tags),
        "diary_pages": len(diary_pages),
        "empty_diary_pages": len(empty_diary_page_ids),
        "page_parent_links": len(page_parent_links),
    }


def run_workspace_overview_window(conn: sqlite3.Connection, page_limit: int | None) -> dict[str, Any]:
    metadata = run_workspace_overview_current_without_previews(conn)
    workspace_id = metadata["workspace_id"]
    pages = active_pages(conn, workspace_id)
    archived = archived_pages(conn, workspace_id)
    page_ids = [row["id"] for row in pages] + [row["id"] for row in archived]
    if page_limit is not None:
        page_ids = page_ids[:page_limit]
    previews = load_page_list_preview_blocks_window(conn, page_ids)
    metadata["preview_blocks"] = len(previews)
    metadata["preview_page_ids"] = len(page_ids)
    return metadata


def run_workspace_overview_fast(conn: sqlite3.Connection, page_limit: int | None) -> dict[str, Any]:
    metadata = run_workspace_overview_fast_without_previews(conn, page_limit)
    workspace_id = metadata["workspace_id"]
    pages = active_pages_limited(conn, workspace_id, page_limit)
    archived = archived_pages_limited(conn, workspace_id, page_limit)
    page_ids = [row["id"] for row in pages] + [row["id"] for row in archived]
    preview_page_ids = page_ids[:200]
    previews = load_page_list_preview_blocks_window(conn, preview_page_ids)
    metadata["preview_blocks"] = len(previews)
    metadata["preview_page_ids"] = len(preview_page_ids)
    return metadata


def run_workspace_overview_parts(conn: sqlite3.Connection, page_limit: int | None) -> dict[str, Any]:
    parts_ms: dict[str, float] = {}
    counts: dict[str, Any] = {}

    def part(name: str, operation):
        duration_ms, value = time_operation(operation)
        parts_ms[name] = duration_ms
        return value

    workspace = part(
        "workspace",
        lambda: conn.execute(
            """
            SELECT id, name
            FROM workspaces
            ORDER BY created_at ASC
            LIMIT 1
            """
        ).fetchone(),
    )
    workspace_id = workspace["id"] if workspace else ""
    notebooks = part(
        "notebooks",
        lambda: list(
            conn.execute(
                """
                SELECT id, workspace_id, parent_notebook_id, name, order_key
                FROM notebooks
                WHERE workspace_id = ?
                ORDER BY order_key ASC
                """,
                [workspace_id],
            )
        ),
    )
    pages = part("pages", lambda: active_pages(conn, workspace_id))
    archived = part("archived_pages", lambda: archived_pages(conn, workspace_id))
    attachments = part(
        "attachments",
        lambda: list(
            conn.execute(
                """
                SELECT id,
                       workspace_id,
                       original_filename,
                       uti_type,
                       byte_size,
                       content_hash,
                       local_path,
                       thumbnail_path
                FROM attachments
                WHERE workspace_id = ?
                ORDER BY created_at ASC
                """,
                [workspace_id],
            )
        ),
    )
    page_ids = [row["id"] for row in pages] + [row["id"] for row in archived]
    if page_limit is not None:
        page_ids = page_ids[:page_limit]
    previews = part("page_list_previews", lambda: load_page_list_preview_blocks_window(conn, page_ids))
    tags = part(
        "tags",
        lambda: list(
            conn.execute(
                """
                SELECT id, workspace_id, parent_tag_id, name
                FROM tags
                WHERE workspace_id = ?
                ORDER BY name ASC
                """,
                [workspace_id],
            )
        ),
    )
    page_tags = part(
        "page_tags",
        lambda: list(conn.execute("SELECT page_id, tag_id FROM page_tags ORDER BY page_id ASC, tag_id ASC")),
    )
    diary_pages = part(
        "diary_pages",
        lambda: list(
            conn.execute(
                """
                SELECT page_id, workspace_id, diary_date
                FROM diary_pages
                WHERE workspace_id = ?
                ORDER BY diary_date DESC
                """,
                [workspace_id],
            )
        ),
    )
    empty_diary_page_ids = part(
        "empty_diary_page_ids",
        lambda: list(
            conn.execute(
                """
                SELECT diary_pages.page_id
                FROM diary_pages
                WHERE diary_pages.workspace_id = ?
                  AND NOT EXISTS (
                      SELECT 1
                      FROM blocks
                      WHERE blocks.page_id = diary_pages.page_id
                        AND blocks.is_deleted = 0
                        AND (
                            length(trim(blocks.text_plain)) > 0
                            OR blocks.type IN (
                                'table',
                                'divider',
                                'pageReference',
                                'blockReference',
                                'attachmentImage',
                                'attachmentVideo',
                                'attachmentFile',
                                'drawing'
                            )
                        )
                  )
                """,
                [workspace_id],
            )
        ),
    )
    page_parent_links = part(
        "page_parent_links",
        lambda: list(
            conn.execute(
                """
                SELECT parent_page_id, child_page_id, source_block_id, order_key
                FROM page_parent_links
                ORDER BY parent_page_id ASC, order_key ASC
                """
            )
        ),
    )

    counts.update(
        {
            "workspace_id": workspace_id,
            "notebooks": len(notebooks),
            "pages": len(pages),
            "archived_pages": len(archived),
            "attachments": len(attachments),
            "preview_blocks": len(previews),
            "preview_page_ids": len(page_ids),
            "tags": len(tags),
            "page_tags": len(page_tags),
            "diary_pages": len(diary_pages),
            "empty_diary_pages": len(empty_diary_page_ids),
            "page_parent_links": len(page_parent_links),
            "parts_ms": parts_ms,
        }
    )
    return counts


def run_workspace_overview_current_without_previews(conn: sqlite3.Connection) -> dict[str, Any]:
    workspace = conn.execute(
        """
        SELECT id, name
        FROM workspaces
        ORDER BY created_at ASC
        LIMIT 1
        """
    ).fetchone()
    workspace_id = workspace["id"] if workspace else ""
    notebooks = list(
        conn.execute(
            """
            SELECT id, workspace_id, parent_notebook_id, name, order_key
            FROM notebooks
            WHERE workspace_id = ?
            ORDER BY order_key ASC
            """,
            [workspace_id],
        )
    )
    pages = active_pages(conn, workspace_id)
    archived = archived_pages(conn, workspace_id)
    attachments = list(
        conn.execute(
            """
            SELECT id,
                   workspace_id,
                   original_filename,
                   uti_type,
                   byte_size,
                   content_hash,
                   local_path,
                   thumbnail_path
            FROM attachments
            WHERE workspace_id = ?
            ORDER BY created_at ASC
            """,
            [workspace_id],
        )
    )
    tags = list(
        conn.execute(
            """
            SELECT id, workspace_id, parent_tag_id, name
            FROM tags
            WHERE workspace_id = ?
            ORDER BY name ASC
            """,
            [workspace_id],
        )
    )
    page_tags = list(conn.execute("SELECT page_id, tag_id FROM page_tags ORDER BY page_id ASC, tag_id ASC"))
    diary_pages = list(
        conn.execute(
            """
            SELECT page_id, workspace_id, diary_date
            FROM diary_pages
            WHERE workspace_id = ?
            ORDER BY diary_date DESC
            """,
            [workspace_id],
        )
    )
    empty_diary_page_ids = list(
        conn.execute(
            """
            SELECT diary_pages.page_id
            FROM diary_pages
            WHERE diary_pages.workspace_id = ?
              AND NOT EXISTS (
                  SELECT 1
                  FROM blocks
                  WHERE blocks.page_id = diary_pages.page_id
                    AND blocks.is_deleted = 0
                    AND (
                        length(trim(blocks.text_plain)) > 0
                        OR blocks.type IN (
                            'table',
                            'divider',
                            'pageReference',
                            'blockReference',
                            'attachmentImage',
                            'attachmentVideo',
                            'attachmentFile',
                            'drawing'
                        )
                    )
              )
            """,
            [workspace_id],
        )
    )
    page_parent_links = list(
        conn.execute(
            """
            SELECT parent_page_id, child_page_id, source_block_id, order_key
            FROM page_parent_links
            ORDER BY parent_page_id ASC, order_key ASC
            """
        )
    )
    return {
        "workspace_id": workspace_id,
        "notebooks": len(notebooks),
        "pages": len(pages),
        "archived_pages": len(archived),
        "attachments": len(attachments),
        "preview_blocks": 0,
        "tags": len(tags),
        "page_tags": len(page_tags),
        "diary_pages": len(diary_pages),
        "empty_diary_pages": len(empty_diary_page_ids),
        "page_parent_links": len(page_parent_links),
    }


def run_workspace_overview_fast_without_previews(
    conn: sqlite3.Connection,
    page_limit: int | None,
) -> dict[str, Any]:
    workspace = conn.execute(
        """
        SELECT id, name
        FROM workspaces
        ORDER BY created_at ASC
        LIMIT 1
        """
    ).fetchone()
    workspace_id = workspace["id"] if workspace else ""
    notebooks = list(
        conn.execute(
            """
            SELECT id, workspace_id, parent_notebook_id, name, order_key
            FROM notebooks
            WHERE workspace_id = ?
            ORDER BY order_key ASC
            """,
            [workspace_id],
        )
    )
    pages = active_pages_limited(conn, workspace_id, page_limit)
    archived = archived_pages_limited(conn, workspace_id, page_limit)
    tags = list(
        conn.execute(
            """
            SELECT id, workspace_id, parent_tag_id, name
            FROM tags
            WHERE workspace_id = ?
            ORDER BY name ASC
            """,
            [workspace_id],
        )
    )
    page_tags = list(conn.execute("SELECT page_id, tag_id FROM page_tags ORDER BY page_id ASC, tag_id ASC"))
    diary_pages = list(
        conn.execute(
            """
            SELECT page_id, workspace_id, diary_date
            FROM diary_pages
            WHERE workspace_id = ?
            ORDER BY diary_date DESC
            """,
            [workspace_id],
        )
    )
    page_parent_links = list(
        conn.execute(
            """
            SELECT parent_page_id, child_page_id, source_block_id, order_key
            FROM page_parent_links
            ORDER BY parent_page_id ASC, order_key ASC
            """
        )
    )
    return {
        "workspace_id": workspace_id,
        "notebooks": len(notebooks),
        "pages": len(pages),
        "archived_pages": len(archived),
        "attachments": 0,
        "preview_blocks": 0,
        "tags": len(tags),
        "page_tags": len(page_tags),
        "diary_pages": len(diary_pages),
        "empty_diary_pages": 0,
        "page_parent_links": len(page_parent_links),
    }


def benchmark_database(
    path: Path,
    label: str,
    iterations: int,
    warmups: int,
    selected_operations: set[str] | None = None,
    page_limit: int | None = None,
) -> dict[str, Any]:
    with connect(path, readonly=True) as conn:
        workspace_id = query_scalar(
            conn,
            "SELECT id FROM workspaces ORDER BY created_at ASC LIMIT 1",
        ) or ""
        pages = active_pages(conn, workspace_id)
        archived = archived_pages(conn, workspace_id)
        page_ids = [row["id"] for row in pages] + [row["id"] for row in archived]
        if page_limit is not None:
            page_ids = page_ids[:page_limit]
        search_term, search_term_hash = search_benchmark_term(conn)
        largest_id, largest_count = largest_page_id(conn)

        operations = {
            "workspace_overview_current": lambda: run_workspace_overview_current(conn),
            "workspace_overview_fast": lambda: run_workspace_overview_fast(conn, page_limit),
            "workspace_overview_window": lambda: run_workspace_overview_window(conn, page_limit),
            "workspace_overview_parts": lambda: run_workspace_overview_parts(conn, page_limit),
            "page_list_preview_blocks_current": lambda: {
                "preview_blocks": len(load_page_list_preview_blocks_current(conn, page_ids)),
                "page_ids": len(page_ids),
            },
            "page_list_preview_blocks_window": lambda: {
                "preview_blocks": len(load_page_list_preview_blocks_window(conn, page_ids)),
                "page_ids": len(page_ids),
            },
            "largest_page_blocks": lambda: (
                lambda loaded: {
                    "blocks": len(loaded[0]),
                    "page_id_hash": hashlib.sha256(loaded[1].encode("utf-8")).hexdigest()[:12],
                    "expected_blocks": loaded[2],
                }
            )(load_largest_page_blocks(conn)),
            "selected_largest_page_blocks": lambda: {
                "blocks": len(load_blocks_for_page(conn, largest_id)),
                "page_id_hash": hashlib.sha256(largest_id.encode("utf-8")).hexdigest()[:12],
                "expected_blocks": largest_count,
            },
            "search_index_query": lambda: {
                "results": len(run_search_query(conn, search_term)),
                "term_hash": search_term_hash,
            },
        }

        results: dict[str, Any] = {
            "label": label,
            "db_path": str(path),
            "iterations": iterations,
            "warmups": warmups,
            "page_ids": len(page_ids),
            "search_term_hash": search_term_hash,
            "operations": {},
        }
        for name, operation in operations.items():
            if selected_operations is not None and name not in selected_operations:
                continue
            eprint(f"benchmark {label}:{name} warmups={warmups} iterations={iterations}")
            for _ in range(warmups):
                operation()
            samples: list[float] = []
            metadata: dict[str, Any] = {}
            for _ in range(iterations):
                duration_ms, metadata = time_operation(operation)
                samples.append(duration_ms)
            summary = benchmark_summary(samples)
            summary["samples_ms"] = samples
            results["operations"][name] = {
                "summary": summary,
                "metadata": metadata,
            }
        return results


def benchmark_from_report(report_path: Path) -> list[tuple[str, Path]]:
    report = json.loads(report_path.read_text(encoding="utf-8"))
    datasets = report.get("datasets", {})
    resolved: list[tuple[str, Path]] = []
    for label, dataset in datasets.items():
        db_path = dataset.get("db_path")
        if db_path:
            resolved.append((label, Path(db_path)))
    return resolved


def write_report(report: dict[str, Any], path: Path | None) -> None:
    text = json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True)
    if path:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text + "\n", encoding="utf-8")
    print(text)


def format_ms(value: Any) -> str:
    try:
        return f"{float(value):.3f}"
    except (TypeError, ValueError):
        return "0.000"


def benchmark_rows(report: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for dataset_label, dataset in report.get("datasets", {}).items():
        for operation_name, operation in dataset.get("operations", {}).items():
            summary = operation.get("summary", {})
            metadata = operation.get("metadata", {})
            rows.append(
                {
                    "dataset": dataset_label,
                    "operation": operation_name,
                    "p50_ms": float(summary.get("p50_ms", 0.0)),
                    "p95_ms": float(summary.get("p95_ms", 0.0)),
                    "p99_ms": float(summary.get("p99_ms", 0.0)),
                    "max_ms": float(summary.get("max_ms", 0.0)),
                    "count": int(float(summary.get("count", 0))),
                    "metadata": metadata,
                }
            )
    return rows


def slow_samples(report: dict[str, Any], report_label: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for dataset_label, dataset in report.get("datasets", {}).items():
        for operation_name, operation in dataset.get("operations", {}).items():
            samples = operation.get("summary", {}).get("samples_ms", [])
            for index, value in enumerate(samples):
                rows.append(
                    {
                        "report": report_label,
                        "dataset": dataset_label,
                        "operation": operation_name,
                        "sample": index + 1,
                        "duration_ms": float(value),
                    }
                )
    rows.sort(key=lambda row: row["duration_ms"], reverse=True)
    return rows


TRACE_LINE_RE = re.compile(
    r"^(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+)(?:[+-]\d{4})?\s+"
    r".*?\]\s+(?P<kind>perf_point|perf_interval)\s+name=(?P<name>\S+)(?:\s+(?P<metadata>.*))?$"
)


TRACE_POINT_PAIRS = [
    ("keydown_to_character_painted", "keydown_start", "character_painted", ["block_id"]),
    ("cursor_to_painted", "cursor_move_start", "cursor_painted", ["block_id", "location", "length"]),
    ("selection_to_painted", "selection_start", "selection_painted", ["block_id", "location", "length"]),
    ("sidebar_click_to_selected_painted", "sidebar_collection_click_start", "sidebar_selected_painted", ["collection"]),
    ("sidebar_click_to_page_list_first_screen", "sidebar_collection_click_start", "page_list_first_screen_painted", ["collection"]),
    ("page_row_click_to_selected_painted", "page_row_click_start", "page_row_selected_painted", ["page_id"]),
    ("page_row_click_to_editor_first_block", "page_row_click_start", "editor_first_block_painted", ["page_id"]),
    ("focus_mode_toggle_to_chrome_painted", "focus_mode_toggle_start", "focus_mode_chrome_painted", ["transition"]),
    ("focus_mode_toggle_to_settled", "focus_mode_toggle_start", "focus_mode_transition_settled", ["transition"]),
    ("task_completion_to_painted", "task_completion_click_start", "task_completion_painted", ["block_id"]),
    ("task_completion_to_persisted", "task_completion_click_start", "task_completion_persisted", ["block_id"]),
    ("mobile_route_push", "mobile_route_push_start", "mobile_route_push_painted", []),
    ("mobile_route_back", "mobile_route_back_start", "mobile_route_back_painted", []),
    ("mobile_scroll_restore", "mobile_scroll_restore_start", "mobile_scroll_restore_done", []),
    ("mobile_editor_focus_to_cursor_visible", "mobile_editor_focus_start", "mobile_editor_cursor_visible", ["block_id"]),
    ("keyboard_show_to_layout_stable", "keyboard_show_start", "keyboard_layout_stable", []),
]


def parse_trace_timestamp(value: str) -> float:
    parsed = dt.datetime.strptime(value, "%Y-%m-%d %H:%M:%S.%f")
    return parsed.timestamp() * 1000.0


def parse_trace_metadata(raw: str | None) -> dict[str, str]:
    metadata: dict[str, str] = {}
    if not raw:
        return metadata
    for token in raw.split():
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        metadata[key] = value
    return metadata


def parse_trace_log(path: Path) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), start=1):
        match = TRACE_LINE_RE.match(line)
        if not match:
            continue
        metadata = parse_trace_metadata(match.group("metadata"))
        events.append(
            {
                "line": line_number,
                "timestamp": match.group("timestamp"),
                "timestamp_ms": parse_trace_timestamp(match.group("timestamp")),
                "kind": match.group("kind"),
                "name": match.group("name"),
                "metadata": metadata,
            }
        )
    return events


def summary_for_float_samples(samples: list[float]) -> dict[str, Any]:
    return {
        "count": len(samples),
        "p50_ms": percentile_float(samples, 0.50),
        "p95_ms": percentile_float(samples, 0.95),
        "p99_ms": percentile_float(samples, 0.99),
        "max_ms": max(samples) if samples else 0.0,
        "samples_ms": samples,
    }


def trace_match_key(event: dict[str, Any], keys: list[str]) -> tuple[str, ...]:
    metadata = event["metadata"]
    return tuple(metadata.get(key, "") for key in keys)


def trace_pair_samples(events: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    pair_specs = {
        end_name: (metric_name, start_name, keys)
        for metric_name, start_name, end_name, keys in TRACE_POINT_PAIRS
    }
    start_queues: dict[tuple[str, str, tuple[str, ...]], list[dict[str, Any]]] = {}
    samples: dict[str, list[dict[str, Any]]] = {metric_name: [] for metric_name, *_ in TRACE_POINT_PAIRS}

    for event in events:
        if event["kind"] != "perf_point":
            continue
        for metric_name, start_name, _, keys in TRACE_POINT_PAIRS:
            if event["name"] == start_name:
                start_queues.setdefault((metric_name, start_name, trace_match_key(event, keys)), []).append(event)
        if event["name"] not in pair_specs:
            continue
        metric_name, start_name, keys = pair_specs[event["name"]]
        queue_key = (metric_name, start_name, trace_match_key(event, keys))
        queue = start_queues.get(queue_key, [])
        if not queue:
            continue
        start = queue.pop(0)
        duration_ms = max(0.0, event["timestamp_ms"] - start["timestamp_ms"])
        metadata = dict(event["metadata"])
        metadata.update({f"start_{key}": value for key, value in start["metadata"].items()})
        samples[metric_name].append(
            {
                "duration_ms": duration_ms,
                "start_line": start["line"],
                "end_line": event["line"],
                "metadata": metadata,
            }
        )
    return samples


def trace_interval_samples(events: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    intervals: dict[str, list[dict[str, Any]]] = {}
    for event in events:
        if event["kind"] != "perf_interval":
            continue
        duration = event["metadata"].get("duration_ms")
        if duration is None:
            continue
        try:
            duration_ms = float(duration)
        except ValueError:
            continue
        intervals.setdefault(event["name"], []).append(
            {
                "duration_ms": duration_ms,
                "line": event["line"],
                "metadata": event["metadata"],
            }
        )
        if event["name"] in {"keyboard_layout_stable", "keyboard_show_frame_pacing_done"}:
            keyboard_height = 0.0
            try:
                keyboard_height = float(event["metadata"].get("keyboard_height", "0"))
            except ValueError:
                keyboard_height = 0.0
            keyboard_kind = event["metadata"].get(
                "keyboard_kind",
                "software" if keyboard_height >= 120 else "accessory",
            )
            intervals.setdefault(f"{event['name']}_{keyboard_kind}", []).append(
                {
                    "duration_ms": duration_ms,
                    "line": event["line"],
                    "metadata": event["metadata"],
                }
            )
        if event["name"] in {
            "mobile_route_push_painted",
            "mobile_route_back_painted",
            "mobile_scroll_restore_done",
            "mobile_route_push_frame_pacing_done",
            "mobile_route_back_frame_pacing_done",
        }:
            if event["metadata"].get("source") != "programmatic":
                intervals.setdefault(f"{event['name']}_interactive", []).append(
                    {
                        "duration_ms": duration_ms,
                        "line": event["line"],
                        "metadata": event["metadata"],
                    }
                )
    return intervals


def analyze_trace_log(path: Path, label: str) -> dict[str, Any]:
    events = parse_trace_log(path)
    pair_samples = trace_pair_samples(events)
    interval_samples = trace_interval_samples(events)
    metrics: dict[str, Any] = {}
    for metric_name, samples in pair_samples.items():
        metrics[metric_name] = {
            "summary": summary_for_float_samples([sample["duration_ms"] for sample in samples]),
            "samples": samples,
            "source": "paired_perf_points",
        }
    for metric_name, samples in interval_samples.items():
        metrics[metric_name] = {
            "summary": summary_for_float_samples([sample["duration_ms"] for sample in samples]),
            "samples": samples,
            "source": "perf_interval_duration_ms",
        }

    slow_interactions: list[dict[str, Any]] = []
    for metric_name, metric in metrics.items():
        for sample in metric["samples"]:
            slow_interactions.append(
                {
                    "metric": metric_name,
                    "duration_ms": sample["duration_ms"],
                    "line": sample.get("line", sample.get("end_line")),
                    "metadata": sample.get("metadata", {}),
                }
            )
    slow_interactions.sort(key=lambda row: row["duration_ms"], reverse=True)
    long_intervals = [
        row
        for row in slow_interactions
        if row["duration_ms"] >= 50.0
    ]

    return {
        "created_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "label": label,
        "trace_path": str(path),
        "event_count": len(events),
        "metrics": metrics,
        "top_slow_interactions": slow_interactions[:10],
        "long_intervals": long_intervals[:25],
    }


def trace_rows(report: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for metric_name, metric in report.get("metrics", {}).items():
        summary = metric.get("summary", {})
        rows.append(
            {
                "metric": metric_name,
                "source": metric.get("source", ""),
                "p50_ms": float(summary.get("p50_ms", 0.0)),
                "p95_ms": float(summary.get("p95_ms", 0.0)),
                "p99_ms": float(summary.get("p99_ms", 0.0)),
                "max_ms": float(summary.get("max_ms", 0.0)),
                "count": int(float(summary.get("count", 0))),
            }
        )
    rows.sort(key=lambda row: (row["source"], row["metric"]))
    return rows


def markdown_table(headers: list[str], rows: list[list[str]]) -> list[str]:
    table = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join("---" for _ in headers) + " |",
    ]
    table.extend("| " + " | ".join(row) + " |" for row in rows)
    return table


def comparison_operation_family(operation_name: str) -> str:
    if operation_name.startswith("workspace_overview_"):
        return "workspace_overview"
    if operation_name.startswith("page_list_preview_blocks_"):
        return "page_list_preview_blocks"
    return operation_name


def command_report(args: argparse.Namespace) -> None:
    profile = json.loads(Path(args.profile).expanduser().read_text(encoding="utf-8")) if args.profile else None
    benchmarks = [
        (Path(path).expanduser().stem, json.loads(Path(path).expanduser().read_text(encoding="utf-8")))
        for path in args.benchmark
    ]
    traces = [
        (Path(path).expanduser().stem, json.loads(Path(path).expanduser().read_text(encoding="utf-8")))
        for path in (args.trace or [])
    ]

    lines: list[str] = [
        "# Editor Performance Report",
        "",
        f"- generated_at: {dt.datetime.now(dt.timezone.utc).isoformat()}",
    ]

    if profile:
        lines.extend(["", "## Dataset Profile", ""])
        profile_rows: list[list[str]] = []
        for label, dataset in profile.get("datasets", {}).items():
            counts = dataset.get("counts", {})
            blocks_per_page = dataset.get("blocks_per_page", {})
            profile_rows.append(
                [
                    label,
                    str(counts.get("pages", 0)),
                    str(counts.get("blocks", 0)),
                    str(counts.get("tags", 0)),
                    str(counts.get("attachments", 0)),
                    str(blocks_per_page.get("p95", 0)),
                    str(blocks_per_page.get("p99", 0)),
                    str(blocks_per_page.get("max", 0)),
                    dataset.get("integrity_check", "unknown"),
                ]
            )
        lines.extend(
            markdown_table(
                ["dataset", "pages", "blocks", "tags", "attachments", "blocks/page p95", "p99", "max", "integrity"],
                profile_rows,
            )
        )

    for report_label, benchmark in benchmarks:
        lines.extend(["", f"## Benchmark: {report_label}", ""])
        rows = benchmark_rows(benchmark)
        lines.extend(
            markdown_table(
                ["dataset", "operation", "p50 ms", "p95 ms", "p99 ms", "max ms", "samples"],
                [
                    [
                        row["dataset"],
                        row["operation"],
                        format_ms(row["p50_ms"]),
                        format_ms(row["p95_ms"]),
                        format_ms(row["p99_ms"]),
                        format_ms(row["max_ms"]),
                        str(row["count"]),
                    ]
                    for row in rows
                ],
            )
        )

    for trace_label, trace in traces:
        lines.extend(["", f"## UI Trace: {trace_label}", ""])
        lines.append(f"- events: {trace.get('event_count', 0)}")
        lines.append(f"- source: {trace.get('trace_path', '-')}")
        rows = trace_rows(trace)
        lines.extend(
            markdown_table(
                ["metric", "source", "p50 ms", "p95 ms", "p99 ms", "max ms", "samples"],
                [
                    [
                        row["metric"],
                        row["source"],
                        format_ms(row["p50_ms"]),
                        format_ms(row["p95_ms"]),
                        format_ms(row["p99_ms"]),
                        format_ms(row["max_ms"]),
                        str(row["count"]),
                    ]
                    for row in rows
                ],
            )
        )

    if len(benchmarks) >= 2:
        before_label, before_report = benchmarks[0]
        after_label, after_report = benchmarks[-1]
        before = {
            (row["dataset"], comparison_operation_family(row["operation"])): row
            for row in benchmark_rows(before_report)
        }
        after = {
            (row["dataset"], comparison_operation_family(row["operation"])): row
            for row in benchmark_rows(after_report)
        }
        comparison_rows: list[list[str]] = []
        for key in sorted(before.keys() & after.keys()):
            before_row = before[key]
            after_row = after[key]
            delta = after_row["p95_ms"] - before_row["p95_ms"]
            operation_label = before_row["operation"]
            if before_row["operation"] != after_row["operation"]:
                operation_label = f"{before_row['operation']} -> {after_row['operation']}"
            comparison_rows.append(
                [
                    key[0],
                    operation_label,
                    before_label,
                    format_ms(before_row["p95_ms"]),
                    after_label,
                    format_ms(after_row["p95_ms"]),
                    format_ms(delta),
                ]
            )
        lines.extend(["", "## Before / After P95", ""])
        if not comparison_rows:
            comparison_rows.append(
                [
                    "-",
                    "No comparable operation families",
                    before_label,
                    "-",
                    after_label,
                    "-",
                    "-",
                ]
            )
        lines.extend(
            markdown_table(
                ["dataset", "operation", "before", "before p95 ms", "after", "after p95 ms", "delta ms"],
                comparison_rows,
            )
        )

    all_slow_samples: list[dict[str, Any]] = []
    for report_label, benchmark in benchmarks:
        all_slow_samples.extend(slow_samples(benchmark, report_label))
    lines.extend(["", "## Top 10 Slow Samples", ""])
    lines.extend(
        markdown_table(
            ["report", "dataset", "operation", "sample", "duration ms"],
            [
                [
                    row["report"],
                    row["dataset"],
                    row["operation"],
                    str(row["sample"]),
                    format_ms(row["duration_ms"]),
                ]
                for row in all_slow_samples[:10]
            ],
        )
    )

    for trace_label, trace in traces:
        slow_rows = trace.get("top_slow_interactions", [])
        lines.extend(["", f"## Top 10 Slow UI Interactions: {trace_label}", ""])
        lines.extend(
            markdown_table(
                ["metric", "duration ms", "line", "metadata"],
                [
                    [
                        row.get("metric", ""),
                        format_ms(row.get("duration_ms", 0.0)),
                        str(row.get("line", "")),
                        " ".join(
                            f"{key}={value}"
                            for key, value in sorted(row.get("metadata", {}).items())
                            if key in {"platform", "block_id", "source", "text_length", "keyboard_visible", "cursor_visible"}
                        ),
                    ]
                    for row in slow_rows[:10]
                ],
            )
        )
        long_rows = trace.get("long_intervals", [])
        lines.extend(["", f"Long Trace Intervals >= 50ms: {trace_label}", ""])
        if long_rows:
            lines.extend(
                markdown_table(
                    ["metric", "duration ms", "line", "metadata"],
                    [
                        [
                            row.get("metric", ""),
                            format_ms(row.get("duration_ms", 0.0)),
                            str(row.get("line", "")),
                            " ".join(
                                f"{key}={value}"
                                for key, value in sorted(row.get("metadata", {}).items())
                                if key in {"platform", "block_id", "source", "text_length", "keyboard_visible", "cursor_visible"}
                            ),
                        ]
                        for row in long_rows[:10]
                    ],
                )
            )
        else:
            lines.append("No traced interval or interaction exceeded 50ms.")


    lines.extend(
        [
            "",
            "## Notes",
            "",
            "- DB benchmarks are read-only and run against isolated Current/xN copies when prepared with this script.",
            "- UI input/cursor/IME runtime events come from EditorPerformanceTrace when EDITOR_PERFORMANCE_TRACE_ENABLED=1.",
        ]
    )

    text = "\n".join(lines) + "\n"
    if args.output:
        output_path = Path(args.output).expanduser()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(text, encoding="utf-8")
    print(text)


def command_locate(_: argparse.Namespace) -> None:
    path = locate_db()
    valid, pages, blocks = is_valid_editor_db(path)
    print(f"{path}\npages={pages}\nblocks={blocks}\nvalid={valid}")


def command_profile(args: argparse.Namespace) -> None:
    path = Path(args.db).expanduser() if args.db else locate_db()
    write_report(profile_db(path, args.label), Path(args.output) if args.output else None)


def command_prepare(args: argparse.Namespace) -> None:
    source_db = Path(args.source_db).expanduser() if args.source_db else locate_db()
    timestamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    output_root = (
        Path(args.output_root).expanduser()
        if args.output_root
        else Path(tempfile.gettempdir()) / f"editor-performance-{timestamp}"
    )
    factors = sorted(set(args.factors))
    if 1 not in factors:
        factors.insert(0, 1)
    report = {
        "source_db": str(source_db),
        "source_store_dir": str(source_db.parent),
        "output_root": str(output_root),
        "datasets": prepare_datasets(source_db, output_root, factors),
    }
    report_path = output_root / "profile-report.json"
    write_report(report, report_path)
    eprint(f"wrote report: {report_path}")


def command_benchmark(args: argparse.Namespace) -> None:
    if args.report:
        targets = benchmark_from_report(Path(args.report).expanduser())
    elif args.db:
        targets = [(args.label, Path(args.db).expanduser())]
    else:
        targets = [("Current", locate_db())]
    selected_operations = set(args.operation) if args.operation else None
    report = {
        "created_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "iterations": args.iterations,
        "warmups": args.warmups,
        "datasets": {
            label: benchmark_database(
                path,
                label,
                args.iterations,
                args.warmups,
                selected_operations,
                args.page_limit,
            )
            for label, path in targets
        },
    }
    write_report(report, Path(args.output) if args.output else None)


def command_trace(args: argparse.Namespace) -> None:
    path = Path(args.input).expanduser()
    report = analyze_trace_log(path, args.label)
    write_report(report, Path(args.output) if args.output else None)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(required=True)

    locate = subparsers.add_parser("locate", help="Print the selected real Editor database path.")
    locate.set_defaults(func=command_locate)

    profile = subparsers.add_parser("profile", help="Profile a database without modifying it.")
    profile.add_argument("--db", help="Database path. Defaults to the located real Editor database.")
    profile.add_argument("--label", default="Current")
    profile.add_argument("--output", help="Optional JSON output path.")
    profile.set_defaults(func=command_profile)

    prepare = subparsers.add_parser("prepare", help="Prepare isolated Current/xN datasets.")
    prepare.add_argument("--source-db", help="Source database path. Defaults to the located real Editor database.")
    prepare.add_argument("--output-root", help="Output root. Defaults to /tmp/editor-performance-<timestamp>.")
    prepare.add_argument("--factors", type=int, nargs="+", default=[1, 5, 10])
    prepare.set_defaults(func=command_prepare)

    benchmark = subparsers.add_parser("benchmark", help="Run read-only p50/p95/p99 benchmarks.")
    benchmark.add_argument("--db", help="Database path for a single-database benchmark.")
    benchmark.add_argument("--label", default="Current")
    benchmark.add_argument("--report", help="profile-report.json from the prepare command.")
    benchmark.add_argument("--iterations", type=int, default=15)
    benchmark.add_argument("--warmups", type=int, default=3)
    benchmark.add_argument("--page-limit", type=int, help="Limit page IDs for page-list preview operations.")
    benchmark.add_argument(
        "--operation",
        action="append",
        choices=[
            "workspace_overview_current",
            "workspace_overview_fast",
            "workspace_overview_window",
            "workspace_overview_parts",
            "page_list_preview_blocks_current",
            "page_list_preview_blocks_window",
            "largest_page_blocks",
            "selected_largest_page_blocks",
            "search_index_query",
        ],
        help="Limit benchmark to one operation. May be passed more than once.",
    )
    benchmark.add_argument("--output", help="Optional JSON output path.")
    benchmark.set_defaults(func=command_benchmark)

    report = subparsers.add_parser("report", help="Render benchmark/profile JSON as a Markdown report.")
    report.add_argument("--profile", help="profile-report.json from the prepare command.")
    report.add_argument(
        "--benchmark",
        action="append",
        required=True,
        help="Benchmark JSON path. Pass multiple times for before/after comparison.",
    )
    report.add_argument("--output", help="Optional Markdown output path.")
    report.add_argument(
        "--trace",
        action="append",
        help="Trace JSON from the trace command. Pass multiple times to include more traces.",
    )
    report.set_defaults(func=command_report)

    trace = subparsers.add_parser("trace", help="Analyze EditorPerformanceTrace OSLog text output.")
    trace.add_argument("--input", required=True, help="OSLog text file captured from log show/stream.")
    trace.add_argument("--label", default="UI_Trace")
    trace.add_argument("--output", help="Optional JSON output path.")
    trace.set_defaults(func=command_trace)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
