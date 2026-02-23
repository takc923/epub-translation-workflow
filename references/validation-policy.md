# Validation Diff Policy

## Why Diff-Based Validation

Some source EPUB files already contain validation issues.
Comparing translated EPUB against source EPUB avoids false-positive rework.

## Required Validation Sequence

1. Run `epubcheck` on original EPUB.
2. Run `epubcheck` on translated EPUB.
3. Normalize and compare error entries.
4. Extract generated-only errors.
5. Fix generated-only errors.
6. Repeat until generated-only error count is zero.

## Baseline Handling

- Errors present in original EPUB are baseline errors.
- Baseline errors are not translation regressions.
- Only generated-only errors block completion.

## Typical Generated-Only Failures

- `RSC-012` from missing fragment anchors after translation edits
- wrong pagebreak ID loss (`page_*`)
- broken in-file references after partial rewrites

## Completion Criteria

- generated-only errors: `0`
- package build checks pass (`mimetype` first and stored)
- no temporary translation artifacts included in output (`*.bak_codex`)
