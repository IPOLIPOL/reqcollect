# reqcollect — Requirements Collector & Merge Tool

A minimal, offline-first pipeline for collecting requirements from
stakeholders and merging them into a central, versioned repository.

The main parts of design are:

1. **Schema** — a sexp file describing the thematic groups of a
   questionnaire (`purpose`, `functional`, `performance`, ...).
2. **Collector** — a single self-contained `.html` file that renders the
   form, validates input, and exports a submission in sexp format.
   No install, no server, no runtime dependencies, works offline.
3. **Merge tool** — an OCaml CLI that ingests one or more submission
   files, assigns internal IDs and human-readable display IDs, and
   writes a merged sexp file into the central repository.
4. **Renderer** — an OCaml CLI. Turns the merged file into a single
   self-contained HTML document with navigation, folding, and PDF/Word
   export.

Everything is stored as **s-expressions**. 
The repository is plain files, versionable with Git.
The whole toolchain is OCaml. JavaScript in the HTML bundles is a
`js_of_ocaml` build artifact, never hand-written.

## Flow

> Workflow overview: **<https://ipolipol.github.io/reqcollect/>**

```
        ┌──────────────────────────┐
        │ schemas/example.v1.sexp    │  the questionnaire definition
        └────────────┬─────────────┘
                     │
                     │  make collector
                     ▼
        ┌──────────────────────────┐
        │ dist/collector.html      │  single file, emailed / shared
        └────────────┬─────────────┘
                     │           
                     │  user fills form
                     ▼
        ┌──────────────────────────┐
        │ submission.sexp          │  no per-req IDs, no schema copy
        └────────────┬─────────────┘
                     │ 
                     │  dropped into submissions/ ,make merge
                     ▼
        ┌──────────────────────────┐
        │ repo/merged.sexp         │  IDs assigned, headers copied
        └────────────┬─────────────┘
                     │
                     │  make render 
                     ▼
        ┌──────────────────────────┐
        │ repo/merged.html         │  TOC + tree nav + print/Word
        └──────────────────────────┘
```

## Status

Working end to end.

- [x] Schema → collector → export → merge round-trip
- [x] Free-text input, no forced parameter registry
- [x] Header fields (author, system name, RDS, RDS-PP) — filled once,
      copied into every requirement at merge time
- [x] IDs assigned at merge time, never in the collector
- [x] Merged HTML view: sidebar tree, fold/unfold, go-to-top,
      PDF (via print) and Word export
- [ ] Idempotent re-import (dedup by author + group + text)
- [ ] Schema-driven validation (required fields, known groups)
- [ ] Configurable batch identity (currently `batch-001` hardcoded)

## Requirements

- OCaml ≥ 4.14
- Dune ≥ 3.0
- `opam install dune sexplib cmdliner js_of_ocaml js_of_ocaml-ppx`

## Layout
```
reqcollect/
├── dune-project
├── Makefile
├── lib/                         core library (pure OCaml)
│   ├── sexp_util.ml             parsing helpers
│   ├── schema.ml                questionnaire schema
│   ├── submission.ml            one collector export
│   ├── merge.ml                 merge + ID assignment
│   └── render_html.ml           merged.sexp -> merged.html
├── bin/
│   └── main.ml                  CLI: merge, render
├── web/
│   ├── main.ml                  collector (compiled to JS)
│   ├── template.html            collector shell
│   └── merged_template.html     merged-view shell
├── schemas/
│   └── example.v1.sexp          example schema
├── submissions/                 incoming collector exports
├── repo/                        merged.sexp, merged.html
└── dist/                        generated collector.html
```

### Renaming the placeholder

The schema ships with the id `example` and the filename
`schemas/example.v1.sexp`. This is a placeholder — pick any name for
your project and use it consistently:

1. Rename `schemas/example.v1.sexp` to `schemas/<your-name>.v1.sexp`.
2. Inside it, set `(id <your-name>)` and `(name "...")`.
3. Update the `SUBMISSIONS`/schema path in the `Makefile` if you named
   it differently.
4. Update `web/dune` to point to the right schema file.
5. Rebuild: `make clean && make collector`.

The collector reads `schema-id` and `schema-version` from the schema
file itself, so nothing else needs to know the name.

## Build
```sh
make            # dune build
make collector  # -> dist/collector.html
make merge      # -> repo/merged.sexp  (merges submissions/*.sexp)
make render     # -> repo/merged.html
make clean
```

## Data format

All artifacts use the same sexp syntax.

