#!/usr/bin/env bash
# chunker.sh — split any PDF into 1-page text chunks with paragraph overlap.
#
# Usage: ./chunker.sh input.pdf [output_dir] [pages_per_chunk]
#
# Output: chunk_01.txt ... chunk_NN.txt in output_dir (default: ./chunks).
# Each chunk after the first starts with the last paragraph of the previous
# chunk, so no clause is lost at a page boundary.
#
# Requires: pdftotext + pdfinfo (poppler-utils).
# Optional: pdftoppm + tesseract (poppler-utils + Tesseract OCR) — if present,
# pages with no embedded text (scans, or vector-outline-only PDFs produced by
# some "print to PDF" paths) are rasterized and OCR'd instead of just flagged.

set -euo pipefail

# --- args ---------------------------------------------------------------
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 input.pdf [output_dir] [pages_per_chunk]" >&2
  exit 1
fi

PDF="$1"
OUT_DIR="${2:-chunks}"
PAGES_PER_CHUNK="${3:-1}"

[[ "$PAGES_PER_CHUNK" =~ ^[1-9][0-9]*$ ]] || { echo "Error: pages_per_chunk must be a positive integer" >&2; exit 1; }

[[ -f "$PDF" ]] || { echo "Error: file not found: $PDF" >&2; exit 1; }
command -v pdftotext >/dev/null || { echo "Error: pdftotext not installed (install poppler-utils)" >&2; exit 1; }
command -v pdfinfo   >/dev/null || { echo "Error: pdfinfo not installed (install poppler-utils)" >&2; exit 1; }

OCR_AVAILABLE=1
command -v pdftoppm >/dev/null || OCR_AVAILABLE=0
command -v tesseract >/dev/null || OCR_AVAILABLE=0
if (( ! OCR_AVAILABLE )); then
  echo "Note: pdftoppm/tesseract not found — OCR fallback disabled. Textless pages will only be flagged, not recovered (install poppler-utils + Tesseract OCR to enable)." >&2
fi

# --- page count ---------------------------------------------------------
TOTAL_PAGES=$(pdfinfo "$PDF" | awk '/^Pages:/ {print $2}')
if [[ -z "$TOTAL_PAGES" || "$TOTAL_PAGES" -lt 1 ]]; then
  echo "Error: could not read page count from $PDF" >&2
  exit 1
fi

NUM_CHUNKS=$(( (TOTAL_PAGES + PAGES_PER_CHUNK - 1) / PAGES_PER_CHUNK ))
mkdir -p "$OUT_DIR"

echo "Input:  $PDF ($TOTAL_PAGES pages)"
echo "Output: $OUT_DIR/ ($NUM_CHUNKS chunks of up to $PAGES_PER_CHUNK pages)"

# --- helper: last non-empty paragraph of a file -------------------------
# pdftotext emits a lone form-feed (\f) as a page-break marker even for a
# blank/textless page. awk's paragraph mode (RS="") doesn't treat a line
# containing only \f as a blank-line separator, so without stripping it
# here a textless page would be carried forward as fake "overlap" text.
last_paragraph() {
  awk 'BEGIN{RS=""} {p=$0} END{if (p != "") print p}' "$1" | tr -d '\f'
}

# --- split --------------------------------------------------------------
prev_chunk=""
empty_chunks=0

for (( i=1; i<=NUM_CHUNKS; i++ )); do
  first=$(( (i-1) * PAGES_PER_CHUNK + 1 ))
  last=$(( i * PAGES_PER_CHUNK ))
  (( last > TOTAL_PAGES )) && last=$TOTAL_PAGES

  chunk=$(printf '%s/chunk_%02d.txt' "$OUT_DIR" "$i")
  body=$(mktemp)

  # -layout preserves column/paragraph structure; fail loudly, never partial
  if ! pdftotext -layout -f "$first" -l "$last" "$PDF" "$body"; then
    rm -f "$body"
    echo "Error: pdftotext failed on pages $first-$last — flag for manual review" >&2
    exit 1
  fi

  # Check emptiness of the raw per-page extraction, before overlap headers
  # are added — the assembled chunk always contains bracket text once an
  # overlap is present, which would mask a genuinely textless page.
  page_is_empty=0
  if ! tr -d '\f' < "$body" | grep -q '[^[:space:]]'; then
    page_is_empty=1
  fi

  # OCR fallback: pdftotext found no embedded text on this page (either a
  # scanned image or, e.g., a "print to PDF" export that flattened glyphs
  # into vector paths with no font behind them). Rasterize each page in
  # this range and OCR it instead of giving up. OCR output is marked
  # distinctly per Legal Accuracy Rule 3/4 — it is a recognition result,
  # not a verified text layer, and must be checked against the source image.
  ocr_used=0
  if (( page_is_empty )) && (( OCR_AVAILABLE )); then
    ocr_dir=$(mktemp -d)
    ocr_text=""
    for (( p=first; p<=last; p++ )); do
      pdftoppm -r 300 -png -f "$p" -l "$p" "$PDF" "$ocr_dir/pg" 2>/dev/null || true
      png_file=$(ls "$ocr_dir"/pg-*.png 2>/dev/null | head -1)
      if [[ -n "$png_file" ]]; then
        tess_out="$ocr_dir/tess_$p"
        if tesseract "$png_file" "$tess_out" >/dev/null 2>&1 && [[ -s "${tess_out}.txt" ]]; then
          ocr_text+="[OCR — page $p, verify against source image; recognition errors possible]"$'\n'
          ocr_text+="$(cat "${tess_out}.txt")"$'\n\n'
        fi
        rm -f "$png_file" "${tess_out}.txt"
      fi
    done
    rm -rf "$ocr_dir"
    if [[ -n "$(tr -d '[:space:]' <<< "$ocr_text")" ]]; then
      printf '%s' "$ocr_text" > "$body"
      page_is_empty=0
      ocr_used=1
    fi
  fi

  {
    if [[ -n "$prev_chunk" ]]; then
      overlap=$(last_paragraph "$prev_chunk")
      if [[ -n "$overlap" ]]; then
        echo "[OVERLAP FROM PREVIOUS CHUNK]"
        echo "$overlap"
        echo
        echo "[--- END OVERLAP ---]"
        echo
      fi
    fi
    cat "$body"
  } > "$chunk"

  rm -f "$body"

  # Warn on empty extraction (likely scanned PDF with no text layer)
  if (( page_is_empty )); then
    echo "Warning: $chunk is empty (pages $first-$last) — possible scanned PDF, needs OCR" >&2
    (( empty_chunks++ )) || true
  elif (( ocr_used )); then
    echo "Note: $chunk recovered via OCR (pages $first-$last) — verify against source image before trusting extracted terms" >&2
  fi

  echo "  $chunk  (pages $first-$last)"
  prev_chunk="$chunk"
done

if (( empty_chunks == NUM_CHUNKS )); then
  echo "Error: no text extracted from any page — PDF likely has no text layer. Run OCR first." >&2
  exit 2
fi

echo "Done: $NUM_CHUNKS chunks written to $OUT_DIR/"
