---
description: Extract the 22-field hotspot schema (UC4) from one contract or a whole batch via extraction/extract.sh or extraction/parallel_extract.sh
argument-hint: [contract-file] | --batch [max-parallel-jobs]
allowed-tools: Bash(./extraction/extract.sh:*), Bash(extraction/extract.sh:*), Bash(./extraction/parallel_extract.sh:*), Bash(extraction/parallel_extract.sh:*), AskUserQuestion
---

You are running the UC4 hotspot extraction command. Your only job is to run the
correct extraction script and report where the output landed — you do not
extract fields yourself, and you never fabricate a value the scripts didn't
produce (see CLAUDE.md Legal Accuracy Rules).

## Arguments provided

$ARGUMENTS

## Step 1 — Decide single-file vs. batch

- If a single contract file path was provided (not `--batch`), this is a
  single-file extraction.
- If `--batch` was provided, this is a batch extraction over every `.txt`
  file in `extraction/input/`. An optional number after `--batch` sets max
  parallel jobs (default 4).
- If neither was provided, ask the user directly: "Extract one contract
  (give me the file path) or batch-extract everything in extraction/input/?"

## Step 2 — Validate before running

- Single-file: the path must exist and must not be a `.pdf`. If it's a
  `.pdf`, tell the user to run `contracts/chunker.sh` on it first (per
  CLAUDE.md's PDF Handling rule) and stop — do not attempt to read the PDF
  yourself.
- Batch: confirm `extraction/input/` exists and contains at least one `.txt`
  file before running; if not, tell the user and stop.

## Step 3 — Run the script

Single file:
```
./extraction/extract.sh <contract_file>
```
Writes `extraction/output/<contract_stem>_extracted.json`.

Batch:
```
./extraction/parallel_extract.sh <max_parallel_jobs>
```
Writes one `extraction/output/<stem>_extracted.json` per input file; a
per-file failure is logged to `extraction/output/.logs/<stem>.log` and does
not abort the rest of the batch.

## Step 4 — Report

- Single file: report the output path. If the result is
  `{"error": "no_text_layer", ...}`, tell the user this document has no
  text layer and needs OCR/manual review — do not treat it as a completed
  extraction.
- Batch: report the "N / M succeeded" summary the script prints, and list
  any failed stems with their log file path so the user can inspect them.
- If the script fails outright (missing `claude`/`jq` CLI, malformed JSON
  after fence-stripping, etc.), surface its exact stderr — do not retry
  silently or paper over the failure.
- Remind the user every non-null field in the output carries a citation and
  that ambiguous fields are `null` + flagged, never guessed (CLAUDE.md
  Legal Accuracy Rules 2–4).
