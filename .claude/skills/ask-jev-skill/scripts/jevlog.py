#!/usr/bin/env python3
"""SQLite call log for askjev: record, search, stats, purge. Stdlib only."""
from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
import unicodedata
from datetime import datetime, timedelta, timezone
from functools import lru_cache
from pathlib import Path
from typing import Any

DEFAULT_DB = Path.home() / ".claude" / "askjev" / "askjev.db"
SCHEMA_VERSION = 1
QUERY_TIME_LIMIT_S = 2.0

SCHEMA = """
CREATE TABLE IF NOT EXISTS calls (
  id INTEGER PRIMARY KEY,
  ts TEXT NOT NULL,
  duration_ms INTEGER,
  attempts INTEGER,
  status TEXT NOT NULL,
  http_status INTEGER,
  error TEXT,
  model TEXT,
  cmd TEXT,
  source TEXT,
  cwd TEXT,
  repo TEXT,
  tag TEXT,
  why TEXT,
  min_confidence REAL,
  act_all INTEGER,
  exit_code INTEGER,
  input_tokens INTEGER,
  output_tokens INTEGER,
  state_text TEXT,
  questions_text TEXT,
  decisions TEXT,
  types TEXT,
  gates TEXT,
  min_conf REAL,
  max_conf REAL,
  request_json TEXT,
  response_json TEXT
);
CREATE INDEX IF NOT EXISTS idx_calls_ts ON calls(ts);
CREATE TABLE IF NOT EXISTS questions (
  call_id INTEGER NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
  qid TEXT,
  type TEXT,
  instructions TEXT,
  criteria_json TEXT,
  decision TEXT,
  confidence REAL,
  noul REAL,
  gate TEXT
);
CREATE INDEX IF NOT EXISTS idx_questions_call ON questions(call_id);
CREATE VIEW IF NOT EXISTS search_v AS
SELECT id, ts, datetime(ts, 'localtime') AS ts_local, status, http_status, error,
       model, cmd, source, repo, cwd, tag, why,
       state_text AS state, questions_text, decisions, types, gates,
       min_conf, max_conf, duration_ms, attempts, act_all, exit_code,
       input_tokens, output_tokens,
       coalesce(request_json, '') || char(10) || coalesce(response_json, '') AS raw
FROM calls;
"""

SEARCH_COLUMNS = [
    ("id", "integer"), ("ts", "UTC ISO8601"), ("ts_local", "giờ máy, 'YYYY-MM-DD HH:MM:SS'"),
    ("status", "ok | http_error | error | disabled"), ("http_status", "integer"), ("error", "text"),
    ("model", "text"), ("cmd", "choice | noul | score | payload | api"), ("source", "cli | eval"),
    ("repo", "tên git repo"), ("cwd", "text"), ("tag", "text"), ("why", "text"),
    ("state", "state đã gửi, JSON hoặc text"), ("questions_text", "instructions + criteria"),
    ("decisions", "'qid=decision' cách nhau bởi dấu phẩy"), ("types", "vd 'choice,noul'"),
    ("gates", "vd 'act,escalate'"), ("min_conf", "real, choice/score"), ("max_conf", "real"),
    ("duration_ms", "integer"), ("attempts", "integer"), ("act_all", "0 | 1"),
    ("exit_code", "0 | 1 | 2 | 3"), ("input_tokens", "integer"), ("output_tokens", "integer"),
    ("raw", "request + response JSON"),
]


def db_path() -> Path:
    raw = os.environ.get("ASKJEV_DB", "").strip()
    return Path(raw).expanduser() if raw else DEFAULT_DB


def logging_enabled() -> bool:
    return os.environ.get("ASKJEV_LOG", "1").strip().lower() not in {"0", "false", "no", "off"}


def connect(path: Path | None = None) -> sqlite3.Connection:
    path = path or db_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    fresh = not path.exists()
    conn = sqlite3.connect(path, timeout=5.0)
    if fresh:
        os.chmod(path, 0o600)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    if conn.execute("PRAGMA user_version").fetchone()[0] < SCHEMA_VERSION:
        conn.executescript(SCHEMA)
        conn.execute(f"PRAGMA user_version={SCHEMA_VERSION}")
    return conn


# ---------------------------------------------------------------- matching helpers

