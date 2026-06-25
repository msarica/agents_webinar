#!/usr/bin/env bash
# Convert Markdown files to DOCX using pandoc.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: convert.sh [options] <file.md> [file2.md ...]

Options:
  -o, --output <path>       Output file (single input only)
  --reference-doc <path>    Pandoc reference DOCX for custom styles
  -h, --help                Show this help

Default: writes <basename>.docx beside each input file.
EOF
}

if ! command -v pandoc >/dev/null 2>&1; then
  echo "Error: pandoc is not installed." >&2
  echo "Install: brew install pandoc  (macOS)" >&2
  echo "         sudo apt install pandoc  (Debian/Ubuntu)" >&2
  echo "         winget install --id JohnMacFarlane.Pandoc  (Windows)" >&2
  exit 1
fi

output=""
reference_doc=""
inputs=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      [[ $# -ge 2 ]] || { echo "Error: $1 requires a path." >&2; exit 1; }
      output="$2"
      shift 2
      ;;
    --reference-doc)
      [[ $# -ge 2 ]] || { echo "Error: $1 requires a path." >&2; exit 1; }
      reference_doc="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      inputs+=("$@")
      break
      ;;
    -*)
      echo "Error: unknown option $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      inputs+=("$1")
      shift
      ;;
  esac
done

if [[ ${#inputs[@]} -eq 0 ]]; then
  echo "Error: no input .md files specified." >&2
  usage >&2
  exit 1
fi

if [[ -n "$output" && ${#inputs[@]} -gt 1 ]]; then
  echo "Error: -o/--output can only be used with a single input file." >&2
  exit 1
fi

if [[ -n "$reference_doc" && ! -f "$reference_doc" ]]; then
  echo "Error: reference document not found: $reference_doc" >&2
  exit 1
fi

convert_one() {
  local input="$1"
  local out="$2"

  if [[ ! -f "$input" ]]; then
    echo "Error: file not found: $input" >&2
    return 1
  fi

  case "$input" in
    *.md|*.markdown) ;;
    *)
      echo "Error: expected a .md file: $input" >&2
      return 1
      ;;
  esac

  local input_dir input_name abs_out
  input_dir="$(cd "$(dirname "$input")" && pwd)"
  input_name="$(basename "$input")"
  abs_out="$(cd "$(dirname "$out")" && pwd)/$(basename "$out")"

  local args=(--from=gfm --to=docx --output="$abs_out")
  if [[ -n "$reference_doc" ]]; then
    args=(--reference-doc="$reference_doc" "${args[@]}")
  fi
  args+=("$input_name")

  (cd "$input_dir" && pandoc "${args[@]}")

  if [[ ! -s "$abs_out" ]]; then
    echo "Error: conversion produced empty output: $abs_out" >&2
    return 1
  fi

  echo "$abs_out"
}

for input in "${inputs[@]}"; do
  if [[ -n "$output" ]]; then
    out="$output"
  else
    out="${input%.*}.docx"
  fi

  convert_one "$input" "$out"
done
