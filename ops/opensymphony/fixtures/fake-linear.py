#!/usr/bin/env python3
"""Fixture-only Linear GraphQL boundary for contained OpenSymphony acceptance."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import re


FIXTURE_ISSUE_ID = "fixture-issue-901"
FIXTURE_ISSUE_IDENTIFIER = "FIX-901"
FIXTURE_MODE = os.environ.get("FIXTURE_LINEAR_MODE", "active")
if FIXTURE_MODE not in {"active", "terminal"}:
    raise SystemExit("FIXTURE_LINEAR_MODE must be active or terminal")


def fixture_state() -> dict:
    if FIXTURE_MODE == "terminal":
        return {"id": "fixture-state-done", "name": "Done", "type": "completed"}
    return {"id": "fixture-state-started", "name": "In Progress", "type": "started"}


def fixture_updated_at() -> str:
    if FIXTURE_MODE == "terminal":
        return "2026-07-23T00:01:00Z"
    return "2026-07-23T00:00:00Z"


def issue_node() -> dict:
    return {
        "id": FIXTURE_ISSUE_ID,
        "identifier": FIXTURE_ISSUE_IDENTIFIER,
        "url": "https://linear.example.invalid/issue/FIX-901",
        "title": "Contained no-model route fixture",
        "description": "Proves routing without a model or live tracker.",
        "priority": 1.0,
        "branchName": None,
        "createdAt": "2026-07-23T00:00:00Z",
        "updatedAt": fixture_updated_at(),
        "state": fixture_state(),
        "project": None,
        "parent": None,
        "projectMilestone": None,
        "attachments": {"nodes": []},
        "children": {"nodes": []},
        "labels": {"nodes": [], "pageInfo": {"hasNextPage": False, "endCursor": None}},
        "inverseRelations": {
            "nodes": [],
            "pageInfo": {"hasNextPage": False, "endCursor": None},
        },
    }


def issue_summary_node() -> dict:
    return {
        "id": FIXTURE_ISSUE_ID,
        "identifier": FIXTURE_ISSUE_IDENTIFIER,
        "url": "https://linear.example.invalid/issue/FIX-901",
        "title": "Contained no-model route fixture",
        "priority": 1.0,
        "createdAt": "2026-07-23T00:00:00Z",
        "updatedAt": fixture_updated_at(),
        "state": fixture_state(),
        "children": {"nodes": []},
        "inverseRelations": {
            "nodes": [],
            "pageInfo": {"hasNextPage": False, "endCursor": None},
        },
    }


def issue_state_node() -> dict:
    return {
        "id": FIXTURE_ISSUE_ID,
        "identifier": FIXTURE_ISSUE_IDENTIFIER,
        "updatedAt": fixture_updated_at(),
        "state": fixture_state(),
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "OpenSymphonyFixtureLinear/1"

    def log_message(self, _format: str, *_args: object) -> None:
        return

    def do_GET(self) -> None:
        if self.path != "/health":
            self.respond(404, {"errors": [{"message": "unknown fixture path"}]})
            return
        self.respond(200, {"status": "ok"})

    def do_POST(self) -> None:
        if self.path != "/graphql":
            self.respond(404, {"errors": [{"message": "unknown fixture path"}]})
            return
        if self.headers.get("authorization") != "fixture-key":
            self.respond(401, {"errors": [{"message": "fixture authorization required"}]})
            return
        length = int(self.headers.get("content-length", "0"))
        try:
            body = json.loads(self.rfile.read(length))
        except (json.JSONDecodeError, UnicodeDecodeError):
            self.respond(400, {"errors": [{"message": "invalid fixture request"}]})
            return

        if not isinstance(body, dict):
            self.respond(400, {"errors": [{"message": "fixture request must be an object"}]})
            return
        query = body.get("query")
        mutation = isinstance(query, str) and bool(
            re.search(r"(?<![_A-Za-z0-9])mutation(?![_A-Za-z0-9])", query, re.IGNORECASE)
        )
        operation = "unknown"
        if isinstance(query, str):
            operation_match = re.match(r"\s*(?:query|mutation)\s+([_A-Za-z][_0-9A-Za-z]*)", query)
            if operation_match:
                operation = operation_match.group(1)
        self.record(operation, mutation)

        if mutation:
            self.respond(409, {"errors": [{"message": "fixture rejects tracker mutation"}]})
            return
        if not isinstance(query, str) or operation not in {
            "IssuesByState",
            "IssueSummariesByState",
            "IssueStatesByIds",
        }:
            self.respond(422, {"errors": [{"message": "fixture rejects unknown operation"}]})
            return

        variables = body.get("variables")
        if not isinstance(variables, dict):
            variables = {}
        if operation == "IssueStatesByIds":
            issue_ids = variables.get("issueIds", [])
            nodes = (
                [issue_state_node()]
                if isinstance(issue_ids, list) and FIXTURE_ISSUE_ID in issue_ids
                else []
            )
        else:
            states = variables.get("stateNames", [])
            expected_state = fixture_state()["name"]
            response_node = (
                issue_summary_node() if operation == "IssueSummariesByState" else issue_node()
            )
            nodes = (
                [response_node]
                if isinstance(states, list) and expected_state in states
                else []
            )
        self.respond(
            200,
            {
                "data": {
                    "issues": {
                        "nodes": nodes,
                        "pageInfo": {"hasNextPage": False, "endCursor": None},
                    }
                }
            },
        )

    def record(self, operation: str, mutation: bool) -> None:
        path = os.environ.get("FIXTURE_LINEAR_AUDIT_LOG")
        if not path:
            return
        with open(path, "a", encoding="utf-8") as audit:
            audit.write(json.dumps({"operation": operation, "mutation": mutation}) + "\n")

    def respond(self, status: int, body: dict) -> None:
        encoded = json.dumps(body, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)


if __name__ == "__main__":
    port = int(os.environ.get("FIXTURE_LINEAR_PORT", "8080"))
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
