#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 --file <translated.xhtml> --report <report.json> [--extra-allow-patterns <patterns.txt>]
USAGE
}

TARGET_FILE=""
REPORT=""
EXTRA_ALLOW_PATTERNS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      TARGET_FILE="$2"; shift 2 ;;
    --report)
      REPORT="$2"; shift 2 ;;
    --extra-allow-patterns)
      EXTRA_ALLOW_PATTERNS="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2 ;;
  esac
done

if [[ -z "$TARGET_FILE" || -z "$REPORT" ]]; then
  usage
  exit 2
fi

if [[ ! -f "$TARGET_FILE" ]]; then
  echo "Target file not found: $TARGET_FILE" >&2
  exit 2
fi

if [[ -n "$EXTRA_ALLOW_PATTERNS" && ! -f "$EXTRA_ALLOW_PATTERNS" ]]; then
  echo "Extra allow patterns file not found: $EXTRA_ALLOW_PATTERNS" >&2
  exit 2
fi

mkdir -p "$(dirname "$REPORT")"

python3 - "$TARGET_FILE" "$REPORT" "$EXTRA_ALLOW_PATTERNS" <<'PY'
import json
import re
import sys
from pathlib import Path

target_file = Path(sys.argv[1])
report_path = Path(sys.argv[2])
extra_patterns_path = Path(sys.argv[3]) if sys.argv[3] else None

url_re = re.compile(r"https?://\S+|www\.\S+")
domain_re = re.compile(r"\b[a-z0-9.-]+\.(com|org|net|edu|gov|io|co|jp)\b", re.IGNORECASE)
email_re = re.compile(r"\b[\w.+-]+@[\w.-]+\.[a-z]{2,}\b", re.IGNORECASE)
acronym_re = re.compile(r"\b(IIBA|PMI|IREB|BABOK|EPUB|XML)\b")
jp_with_en_paren_re = re.compile(r"[ぁ-んァ-ヶ一-龠々ー].*[（(][A-Za-z][^）)]*[）)]")
bibliography_re = re.compile(
    r"\b(Edition|Press|Addison-Wesley|Microsoft Press|International Institute|Project Management Institute| by )\b",
    re.IGNORECASE,
)
alpha_re = re.compile(r"[A-Za-z]")

extra_patterns: list[re.Pattern[str]] = []
if extra_patterns_path:
    for raw in extra_patterns_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        extra_patterns.append(re.compile(line))


def classify(line: str) -> tuple[bool, str]:
    if any(pattern.search(line) for pattern in extra_patterns):
        return True, "extra_allow_pattern"
    if url_re.search(line):
        return True, "url"
    if email_re.search(line):
        return True, "email"
    if domain_re.search(line):
        return True, "domain"
    if bibliography_re.search(line):
        return True, "bibliography_or_citation"
    if acronym_re.search(line):
        return True, "approved_acronym"
    if jp_with_en_paren_re.search(line):
        return True, "jp_with_source_term_paren"
    return False, "unclassified_english"


allowed_lines: list[dict[str, object]] = []
suspicious_lines: list[dict[str, object]] = []

for idx, raw in enumerate(target_file.read_text(encoding="utf-8", errors="replace").splitlines(), start=1):
    if not alpha_re.search(raw):
        continue
    allowed, reason = classify(raw)
    item = {"line": idx, "reason": reason, "text": raw.strip()}
    if allowed:
        allowed_lines.append(item)
    else:
        suspicious_lines.append(item)

report = {
    "file": str(target_file),
    "allowed_count": len(allowed_lines),
    "suspicious_count": len(suspicious_lines),
    "allowed_lines": allowed_lines,
    "suspicious_lines": suspicious_lines,
    "passes_residual_english_gate": len(suspicious_lines) == 0,
}
report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(
    json.dumps(
        {
            "allowed_count": report["allowed_count"],
            "suspicious_count": report["suspicious_count"],
            "passes_residual_english_gate": report["passes_residual_english_gate"],
            "report": str(report_path),
        },
        ensure_ascii=False,
    )
)
if suspicious_lines:
    raise SystemExit(1)
PY