def _fold(text: str) -> str:
    # đ/Đ has no combining-mark decomposition, so NFD alone leaves it untouched.
    text = text.replace("đ", "d").replace("Đ", "D")
    decomposed = unicodedata.normalize("NFD", text)
    return "".join(ch for ch in decomposed if unicodedata.category(ch) != "Mn").casefold()


@lru_cache(maxsize=256)
def _like_regex(pattern: str) -> re.Pattern[str]:
    parts = []
    for ch in _fold(pattern):
        parts.append(".*" if ch == "%" else "." if ch == "_" else re.escape(ch))
    return re.compile("".join(parts), re.DOTALL)


def _ulike(value: Any, pattern: Any) -> int | None:
    if value is None or pattern is None:
        return None
    return int(_like_regex(str(pattern)).fullmatch(_fold(str(value))) is not None)


@lru_cache(maxsize=256)
def _compiled(pattern: str) -> re.Pattern[str]:
    return re.compile(pattern)


def _regexp(pattern: Any, value: Any) -> int | None:
    if value is None or pattern is None:
        return None
    return int(_compiled(str(pattern)).search(str(value)) is not None)


def register_functions(conn: sqlite3.Connection) -> None:
    conn.create_function("ulike", 2, _ulike, deterministic=True)
    conn.create_function("regexp", 2, _regexp, deterministic=True)


# ---------------------------------------------------------------- recording

def _repo_name(cwd: str) -> str | None:
    try:
        out = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=1.0, check=False,
        )
    except Exception:  # noqa: BLE001 - git missing or slow must not break logging
        return None
    return Path(out.stdout.strip()).name if out.returncode == 0 and out.stdout.strip() else None


def _tokens(usage: Any) -> tuple[int | None, int | None]:
    if not isinstance(usage, dict):
        return None, None

    def pick(*keys: str) -> int | None:
        for key in keys:
            if isinstance(usage.get(key), (int, float)):
                return int(usage[key])
        return None

    return pick("input_tokens", "prompt_tokens"), pick("output_tokens", "completion_tokens")


def _text(value: Any) -> str:
    return value if isinstance(value, str) else json.dumps(value, ensure_ascii=False)


def _questions_text(questions: dict[str, Any]) -> str:
    lines = []
    for qid, q in questions.items():
        if not isinstance(q, dict):
            continue
        lines.append(f"{qid} [{q.get('type')}] {q.get('instructions', '')}")
        criteria = q.get("criteria")
        if isinstance(criteria, dict):
            lines.extend(f"  {k}: {v}" for k, v in criteria.items())
        elif isinstance(criteria, list):
            lines.extend(f"  - {item}" for item in criteria)
    return "\n".join(lines)


def _decision_text(verdict: dict[str, Any]) -> str | None:
    if verdict.get("type") == "noul":
        return verdict.get("gate")
    decision = verdict.get("decision")
    return None if decision is None else str(decision)


