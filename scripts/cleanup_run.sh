#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 --run-dir <tmp/run-id> --status <success|failure> [--keep-on-failure <true|false>]
USAGE
}

RUN_DIR=""
STATUS=""
KEEP_ON_FAILURE="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir)
      RUN_DIR="$2"; shift 2 ;;
    --status)
      STATUS="$2"; shift 2 ;;
    --keep-on-failure)
      KEEP_ON_FAILURE="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2 ;;
  esac
done

if [[ -z "$RUN_DIR" || -z "$STATUS" ]]; then
  usage
  exit 2
fi

if [[ "$STATUS" != "success" && "$STATUS" != "failure" ]]; then
  echo "--status must be success or failure" >&2
  exit 2
fi

if [[ "$KEEP_ON_FAILURE" != "true" && "$KEEP_ON_FAILURE" != "false" ]]; then
  echo "--keep-on-failure must be true or false" >&2
  exit 2
fi

if [[ ! -d "$RUN_DIR" ]]; then
  echo "Run directory not found: $RUN_DIR"
  exit 0
fi

if [[ "$STATUS" == "success" ]]; then
  rm -rf "$RUN_DIR"
  echo "Cleanup done (success): removed $RUN_DIR"
  exit 0
fi

# failure path
if [[ "$KEEP_ON_FAILURE" == "false" ]]; then
  rm -rf "$RUN_DIR"
  echo "Cleanup done (failure, keep disabled): removed $RUN_DIR"
  exit 0
fi

ROLLBACK_DIR="$RUN_DIR/rollback"
if [[ -d "$ROLLBACK_DIR" ]]; then
  python3 - "$ROLLBACK_DIR" <<'PY'
import os
import sys
from pathlib import Path

rollback = Path(sys.argv[1])
files = [p for p in rollback.iterdir() if p.is_file()]
files.sort(key=lambda p: p.stat().st_mtime, reverse=True)
for stale in files[1:]:
    stale.unlink(missing_ok=True)
PY
fi

echo "Cleanup done (failure, keep enabled): kept $RUN_DIR with single rollback generation"
