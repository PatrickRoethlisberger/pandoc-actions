#!/usr/bin/env bash
# Exports each page of every draw.io diagram to a cropped PDF beside it: page 1 is
# name.pdf, page N is name-pageN.pdf.
set -euo pipefail

workspace="${GITHUB_WORKSPACE:-$PWD}"
cd "$workspace/$WORKDIR"

while IFS= read -r -d '' diagram; do
  pages="$(grep -o '<diagram[ >]' "$diagram" | wc -l)"
  for page in $(seq 1 "$pages"); do
    suffix=""
    if [ "$page" -gt 1 ]; then suffix="-page$page"; fi
    docker run --rm -v "$workspace:/data" -w "/data/$WORKDIR" \
      rlespinasse/drawio-desktop-headless:minimal-v1.76.0 \
      -x -f pdf --crop -o "${diagram%.*}$suffix.pdf" -p "$page" "$diagram"
  done
done < <(find . \( -name '*.drawio' -o -name '*.dio' \) -print0)