def record(
    *,
    cmd: str,
    request: dict[str, Any] | None,
    response: dict[str, Any] | None,
    verdicts: dict[str, Any] | None,
    status: str,
    error: str | None = None,
    http_status: int | None = None,
    duration_ms: int | None = None,
    attempts: int | None = None,
    min_confidence: float | None = None,
    act_all: bool | None = None,
    exit_code: int | None = None,
    why: str | None = None,
    tag: str | None = None,
) -> int | None:
    """Insert one call. Never raises: a logging failure must not change askjev's result."""
    if not logging_enabled():
        return None
    try:
        request = request or {}
        response = response or {}
        verdicts = verdicts or {}
        questions = request.get("questions") if isinstance(request.get("questions"), dict) else {}
        cwd = os.getcwd()
        in_tok, out_tok = _tokens(response.get("usage"))
        confs = [v["confidence"] for v in verdicts.values() if isinstance(v.get("confidence"), (int, float))]
        conn = connect()
        try:
            with conn:
                cur = conn.execute(
                    """INSERT INTO calls (ts, duration_ms, attempts, status, http_status, error, model, cmd,
                       source, cwd, repo, tag, why, min_confidence, act_all, exit_code, input_tokens,
                       output_tokens, state_text, questions_text, decisions, types, gates, min_conf,
                       max_conf, request_json, response_json)
                       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                    (
                        datetime.now(timezone.utc).isoformat(timespec="milliseconds"),
                        duration_ms, attempts, status, http_status, error,
                        response.get("model") or request.get("model"), cmd,
                        os.environ.get("ASKJEV_SOURCE", "cli"), cwd, _repo_name(cwd), tag, why,
                        min_confidence, None if act_all is None else int(act_all), exit_code,
                        in_tok, out_tok,
                        _text(request.get("state")) if "state" in request else None,
                        _questions_text(questions),
                        ", ".join(f"{qid}={_decision_text(v)}" for qid, v in verdicts.items()),
                        ",".join(str(q.get("type")) for q in questions.values() if isinstance(q, dict)),
                        ",".join(str(v.get("gate")) for v in verdicts.values()),
                        min(confs) if confs else None, max(confs) if confs else None,
                        json.dumps(request, ensure_ascii=False) if request else None,
                        json.dumps(response, ensure_ascii=False) if response else None,
                    ),
                )
                call_id = cur.lastrowid
                rows = []
                for qid, q in questions.items():
                    q = q if isinstance(q, dict) else {}
                    v = verdicts.get(qid, {})
                    rows.append((
                        call_id, qid, q.get("type"), q.get("instructions"),
                        json.dumps(q.get("criteria"), ensure_ascii=False), _decision_text(v),
                        v.get("confidence"), v.get("noul"), v.get("gate"),
                    ))
                conn.executemany("INSERT INTO questions VALUES (?,?,?,?,?,?,?,?,?)", rows)
            return call_id
        finally:
            conn.close()
    except Exception as exc:  # noqa: BLE001
        sys.stderr.write(f"askjev: call log write failed ({db_path()}): {exc}\n")
        return None


# ---------------------------------------------------------------- read-only querying

_READ_ONLY_ACTIONS = {sqlite3.SQLITE_SELECT, sqlite3.SQLITE_READ, sqlite3.SQLITE_FUNCTION}
_ALLOWED_TABLES = {"calls", "questions", "search_v"}


def _authorizer(action: int, arg1: str | None, _arg2: str | None, _db: str | None, _src: str | None) -> int:
    if action not in _READ_ONLY_ACTIONS:
        return sqlite3.SQLITE_DENY
    if action == sqlite3.SQLITE_READ and arg1 not in _ALLOWED_TABLES:
        return sqlite3.SQLITE_DENY
    return sqlite3.SQLITE_OK


def connect_readonly(path: Path | None = None) -> sqlite3.Connection:
    """Connection for user-supplied WHERE clauses: read-only file, read-only authorizer, time limit."""
    path = path or db_path()
    connect(path).close()
    conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=5.0)
    conn.row_factory = sqlite3.Row
    register_functions(conn)
    conn.set_authorizer(_authorizer)
    return conn


class QueryError(ValueError):
    pass


def _run(conn: sqlite3.Connection, sql: str, params: list[Any]) -> list[sqlite3.Row]:
    deadline = time.monotonic() + QUERY_TIME_LIMIT_S
    conn.set_progress_handler(lambda: int(time.monotonic() > deadline), 10_000)
    try:
        return conn.execute(sql, params).fetchall()
    except sqlite3.Error as exc:
        if "interrupted" in str(exc):
            raise QueryError(f"truy vấn chạy quá {QUERY_TIME_LIMIT_S:g}s, đã dừng") from None
        raise QueryError(str(exc)) from None
    finally:
        conn.set_progress_handler(None, 0)


QUICK_COLUMNS = ("why", "tag", "state", "questions_text", "decisions", "error")


def build_where(
    *, ts_from: str | None = None, ts_to: str | None = None, include_eval: bool = False,
    quick: str | None = None, where: str | None = None,
) -> tuple[str, list[Any]]:
    clauses: list[str] = []
    params: list[Any] = []
    if ts_from:
        clauses.append("ts >= ?")
        params.append(ts_from)
    if ts_to:
        clauses.append("ts < ?")
        params.append(ts_to)
    if not include_eval:
        clauses.append("coalesce(source, 'cli') != 'eval'")
    if quick and quick.strip():
        pattern = f"%{quick.strip()}%"
        clauses.append("(" + " OR ".join(f"ulike({c}, ?)" for c in QUICK_COLUMNS) + ")")
        params.extend([pattern] * len(QUICK_COLUMNS))
    if where and where.strip():
        # Own lines so a trailing "--" comment in user input cannot swallow the closing paren.
        clauses.append("(\n" + where.strip() + "\n)")
    return (" AND ".join(clauses) or "1"), params


def search(conn: sqlite3.Connection, where_sql: str, params: list[Any], limit: int = 50, offset: int = 0) -> dict[str, Any]:
    total = _run(conn, f"SELECT count(*) FROM search_v WHERE {where_sql}", params)[0][0]
    rows = _run(
        conn,
        f"""SELECT id, ts, status, cmd, source, repo, tag, why, decisions, types, gates,
                   min_conf, duration_ms, exit_code, error
            FROM search_v WHERE {where_sql} ORDER BY ts DESC LIMIT ? OFFSET ?""",
        [*params, limit, offset],
    )
    return {"total": total, "rows": [dict(r) for r in rows]}


def get_call(conn: sqlite3.Connection, call_id: int) -> dict[str, Any] | None:
    rows = _run(conn, "SELECT * FROM calls WHERE id = ?", [call_id])
    if not rows:
        return None
    call = dict(rows[0])
    for key in ("request_json", "response_json"):
        call[key] = json.loads(call[key]) if call[key] else None
    call["questions"] = [dict(r) for r in _run(conn, "SELECT * FROM questions WHERE call_id = ?", [call_id])]
    for q in call["questions"]:
        q["criteria"] = json.loads(q.pop("criteria_json") or "null")
    return call


def _percentile(sorted_vals: list[int], pct: float) -> int | None:
    if not sorted_vals:
        return None
    idx = min(len(sorted_vals) - 1, max(0, round(pct * (len(sorted_vals) - 1))))
    return sorted_vals[idx]


def stats(conn: sqlite3.Connection, where_sql: str, params: list[Any]) -> dict[str, Any]:
    scope = f"SELECT id FROM search_v WHERE {where_sql}"
    one = lambda sql: _run(conn, sql, params)  # noqa: E731

    totals = dict(one(f"""SELECT count(*) AS calls,
            sum(status = 'ok') AS ok, sum(status != 'ok') AS failed,
            sum(act_all = 0) AS escalated_calls,
            sum(input_tokens) AS input_tokens, sum(output_tokens) AS output_tokens
        FROM search_v WHERE {where_sql}""")[0])
    durations = [r[0] for r in one(
        f"SELECT duration_ms FROM search_v WHERE {where_sql} AND status = 'ok' AND duration_ms IS NOT NULL ORDER BY duration_ms"
    )]
    totals["p50_ms"] = _percentile(durations, 0.5)
    totals["p95_ms"] = _percentile(durations, 0.95)

    def grouped(column: str, limit: int = 10) -> list[dict[str, Any]]:
        return [dict(r) for r in one(
            f"""SELECT coalesce({column}, '(trống)') AS key, count(*) AS n FROM search_v
                WHERE {where_sql} GROUP BY 1 ORDER BY n DESC LIMIT {limit}"""
        )]

    return {
        "totals": totals,
        "per_day": [dict(r) for r in one(
            f"""SELECT date(ts, 'localtime') AS day, count(*) AS n, sum(status != 'ok') AS failed
                FROM search_v WHERE {where_sql} GROUP BY 1 ORDER BY 1"""
        )],
        "gates": [dict(r) for r in one(
            f"""SELECT type, gate, count(*) AS n FROM questions
                WHERE call_id IN ({scope}) AND gate IS NOT NULL GROUP BY 1, 2 ORDER BY 1, 3 DESC"""
        )],
        "confidence_hist": [dict(r) for r in one(
            f"""SELECT min(cast(confidence * 10 AS INTEGER), 9) AS bin, count(*) AS n FROM questions
                WHERE call_id IN ({scope}) AND confidence IS NOT NULL GROUP BY 1 ORDER BY 1"""
        )],
        "noul_hist": [dict(r) for r in one(
            f"""SELECT min(cast(noul * 10 AS INTEGER), 9) AS bin, count(*) AS n FROM questions
                WHERE call_id IN ({scope}) AND noul IS NOT NULL GROUP BY 1 ORDER BY 1"""
        )],
        "by_repo": grouped("repo"),
        "by_tag": grouped("tag"),
        "by_cmd": grouped("cmd"),
        "by_status": grouped("status"),
        "by_model": grouped("model"),
    }


# ---------------------------------------------------------------- maintenance

def db_info(path: Path | None = None) -> dict[str, Any]:
    path = path or db_path()
    conn = connect(path)
    try:
        count, oldest, newest = conn.execute("SELECT count(*), min(ts), max(ts) FROM calls").fetchone()
    finally:
        conn.close()
    size = sum(p.stat().st_size for p in (path, Path(f"{path}-wal"), Path(f"{path}-shm")) if p.exists())
    return {"path": str(path), "bytes": size, "calls": count, "oldest": oldest, "newest": newest}


def schema_ddl(path: Path | None = None) -> list[dict[str, str]]:
    conn = connect(path)
    try:
        rows = conn.execute(
            """SELECT type, name, sql FROM sqlite_master
               WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'
               ORDER BY CASE type WHEN 'view' THEN 0 WHEN 'table' THEN 1 ELSE 2 END, name"""
        ).fetchall()
    finally:
        conn.close()
    return [{"type": t, "name": n, "sql": s} for t, n, s in rows]


def _purge_where(ts_from: str | None, ts_to: str | None, source: str | None) -> tuple[str, list[Any]]:
    if not ts_from and not ts_to:
        raise QueryError("cần ít nhất một mốc thời gian (from hoặc to)")
    clauses, params = [], []
    if ts_from:
        clauses.append("ts >= ?")
        params.append(ts_from)
    if ts_to:
        clauses.append("ts < ?")
        params.append(ts_to)
    if source:
        clauses.append("coalesce(source, 'cli') = ?")
        params.append(source)
    return " AND ".join(clauses), params


def purge(ts_from: str | None, ts_to: str | None, *, source: str | None = None, dry_run: bool = True) -> dict[str, Any]:
    where_sql, params = _purge_where(ts_from, ts_to, source)
    conn = connect()
    try:
        count, approx = conn.execute(
            f"""SELECT count(*), coalesce(sum(length(request_json) + length(response_json)
                    + length(coalesce(state_text, '')) + length(coalesce(questions_text, ''))), 0)
                FROM calls WHERE {where_sql}""",
            params,
        ).fetchone()
        result: dict[str, Any] = {"matched": count, "approx_bytes": approx, "dry_run": dry_run}
        if dry_run or count == 0:
            return result
        before = db_info()["bytes"]
        with conn:
            conn.execute(f"DELETE FROM questions WHERE call_id IN (SELECT id FROM calls WHERE {where_sql})", params)
            conn.execute(f"DELETE FROM calls WHERE {where_sql}", params)
        # In WAL mode VACUUM writes the rebuilt file into the WAL; checkpoint afterwards to shrink it.
        conn.execute("VACUUM")
        conn.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        result.update(deleted=count, bytes_before=before, bytes_after=db_info()["bytes"])
        return result
    finally:
        conn.close()


# ---------------------------------------------------------------- CLI

def _day_to_utc(day: str) -> str:
    local = datetime.strptime(day, "%Y-%m-%d").astimezone()
    return local.astimezone(timezone.utc).isoformat(timespec="milliseconds")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Inspect and prune the askjev call log.")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("info", help="DB path, size, row count")

    p_stats = sub.add_parser("stats", help="summary over the last N days")
    p_stats.add_argument("--days", type=int, default=30)
    p_stats.add_argument("--include-eval", action="store_true")

    p_purge = sub.add_parser("purge", help="delete calls in a local-date range, then VACUUM")
    p_purge.add_argument("--from", dest="day_from", help="YYYY-MM-DD, inclusive")
    p_purge.add_argument("--before", dest="day_to", help="YYYY-MM-DD, exclusive")
    p_purge.add_argument("--older-than-days", type=int)
    p_purge.add_argument("--source", choices=["cli", "eval"])
    p_purge.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    if args.cmd == "info":
        out = db_info()
    elif args.cmd == "stats":
        since = (datetime.now(timezone.utc) - timedelta(days=args.days)).isoformat(timespec="milliseconds")
        conn = connect_readonly()
        try:
            where_sql, params = build_where(ts_from=since, include_eval=args.include_eval)
            out = stats(conn, where_sql, params)
        finally:
            conn.close()
    else:
        ts_from = _day_to_utc(args.day_from) if args.day_from else None
        ts_to = _day_to_utc(args.day_to) if args.day_to else None
        if args.older_than_days is not None:
            ts_to = (datetime.now(timezone.utc) - timedelta(days=args.older_than_days)).isoformat(timespec="milliseconds")
        try:
            out = purge(ts_from, ts_to, source=args.source, dry_run=args.dry_run)
        except QueryError as exc:
            parser.error(str(exc))
    json.dump(out, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
