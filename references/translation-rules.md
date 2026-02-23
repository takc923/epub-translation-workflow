# Translation Rules

## Goal

Translate EPUB content into a target language while keeping package structure and linking intact.

## Non-Negotiable Constraints

- Translate text nodes only.
- Keep all tags and attributes unchanged.
- Keep these unchanged:
- `id`
- `class`
- `href`
- `epub:type`
- pagebreak anchors (`id="page_..."`)
- numeric references

## Content Policy

- Default target language is configurable (`target_language`, default `ja`).
- Keep proper nouns, standards, and citations in source language unless user requests otherwise.
- Keep bibliographic entries in `references.xhtml` unchanged unless explicitly requested.
- For terminology, use project glossary and normalize wording chapter-by-chapter.

## Scope Policy

- Default scope: `core`.
- Translate all: `ch*.xhtml`, `fm.xhtml`, `toc.xhtml`, `nav.xhtml`, `pref01-04.xhtml`, `appendix.xhtml`.
- Translate descriptive text only in `references.xhtml`.
- Keep `index.xhtml` unchanged unless user requests index translation.

## Chunking Guidance

- Prefer chapter-level work first.
- Split only stalled chapters into fixed ranges.
- Never overlap assigned ranges.

## Required Per-Chunk Checks

- `xmllint --noout <file>`
- verify anchor IDs referenced by nav/toc/index
- run residual English detection gate
