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
- Translation quality target is natural and accurate prose.
- Quoted text is also part of the translation target and must be translated unless the user explicitly requests source-only quotes.
- Technical terms must be translated. At first occurrence only, include the original source text (for example: `<translated term> (<source term>)`).
- Glossary operation timing is `create first, then update continuously`: create glossary v0 before full body translation, then update at least at each chapter completion.
- For terminology, use project glossary and normalize wording chapter-by-chapter.

## Scope Policy

- Default scope: `core`.
- Translate all: `ch*.xhtml`, `fm.xhtml`, `toc.xhtml`, `nav.xhtml`, `pref01-04.xhtml`, `appendix.xhtml`.
- Translate descriptive text only in `references.xhtml`.
- Keep `index.xhtml` unchanged unless user requests index translation.
- Do not add new scope values for chapter-only requests. Keep scope unchanged and define exact allowed target files operationally.
- For chapter-only requests, record allowed target files in `todo.md` and verify with allowed-change gate before final acceptance.

## Chunking Guidance

- Prefer chapter-level work first.
- Split only stalled chapters into fixed ranges.
- Never overlap assigned ranges.

## Required Per-Chunk Checks

- `xmllint --noout <file>`
- verify anchor IDs referenced by nav/toc/index
- run residual English detection gate with `allowed/suspicious` classification
- run allowed-change gate before final acceptance

## Residual English Gate Policy

Classify every English-bearing line into one of two categories:

- `allowed`: permitted English that does not block completion
- `suspicious`: possible untranslated content that blocks completion

Pass criteria:

- `suspicious_count = 0`

Default `allowed` categories:

- URL/domain/email entries
- bibliographic lines (book titles, author names, publisher strings, edition labels)
- approved acronyms and standards terms (`IIBA`, `PMI`, `IREB`, `BABOK`, `EPUB`, `XML`)
- first-occurrence source-term parentheses (`<translated term> (English)` or `<translated term> （English）`)

Default `suspicious` category:

- any other English-bearing line in translatable narrative content

Extra allow patterns:

- Optional file input can provide additional regex rules.
- Pattern file format: one regex per line; blank lines and lines starting with `#` are ignored.
- Keep this list minimal to avoid masking untranslated text.
