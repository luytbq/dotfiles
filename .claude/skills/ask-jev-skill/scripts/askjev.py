#!/usr/bin/env python3
"""Ask TypeSafe Jev for a typed tiebreak. Stdlib only."""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

import jevlog

ENDPOINT = "https://api.typesafe.ai/v1/systemone"
DEFAULT_MODEL = "jev-latest"
DEFAULT_MIN_CONF = 0.6
NOUL_YES = 0.7
NOUL_NO = 0.3


def disabled_reason() -> str | None:
    flag = os.environ.get("ASKJEV_DISABLED", "").strip().lower()
    if flag in {"1", "true", "yes", "on"}:
        return "ASKJEV_DISABLED is set"
    if not os.environ.get("TYPESAFE_AI_KEY"):
        return "TYPESAFE_AI_KEY is missing"
    return None


def _request_json(
    url: str, payload: dict[str, Any] | None, timeout: float, trace: dict[str, Any] | None = None
) -> dict[str, Any]:
    key = os.environ["TYPESAFE_AI_KEY"]
    data = None if payload is None else json.dumps(payload).encode()
    last_err = "unknown error"
    trace = {} if trace is None else trace
    for attempt in range(4):
        trace["attempts"] = attempt + 1
        req = urllib.request.Request(
            url,
            data=data,
            method="GET" if payload is None else "POST",
            headers={
                "Authorization": f"Bearer {key}",
                "Accept": "application/json",
                "User-Agent": "claude-askjev/0.1",
                **({"Content-Type": "application/json"} if payload is not None else {}),
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return json.loads(resp.read().decode())
        except urllib.error.HTTPError as exc:
            body = exc.read().decode(errors="replace")
            trace["http_status"] = exc.code
            if exc.code in (429, 529) and attempt < 3:
                retry_after = exc.headers.get("Retry-After")
                try:
                    delay = float(retry_after) if retry_after else 0.5 * (2 ** attempt)
                except ValueError:
                    delay = 0.5 * (2 ** attempt)
                time.sleep(min(delay, 8.0))
                last_err = f"HTTP {exc.code}: {body[:300]}"
                continue
            raise SystemExit(f"askjev HTTP {exc.code}: {body[:800]}") from None
        except Exception as exc:  # noqa: BLE001 - CLI must survive transient DNS/timeouts
            last_err = str(exc)
            if attempt < 3:
                time.sleep(0.5 * (2 ** attempt))
                continue
            raise SystemExit(f"askjev request failed: {last_err}") from None
    raise SystemExit(f"askjev request failed: {last_err}")


def call(
    payload: dict[str, Any],
    timeout: float = 15.0,
    *,
    cmd: str = "api",
    min_conf: float = DEFAULT_MIN_CONF,
    why: str | None = None,
    tag: str | None = None,
) -> tuple[dict[str, Any], int | None]:
    """Call Jev and append the call to the local log. Returns (response, call_id)."""
    meta = payload.get("meta") if isinstance(payload.get("meta"), dict) else {}
    why = why or meta.get("why")
    tag = tag or meta.get("tag")
    body = {
        "state": payload["state"],
        "model": payload.get("model") or os.environ.get("TYPESAFE_DEFAULT_MODEL") or DEFAULT_MODEL,
        "questions": payload["questions"],
    }
    trace: dict[str, Any] = {}
    started = time.perf_counter()
    try:
        response = _request_json(ENDPOINT, body, timeout, trace)
    except SystemExit as exc:
        jevlog.record(
            cmd=cmd, request=body, response=None, verdicts=None,
            status="http_error" if trace.get("http_status") else "error", error=str(exc),
            http_status=trace.get("http_status"), duration_ms=int((time.perf_counter() - started) * 1000),
            attempts=trace.get("attempts"), min_confidence=min_conf, exit_code=1, why=why, tag=tag,
        )
        raise
    wrapped = wrap(response, min_conf)
    call_id = jevlog.record(
        cmd=cmd, request=body, response=response, verdicts=wrapped["verdicts"], status="ok",
        duration_ms=int((time.perf_counter() - started) * 1000), attempts=trace.get("attempts"),
        min_confidence=min_conf, act_all=wrapped["act_all"], exit_code=0 if wrapped["act_all"] else 3,
        why=why, tag=tag,
    )
    return response, call_id


def system_one(payload: dict[str, Any], timeout: float = 15.0) -> dict[str, Any]:
    return call(payload, timeout)[0]


def verdicts(answers: dict[str, Any], min_conf: float) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for qid, ans in answers.items():
        kind = ans.get("type")
        if kind == "choice":
            conf = float(ans.get("confidence") or 0.0)
            act = conf >= min_conf
            out[qid] = {
                "type": kind,
                "decision": ans.get("choice"),
                "confidence": conf,
                "act": act,
                "gate": "act" if act else "escalate",
            }
        elif kind == "score":
            conf = float(ans.get("confidence") or 0.0)
            act = conf >= min_conf
            out[qid] = {
                "type": kind,
                "decision": ans.get("score"),
                "confidence": conf,
                "act": act,
                "gate": "act" if act else "escalate",
            }
        elif kind == "noul":
            noul = float(ans.get("noul") or 0.0)
            if noul >= NOUL_YES:
                gate, act, decision = "yes", True, True
            elif noul <= NOUL_NO:
                gate, act, decision = "no", True, False
            else:
                gate, act, decision = "uncertain", False, None
            out[qid] = {
                "type": kind,
                "noul": noul,
                "decision": decision,
                "act": act,
                "gate": gate,
            }
        else:
            out[qid] = {"type": kind, "act": False, "gate": "unknown"}
    return out


def wrap(response: dict[str, Any], min_conf: float) -> dict[str, Any]:
    answers = response.get("answers") or {}
    v = verdicts(answers, min_conf)
    return {
        "model": response.get("model"),
        "answers": answers,
        "verdicts": v,
        "usage": response.get("usage"),
        "min_confidence": min_conf,
        "act_all": bool(v) and all(item.get("act") for item in v.values()),
    }


def _parse_option(raw: str) -> tuple[str, str | None]:
    if "=" in raw:
        key, _, value = raw.partition("=")
        return key.strip(), (value.strip() or None)
    return raw.strip(), None


def _load_payload(path: str) -> dict[str, Any]:
    text = sys.stdin.read() if path == "-" else Path(path).read_text(encoding="utf-8")
    data = json.loads(text)
    if not isinstance(data, dict) or "state" not in data or "questions" not in data:
        raise SystemExit("payload must be a JSON object with state and questions")
    return data


def _emit(result: dict[str, Any], min_conf: float, call_id: int | None = None) -> int:
    wrapped = wrap(result, min_conf)
    wrapped["call_id"] = call_id
    json.dump(wrapped, sys.stdout, indent=2, sort_keys=False)
    sys.stdout.write("\n")
    if not wrapped["act_all"]:
        return 3
    return 0


def main(argv: list[str] | None = None) -> int:
    # SUPPRESS keeps a subparser from resetting a value given before the subcommand.
    meta_args = argparse.ArgumentParser(add_help=False, argument_default=argparse.SUPPRESS)
    meta_args.add_argument("--why", help="one sentence: the fork being decided (logged, not sent to Jev)")
    meta_args.add_argument("--tag", help="short label for grouping in the log (not sent to Jev)")

    parser = argparse.ArgumentParser(description="Ask TypeSafe Jev for a typed tiebreak.", parents=[meta_args])
    parser.add_argument("--model", default=None)
    parser.add_argument("--min-confidence", type=float, default=DEFAULT_MIN_CONF)
    parser.add_argument("--timeout", type=float, default=15.0)
    sub = parser.add_subparsers(dest="cmd")

    p_payload = sub.add_parser("payload", aliases=["raw"], parents=[meta_args])
    p_payload.add_argument("path", help="JSON file or - for stdin")

    p_choice = sub.add_parser("choice", parents=[meta_args])
    p_choice.add_argument("--state", required=True)
    p_choice.add_argument("--question", required=True)
    p_choice.add_argument("--option", action="append", required=True, dest="options")
    p_choice.add_argument("--id", default="path")

    p_noul = sub.add_parser("noul", parents=[meta_args])
    p_noul.add_argument("--state", required=True)
    p_noul.add_argument("--question", required=True)
    p_noul.add_argument("--yes", default=None)
    p_noul.add_argument("--no", default=None)
    p_noul.add_argument("--id", default="check")

    p_score = sub.add_parser("score", parents=[meta_args])
    p_score.add_argument("--state", required=True)
    p_score.add_argument("--question", required=True)
    p_score.add_argument("--level", action="append", required=True, dest="levels")
    p_score.add_argument("--id", default="score")

    parser.add_argument("--payload", dest="legacy_payload", default=None, help="JSON file or - for stdin")
    args = parser.parse_args(argv)

    min_conf = args.min_confidence
    model = args.model or os.environ.get("TYPESAFE_DEFAULT_MODEL") or DEFAULT_MODEL
    why = getattr(args, "why", None)
    tag = getattr(args, "tag", None)

    if args.legacy_payload and not args.cmd:
        cmd = "payload"
        payload = _load_payload(args.legacy_payload)
        if args.model:
            payload["model"] = args.model
    elif args.cmd in {"payload", "raw"}:
        cmd = "payload"
        payload = _load_payload(args.path)
        if args.model:
            payload["model"] = args.model
    elif args.cmd == "choice":
        cmd = "choice"
        criteria = dict(_parse_option(item) for item in args.options)
        payload = {
            "state": args.state,
            "model": model,
            "questions": {
                args.id: {"type": "choice", "instructions": args.question, "criteria": criteria}
            },
        }
    elif args.cmd == "noul":
        cmd = "noul"
        q: dict[str, Any] = {"type": "noul", "instructions": args.question}
        if args.yes or args.no:
            q["criteria"] = {}
            if args.yes:
                q["criteria"]["true"] = args.yes
            if args.no:
                q["criteria"]["false"] = args.no
        payload = {"state": args.state, "model": model, "questions": {args.id: q}}
    elif args.cmd == "score":
        cmd = "score"
        payload = {
            "state": args.state,
            "model": model,
            "questions": {
                args.id: {
                    "type": "score",
                    "instructions": args.question,
                    "criteria": args.levels,
                }
            },
        }
    else:
        parser.print_help()
        return 1

    reason = disabled_reason()
    if reason:
        meta = payload.get("meta") if isinstance(payload.get("meta"), dict) else {}
        jevlog.record(
            cmd=cmd, request={k: v for k, v in payload.items() if k != "meta"}, response=None,
            verdicts=None, status="disabled", error=reason, min_confidence=min_conf, exit_code=2,
            why=why or meta.get("why"), tag=tag or meta.get("tag"),
        )
        json.dump({"disabled": True, "reason": reason}, sys.stdout)
        sys.stdout.write("\n")
        return 2

    response, call_id = call(payload, timeout=args.timeout, cmd=cmd, min_conf=min_conf, why=why, tag=tag)
    return _emit(response, min_conf, call_id)


if __name__ == "__main__":
    sys.exit(main())
