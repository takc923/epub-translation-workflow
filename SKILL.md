---
name: epub-translation-workflow
description: Translate or localize EPUB files into a target language while preserving XHTML structure, validating with epubcheck diff against the original, and safely rebuilding outputs with atomic replace and rollback-on-failure. Use when asked to translate an EPUB, repair generated-only EPUB validation errors, or run repeatable EPUB localization workflow steps.
---

# EPUB Translation Workflow

## Overview

Use this skill to run a repeatable EPUB localization workflow with low rework risk.
Always preserve XHTML structure, validate generated EPUB against the original EPUB, and avoid leaving scattered backup files in the workspace root.

## Inputs

Collect and confirm these inputs before execution:

- `input_epub`: source EPUB path
- `output_epub`: translated EPUB path
- `target_language`: language code or language label (default: `ja`)
- `scope`: `core` or `all`
- `keep_failure_backup`: `true` or `false` (default: `true`)

## Approval Minimization

To reduce approval prompts and keep execution smooth:

- Keep all temporary work under workspace-local `tmp/run-<timestamp>/`.
- Avoid writing to system directories or global tool locations during normal runs.
- Prefer already-installed `epubcheck`; if missing, pause and ask before installing.
- Keep rollback artifacts under `tmp/run-*/rollback/` only.
- Do not create root-level `*.bak-*` files in normal success flow.

## Workflow Decision

Use this flow:

1. Create run workspace under `tmp/run-<timestamp>/`.
2. Unpack EPUB into `tmp/run-<timestamp>/unpacked/`.
3. Define translation targets according to scope.
4. Translate with structure-safe edits only.
5. Run per-chunk quality gates.
6. Rebuild EPUB with atomic replacement.
7. Compare `epubcheck` results between original and generated EPUB.
8. Fix generated-only errors and rerun validation until diff is clean.
9. Cleanup run directory according to success/failure policy.

## Progress Tracking

Maintain `todo.md` as a live progress board for resumability:

- `Current phase`
- `Chapter progress: <done>/<total>`
- `Current chapter`
- `Last updated`
- Phase and chapter checklists (`[ ]` / `[x]`)

Update `todo.md` at:

- chapter start
- chapter completion
- phase transition

## Scope Rules

Use `core` scope by default:

- Translate: `ch*.xhtml`, `fm.xhtml`, `toc.xhtml`, `nav.xhtml`, `pref01-04.xhtml`, `appendix.xhtml`.
- Translate descriptive text only in `references.xhtml`.
- Keep bibliographic records unchanged in `references.xhtml`.
- Keep `index.xhtml` unchanged unless user explicitly asks to translate index entries.

Use `all` scope only when user explicitly requests full translation.

## Translation Rules

Read `references/translation-rules.md` before editing content.

Hard constraints:

- Translate text nodes only.
- Do not change XHTML tags, attributes, `id`, `class`, `href`, `epub:type`, numbers, or anchor IDs.
- Preserve pagebreak anchors like `id="page_..."`.
- Preserve cross-references and link targets.

Style and terminology constraints:

- Translation style must be natural and accurate in the target language.
- Technical terms must include the original source text at first occurrence only (for example: `<translated term> (<source term>)`).
- Build glossary early, then keep updating it during chapter translation.

## Worker Execution Strategy

Use this strategy to reduce delays and avoid rework:

1. Start with `1 chapter = 1 worker`.
2. Do not launch all chapters at once on the first pass.
3. Use a longer initial wait window to avoid interrupting before write-back.
4. If a worker stalls, split only that chapter into fixed ranges (for example: `1-120`, `121-260`, `261+`).
5. Confirm progress with these three checks:
- file modification time changed
- first translated lines actually updated
- `xmllint --noout` passes

## Interruption and Recovery Rules

When interruption happens:

1. Collect explicit completion state from worker (`completed` / `not completed`, and exact range).
2. Reassign only unfinished ranges.
3. Keep ranges fixed to avoid overlapping edits.
4. Exclude temporary artifacts such as `*.bak_codex` from final packaging.

## Quality Gates Per Chunk

After each translated chunk, run all gates:

1. XML syntax gate:
- `xmllint --noout <file>`
2. Anchor gate:
- verify critical anchors (`page_*`, section ids referenced by nav/index/toc)
3. Residual English gate:
- prioritize detection of lines with no target-language characters (not total English count)

Important: Missing pagebreak IDs often creates `RSC-012` errors.

## EPUB Validation Diff Policy

Read `references/validation-policy.md` before final acceptance.

Validation policy:

1. Run `epubcheck` on original EPUB.
2. Run `epubcheck` on generated EPUB.
3. Compare errors and extract generated-only errors.
4. Fix only generated-only errors.
5. Treat original-only errors as known baseline issues.
6. Final acceptance requires generated-only error count = `0`.

## Safe Build and Replace Policy

Never replace output directly.

- Build to `*.tmp` first.
- Replace output atomically (`mv`) only after successful build.
- Keep rollback copy only inside `tmp/run-<timestamp>/rollback/`.
- Remove rollback on success.
- Keep one rollback generation only on failure when `keep_failure_backup=true`.
- Do not leave `*.bak-*` in workspace root during normal success path.

## Scripts

Use these scripts from `scripts/`:

1. `scripts/check_epub.sh`
- Runs epubcheck on original and translated EPUB.
- Writes JSON report including generated-only errors.

2. `scripts/repackage_epub.sh`
- Rebuilds EPUB from `run-dir/unpacked`.
- Forces `mimetype` first and stored.
- Excludes `*.bak_codex` by default.
- Uses atomic replacement and run-local rollback.

3. `scripts/cleanup_run.sh`
- Success: removes run directory.
- Failure: keeps one rollback generation only if requested.

## Recommended Git Workflow

When Git is available:

1. Commit skill files independently from EPUB outputs.
2. Keep script changes and SKILL/reference changes in the same commit.
3. Use separate commits for workflow policy updates and tool behavior updates.

## Acceptance Checklist

Accept only when all items pass:

- `SKILL.md` includes workflow, worker strategy, interruption recovery, quality gates, validation diff policy, and safe replace policy.
- `scripts/check_epub.sh`, `scripts/repackage_epub.sh`, and `scripts/cleanup_run.sh` exist and run.
- `quick_validate.py` passes.
- On sample run, generated-only epubcheck errors are extracted correctly.
- Success path leaves no scattered `*.bak-*` in workspace root.