**Schema** — describes header fields, groups, and requirement fields:
```lisp
(schema
 (id example)
 (name "Requirements sheet")
 (version 0.1.0)
 (header-field (id author)      (name "Author")      (required true))
 (header-field (id system-name) (name "System name") (required true))
 (header-field (id rds)         (name "RDS")         (required false))
 (header-field (id rds-pp)      (name "RDS-PP")      (required false))
 (group (id purpose) (name "Purpose of the system") (order 1))
 ...
 (field (id text)   (name "Requirement") (data-type text) (required true))
 ...)
```

**Submission** — what the collector emits:
```lisp
(submission
 (schema-id example)
 (schema-version 0.1.0)
 (created-at "2026-01-15T09:14:22Z")
 (headers
  (author "alice@example.com")
  (system-name "Main crane")
  (rds "RDS-001")
  (rds-pp "RDS-PP-001"))
 (requirements
  (requirement
   (group performance)
   (text "The crane must lift the transformer, mass 8 t.")
   (source "Contract-2026-014")
   (note ""))
  ...))
```

**Merged** — output of `make merge`:
```lisp
(merged
 (batch-id batch-001)
 (schema-id example)
 (schema-version 0.1.0)
 (count 5)
 (requirements
  (requirement
   (id batch-001-0001)
   (display-id REQ-PERF-0001)
   (group performance)
   (text "The crane must lift the transformer, mass 8 t.")
   (source "Contract-2026-014")
   (note "")
   (headers
    ((author "alice@example.com")
     (system-name "Main crane")
     (rds "RDS-001")
     (rds-pp "RDS-PP-001"))))
  ...))
```

## Using the collector

1. `make collector`
2. Open `dist/collector.html`.
3. Fill in headers (author, system name, RDS, RDS-PP) once.
4. Fill in requirements section by section; add rows as needed.
5. Click **Export .sexp** — a `submission.sexp` file downloads.
6. Drop it into `submissions/` and run `make merge && make render`.

## Viewing the merged result

Open `repo/merged.html`. The sidebar tree lists systems and their
groups; click any entry to jump. Systems fold and unfold. Requirements
are grouped by system, then by group, each as a card with its metadata.

- **Export PDF** — opens the browser print dialog; choose *Save as PDF*.
- **Export Word** — downloads a `.doc` file that Word or LibreOffice
  opens natively.

Print styling hides the sidebar and buttons, and starts each system on
a fresh page.

## Design notes

**Why sexp** S-expressions are trivially canonical (one
spelling per tree), trivially safely readable without `eval`, diffable
in Git, and natively supported in OCaml via `sexplib0`. 

**Why IDs are assigned at merge.** The collector runs offline, in
isolation. Two collectors cannot coordinate unique identifiers. The
collector therefore emits requirements with no per-requirement IDs.
Merge assigns:

- `id` — internal, deterministic from batch + ordinal.
- `display-id` — human-readable, `REQ-<GROUP>-<NNNN>`.
- Headers are copied verbatim into every requirement, so a requirement
  is self-describing wherever it lands.

**Why header fields are schema-driven.** Adding a new field
(department, project code, revision) requires editing **one** file —
the schema — and rebuilding. Neither the collector nor the merge tool
has any knowledge of specific header names.

**Why free text for now.** The schema imposes almost no structure
beyond "which group does this requirement belong to". Deliberate: it
lets the concept be tested end to end before deciding what structure
is worth enforcing. A parameter registry, typed values, and cross-field
constraints are natural next steps *once the shape of real submissions
is known* — not before.

**Why OCaml for the whole toolchain.** The merge and render steps are
pure data transformation with a thin IO edge, which suits a functional
language. The collector compiles OCaml to JavaScript via
`js_of_ocaml`, so the browser-side logic is the same codebase, not a
parallel implementation.

**Why one HTML file per view.** The collector is emailed or shared as
a single file with no install. The merged view is a single file that
opens from disk, prints cleanly, and needs no server. Both are just
`<style>` + `<script>` + content inlined into a template.

## License

reqcollect is open source and released under the MIT License. This license allows you to freely use, modify, and distribute the software for both personal and commercial purposes. While the MIT License permits anyone to fork or reimplement the project, the core idea, user experience, and design of reqcollect are the result of careful thought and iteration. We kindly ask that if you build upon this project, you:
- Give appropriate credit to the original work
- Consider contributing any improvements back to the community
If you're looking for additional features (custom branding, password protection, advanced customization, etc.), commercial licensing, or support, feel free to reach out.

© 2026 IPOLIPOL. All rights reserved. reqcollect is a trademark of IPOLIPOL.
