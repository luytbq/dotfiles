#!/usr/bin/env python3
"""Local web UI for the askjev call log. Stdlib only; binds to 127.0.0.1."""
from __future__ import annotations

import argparse
import json
import sys
import webbrowser
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

import jevlog

PAGE = Path(__file__).with_name("jevlog_ui.html")
MAX_PAGE_SIZE = 500


class Handler(BaseHTTPRequestHandler):
    server_version = "jevlog-ui"

    def log_message(self, fmt: str, *args: Any) -> None:
        if not self.server.quiet:  # type: ignore[attr-defined]
            super().log_message(fmt, *args)

    # ------------------------------------------------------------ plumbing

    def _send(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, data: Any, status: int = 200) -> None:
        self._send(status, json.dumps(data, ensure_ascii=False, default=str).encode(), "application/json; charset=utf-8")

    def _error(self, message: str, status: int = 400) -> None:
        self._json({"error": message}, status)

    def _host_ok(self) -> bool:
        # Rejects DNS-rebinding: a hostile page resolving its own name to 127.0.0.1 sends its own Host.
        host = (self.headers.get("Host") or "").rsplit(":", 1)[0]
        return host in {"127.0.0.1", "localhost", "[::1]"}

    def _filters(self, q: dict[str, list[str]]) -> tuple[str, list[Any]]:
        get = lambda k: (q.get(k) or [None])[0]  # noqa: E731
        return jevlog.build_where(
            ts_from=get("from"), ts_to=get("to"), include_eval=get("include_eval") == "1",
            quick=get("q"), where=get("where"),
        )

    # ------------------------------------------------------------ routes

    def do_GET(self) -> None:  # noqa: N802
        if not self._host_ok():
            return self._error("bad host", HTTPStatus.FORBIDDEN)
        url = urlparse(self.path)
        q = parse_qs(url.query)
        try:
            if url.path in {"/", "/index.html"}:
                return self._send(200, PAGE.read_bytes(), "text/html; charset=utf-8")
            if url.path == "/api/info":
                return self._json({**jevlog.db_info(), "columns": jevlog.SEARCH_COLUMNS, "ddl": jevlog.schema_ddl()})
            if url.path in {"/api/calls", "/api/stats"} or url.path.startswith("/api/calls/"):
                conn = jevlog.connect_readonly()
                try:
                    if url.path.startswith("/api/calls/"):
                        call = jevlog.get_call(conn, int(url.path.rsplit("/", 1)[1]))
                        return self._json(call) if call else self._error("not found", 404)
                    where_sql, params = self._filters(q)
                    if url.path == "/api/stats":
                        return self._json(jevlog.stats(conn, where_sql, params))
                    limit = min(int((q.get("limit") or ["50"])[0]), MAX_PAGE_SIZE)
                    offset = int((q.get("offset") or ["0"])[0])
                    return self._json(jevlog.search(conn, where_sql, params, limit, offset))
                finally:
                    conn.close()
            return self._error("not found", 404)
        except jevlog.QueryError as exc:
            return self._error(str(exc))
        except ValueError as exc:
            return self._error(f"tham số không hợp lệ: {exc}")

    def do_POST(self) -> None:  # noqa: N802
        if not self._host_ok():
            return self._error("bad host", HTTPStatus.FORBIDDEN)
        # A custom header forces a CORS preflight, which this server never answers,
        # so other sites open in the browser cannot trigger a purge.
        if self.headers.get("X-Jevlog") != "1" or "application/json" not in (self.headers.get("Content-Type") or ""):
            return self._error("forbidden", HTTPStatus.FORBIDDEN)
        if urlparse(self.path).path != "/api/purge":
            return self._error("not found", 404)
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length") or 0)) or b"{}")
            return self._json(jevlog.purge(
                body.get("from") or None, body.get("to") or None,
                source=body.get("source") or None, dry_run=not body.get("confirm"),
            ))
        except (jevlog.QueryError, ValueError) as exc:
            return self._error(str(exc))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Browse, search and prune the askjev call log.")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--open", action="store_true", help="open the browser")
    parser.add_argument("--quiet", action="store_true", help="no per-request access log")
    args = parser.parse_args(argv)

    info = jevlog.db_info()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.quiet = args.quiet  # type: ignore[attr-defined]
    url = f"http://127.0.0.1:{args.port}/"
    print(f"jevlog UI: {url}  (db: {info['path']}, {info['calls']} calls)  Ctrl+C to stop", flush=True)
    if args.open:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
