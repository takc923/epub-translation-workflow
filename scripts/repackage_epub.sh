#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 --run-dir <tmp/run-id> --output <translated.epub> [--failure-backup <on|off>]

Expected unpacked source directory:
  <run-dir>/unpacked
USAGE
}

RUN_DIR=""
OUTPUT=""
FAILURE_BACKUP="on"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir)
      RUN_DIR="$2"; shift 2 ;;
    --output)
      OUTPUT="$2"; shift 2 ;;
    --failure-backup)
      FAILURE_BACKUP="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2 ;;
  esac
done

if [[ -z "$RUN_DIR" || -z "$OUTPUT" ]]; then
  usage
  exit 2
fi

if [[ "$FAILURE_BACKUP" != "on" && "$FAILURE_BACKUP" != "off" ]]; then
  echo "--failure-backup must be on or off" >&2
  exit 2
fi

SOURCE_DIR="$RUN_DIR/unpacked"
if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Unpacked source directory not found: $SOURCE_DIR" >&2
  exit 2
fi

if [[ ! -f "$SOURCE_DIR/mimetype" ]]; then
  echo "mimetype not found in $SOURCE_DIR" >&2
  exit 2
fi

mkdir -p "$(dirname "$OUTPUT")"
ROLLBACK_DIR="$RUN_DIR/rollback"

if [[ -f "$OUTPUT" && "$FAILURE_BACKUP" == "on" ]]; then
  mkdir -p "$ROLLBACK_DIR"
  TS="$(date '+%Y%m%d-%H%M%S')"
  cp "$OUTPUT" "$ROLLBACK_DIR/$(basename "$OUTPUT").bak-$TS"
fi

TMP_OUTPUT="$OUTPUT.tmp"
rm -f "$TMP_OUTPUT"

(
  cd "$SOURCE_DIR"
  zip -X0 "$TMP_OUTPUT" mimetype
  zip -Xr9 "$TMP_OUTPUT" * -x mimetype -x "*.bak_codex"
)

mv "$TMP_OUTPUT" "$OUTPUT"

# Verify packaging rule: first entry must be uncompressed mimetype
python3 - "$OUTPUT" <<'PY'
import sys
import zipfile

epub_path = sys.argv[1]
with zipfile.ZipFile(epub_path, "r") as zf:
    infos = zf.infolist()
    if not infos:
        raise SystemExit("Packaging rule violation: archive is empty")
    first = infos[0]
    if first.filename != "mimetype":
        raise SystemExit(
            f"Packaging rule violation: first entry must be 'mimetype', got '{first.filename}'"
        )
    if first.compress_type != zipfile.ZIP_STORED:
        raise SystemExit(
            "Packaging rule violation: 'mimetype' must be stored without compression"
        )
PY

echo "Repackaged EPUB: $OUTPUT"
