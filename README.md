# reqcollect — Requirements Collector & Merge Tool

A minimal, offline-first pipeline for collecting requirements from
stakeholders and merging them into a central repository.

The design has three parts:

1. **Schema** — a sexp file describing the thematic groups of a
   questionnaire (`purpose`, `functional`, `performance`, ...).
2. **Collector** — a single self-contained `.html` file that renders the
   form, validates input, and exports a submission in sexp format.
   No install, no server, works offline.
3. **Merge tool** — an OCaml CLI that ingests one or more submission
   files, assigns internal IDs and human-readable display IDs, and
   writes a merged sexp file into the central repository.

Everything is stored as **s-expressions**. No JSON, no database. The
repository is plain files, versionable with Git.

## Status

Early prototype. The pipeline works end to end:

- [x] Schema → collector → export → merge round-trip
- [x] Free-text input, no forced parameter registry
- [x] IDs assigned at merge time, never in the collector
- [ ] Idempotent re-import (dedup by author + group + text)
- [ ] Schema-driven validation (required fields, known groups)
- [ ] Batch identity (currently `batch-001` hardcoded)

## Requirements

- OCaml ≥ 4.14
- Dune ≥ 3.0
- `opam install dune sexplib cmdliner js_of_ocaml js_of_ocaml-ppx`

## Layout

```
reqcollect/
├── dune-project
├── Makefile
├── lib/                    core library (pure OCaml)
│   ├── sexp_util.ml        parsing helpers
│   ├── schema.ml           questionnaire schema
│   ├── submission.ml       one collector export
│   └── merge.ml            merge logic + ID assignment
├── bin/
│   └── main.ml             CLI entry point
├── web/                    js_of_ocaml collector
│   ├── main.ml
│   └── dune                includes schema_data.ml rule
├── web/template.html       HTML shell with __INJECT_JS__ placeholder
├── schemas/
│   └── crane.v1.sexp       example schema
├── submissions/            incoming collector exports
├── repo/                   merged output
└── dist/                   generated collector.html
```

## Build

```sh
make            # dune build
make collector  # produces dist/collector.html
make merge      # merges submissions/*.sexp into repo/merged.sexp
make clean
```

## Using the collector

1. `make collector`
2. Open `dist/collector.html` in any browser.
3. Fill in the form; the schema's groups become sections.
4. Click **Export .sexp** — a `submission.sexp` file is downloaded.
5. Drop it into `submissions/` and run `make merge`.

The collector is a single file. It can be emailed, put on a USB stick,
or served from any static host. No runtime dependencies.

## Data format

All three artifacts — schema, submission, merged output — use the same
sexp syntax.

**Schema** (`schemas/crane.v1.sexp`):

```lisp
(schema
 (id crane)
 (name "Overhead Crane Requirements")
 (version 0.1.0)
 (group (id purpose) (name "Purpose of the system") (order 1))
 ...
 (field (id text) (name "Requirement") (data-type text) (required true))
 ...)
```

**Submission** (produced by the collector):

```lisp
(submission
 (schema-id crane)
 (schema-version 0.1.0)
 (created-at "2026-01-15T09:14:22Z")
 (author "alice@example.com")
 (requirements
  (requirement
   (group performance)
   (text "The crane must lift the transformer, mass 8 t.")
   (source "Contract-2026-014")
   (note ""))
  ...))
```

**Merged** (produced by `make merge`):

```lisp
(merged
 (batch-id batch-001)
 (count 5)
 (requirements
  (requirement
   (id batch-001-0001)
   (display-id REQ-PERF-0001)
   (group performance)
   (text "The crane must lift the transformer, mass 8 t.")
   (source "Contract-2026-014")
   (note "")
   (author "alice@example.com"))
  ...))
```

## Design notes

**Why sexp, not JSON.** S-expressions are trivially canonical (one
spelling per tree), trivially safely readable without `eval`, diffable
in Git, and natively supported in OCaml via `sexplib0`. JSON buys
nothing here and adds a second format to maintain.

**Why IDs are assigned at merge.** The collector runs offline, in
isolation. Two collectors cannot coordinate to produce unique
identifiers. So per-requirement IDs are the merge tool's job; the
collector emits requirements with no IDs at all. Merge assigns:

- `id` — internal, deterministic from batch + ordinal.
- `display-id` — human-readable, `REQ-<GROUP>-<NNNN>`.
- `author` — copied from the submission.

**Why free text for now.** The schema currently imposes almost no
structure beyond "which group does this requirement belong to". This
is deliberate: it lets the concept be tested end to end before deciding
what structure is worth enforcing. A parameter registry, typed values,
and cross-field constraints are natural next steps *once the shape of
real submissions is known* — not before.

**Why OCaml.** The merge tool is pure data transformation with a thin
IO edge, which suits a functional language. The collector compiles
OCaml to JavaScript via `js_of_ocaml`, so the JS in the HTML bundle is
a build artifact, never hand-written.

## License

see [LICENSE](LICENSE)