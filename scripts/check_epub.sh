#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 --original <original.epub> --translated <translated.epub> --report <report.json>
USAGE
}

ORIGINAL=""
TRANSLATED=""
REPORT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --original)
      ORIGINAL="$2"; shift 2 ;;
    --translated)
      TRANSLATED="$2"; shift 2 ;;
    --report)
      REPORT="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2 ;;
  esac
done

if [[ -z "$ORIGINAL" || -z "$TRANSLATED" || -z "$REPORT" ]]; then
  usage
  exit 2
fi

if [[ ! -f "$ORIGINAL" ]]; then
  echo "Original EPUB not found: $ORIGINAL" >&2
  exit 2
fi

if [[ ! -f "$TRANSLATED" ]]; then
  echo "Translated EPUB not found: $TRANSLATED" >&2
  exit 2
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/epubcheck-diff-XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

ORIG_LOG="$TMP_DIR/original.log"
TRAN_LOG="$TMP_DIR/translated.log"
mkdir -p "$(dirname "$REPORT")"

epubcheck "$ORIGINAL" >"$ORIG_LOG" 2>&1 || true
epubcheck "$TRANSLATED" >"$TRAN_LOG" 2>&1 || true

python3 - "$ORIG_LOG" "$TRAN_LOG" "$REPORT" "$(basename "$ORIGINAL")" "$(basename "$TRANSLATED")" <<'PY'
import json
import re
import sys
from pathlib import Path

orig_log = Path(sys.argv[1])
tran_log = Path(sys.argv[2])
report_path = Path(sys.argv[3])
orig_name = sys.argv[4]
tran_name = sys.argv[5]

err_re = re.compile(r"^ERROR\(([^)]+)\):\s*(.+)$")

def normalize_detail(detail: str) -> str:
    out = detail.replace(orig_name + "/", "<BOOK>/")
    out = out.replace(tran_name + "/", "<BOOK>/")
    return out

def parse_errors(path: Path):
    errors = []
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = err_re.match(raw.strip())
        if not m:
            continue
        code = m.group(1)
        detail = m.group(2)
        norm = normalize_detail(detail)
        key = f"{code}::{norm}"
        errors.append({"code": code, "detail": detail, "normalized": norm, "key": key})
    return errors

orig_errors = parse_errors(orig_log)
tran_errors = parse_errors(tran_log)

orig_keys = {e["key"] for e in orig_errors}
tran_keys = {e["key"] for e in tran_errors}

generated_only = [e for e in tran_errors if e["key"] not in orig_keys]
resolved_from_original = [e for e in orig_errors if e["key"] not in tran_keys]

report = {
    "original_epub": str(orig_name),
    "translated_epub": str(tran_name),
    "original_error_count": len(orig_errors),
    "translated_error_count": len(tran_errors),
    "generated_only_error_count": len(generated_only),
    "resolved_from_original_count": len(resolved_from_original),
    "generated_only_errors": [
        {"code": e["code"], "detail": e["detail"], "normalized": e["normalized"]}
        for e in generated_only
    ],
    "resolved_from_original_errors": [
        {"code": e["code"], "detail": e["detail"], "normalized": e["normalized"]}
        for e in resolved_from_original
    ],
    "passes_diff_policy": len(generated_only) == 0,
}

report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({
    "generated_only_error_count": report["generated_only_error_count"],
    "passes_diff_policy": report["passes_diff_policy"],
    "report": str(report_path),
}, ensure_ascii=False))
PY
