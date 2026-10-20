#!/usr/bin/env bash
# Builds the manuscript in a Pandoc image, with the template's pandoc/ folder mounted into it.
set -euo pipefail

fail() { echo "::error::$1" >&2; exit 1; }

[ -n "$DEFAULTS" ] || fail "'defaults' is required"
if [ -n "$TEMPLATE" ] && [ -n "$DATA_DIR" ]; then fail "use either 'template' or 'data-dir', not both"; fi
if [ -z "$TEMPLATE" ] && [ -z "$DATA_DIR" ]; then fail "one of 'template' or 'data-dir' is required"; fi

workspace="${GITHUB_WORKSPACE:-$PWD}"

if [ -n "$TEMPLATE" ]; then
  # fetched outside the workspace, so nothing of the template ends up in the consumer's tree
  repo="${TEMPLATE%%@*}"
  ref=HEAD
  case "$TEMPLATE" in *@*) ref="${TEMPLATE#*@}" ;; esac
  auth=()
  if [ -n "$TOKEN" ]; then
    auth=(-c "http.extraheader=AUTHORIZATION: basic $(printf 'x-access-token:%s' "$TOKEN" | base64 | tr -d '\n')")
  fi
  checkout="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/template.XXXXXX")"
  git -C "$checkout" init -q
  git -C "$checkout" ${auth[@]+"${auth[@]}"} fetch -q --depth 1 "${GITHUB_SERVER_URL:-https://github.com}/$repo" "$ref"
  git -C "$checkout" checkout -q FETCH_HEAD
  data="$checkout/pandoc"
else
  data="$workspace/$DATA_DIR"
fi
[ -d "$data" ] || fail "Pandoc data directory not found: $data"

cd "$workspace/$WORKDIR"

docker run --rm -v "$workspace:/data" -v "$data:/opt/pandoc-template:ro" -w "/data/$WORKDIR" \
  "$IMAGE" \
  --data-dir=/opt/pandoc-template -d "$DEFAULTS" "$INPUT" -o "$OUTPUT" ${ARGS:-}
