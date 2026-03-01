#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 --original <original.epub> --translated <translated.epub> --report <report.json> --allowed-file <path> [--allowed-file <path> ...]
USAGE
}

ORIGINAL=""
TRANSLATED=""
REPORT=""
declare -a ALLOWED_FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --original)
      ORIGINAL="$2"; shift 2 ;;
    --translated)
      TRANSLATED="$2"; shift 2 ;;
    --report)
      REPORT="$2"; shift 2 ;;
    --allowed-file)
      ALLOWED_FILES+=("$2"); shift 2 ;;
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

if [[ "${#ALLOWED_FILES[@]}" -eq 0 ]]; then
  echo "At least one --allowed-file is required" >&2
  exit 2
fi

mkdir -p "$(dirname "$REPORT")"

python3 - "$ORIGINAL" "$TRANSLATED" "$REPORT" "${ALLOWED_FILES[@]}" <<'PY'
import json
import sys
import zipfile
from pathlib import Path

original_epub = Path(sys.argv[1])
translated_epub = Path(sys.argv[2])
report_path = Path(sys.argv[3])
allowed_inputs = sys.argv[4:]


def normalize_allowed(path: str) -> str:
    if path.startswith("OEBPS/xhtml/"):
        return path
    return f"OEBPS/xhtml/{path}"


allowed_files = sorted({normalize_allowed(p) for p in allowed_inputs})

prefix = "OEBPS/xhtml/"

with zipfile.ZipFile(original_epub, "r") as oz, zipfile.ZipFile(translated_epub, "r") as tz:
    orig_names = {name for name in oz.namelist() if name.startswith(prefix) and name.endswith(".xhtml")}
    tran_names = {name for name in tz.namelist() if name.startswith(prefix) and name.endswith(".xhtml")}

    all_names = sorted(orig_names | tran_names)
    changed_files = []
    for name in all_names:
        orig_data = oz.read(name) if name in orig_names else None
        tran_data = tz.read(name) if name in tran_names else None
        if orig_data != tran_data:
            changed_files.append(name)

unexpected_changed_files = [name for name in changed_files if name not in allowed_files]

report = {
    "original_epub": str(original_epub),
    "translated_epub": str(translated_epub),
    "allowed_files": allowed_files,
    "changed_files": changed_files,
    "unexpected_changed_files": unexpected_changed_files,
    "passes_allowed_change_gate": len(unexpected_changed_files) == 0,
}

report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(
    json.dumps(
        {
            "changed_files_count": len(changed_files),
            "unexpected_changed_files_count": len(unexpected_changed_files),
            "passes_allowed_change_gate": report["passes_allowed_change_gate"],
            "report": str(report_path),
        },
        ensure_ascii=False,
    )
)

if unexpected_changed_files:
    raise SystemExit(1)
PY
