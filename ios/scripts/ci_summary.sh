#!/usr/bin/env zsh
set -euo pipefail

# Usage: GITHUB_TOKEN=... scripts/ci_summary.sh
# Fetch latest run, list job statuses, and download + print matrix summary if present.

# .env loading removed to avoid implicit env changes; rely on GITHUB_TOKEN or Keychain.

# Repo can be overridden via env
REPO=${REPO:-"IrigamGit/iAlly"}
BASE_URL="https://api.github.com/repos/${REPO}"

# Try Keychain fallback for token if missing
if [[ -z ${GITHUB_TOKEN:-} ]]; then
  if command -v security >/dev/null 2>&1; then
    owner=${REPO%%/*}
    repo=${REPO##*/}
    key_name="GITHUB_TOKEN_${owner}_${repo}"
    token=$(security find-generic-password -s "$key_name" -w 2>/dev/null || true)
    if [[ -n "$token" ]]; then
      export GITHUB_TOKEN="$token"
    fi
  fi
fi

if [[ -z ${GITHUB_TOKEN:-} ]]; then
  echo "Error: GITHUB_TOKEN env var not set." >&2
  echo "Set it via: export GITHUB_TOKEN=\"<PAT>\"" >&2
  echo "Or add to .env (GITHUB_TOKEN=...)" >&2
  echo "Or save in Keychain: security add-generic-password -a $USER -s GITHUB_TOKEN_${REPO%%/*}_${REPO##*/} -w '<PAT>'" >&2
  exit 1
fi

RUN_ID=$(curl -sSfL -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/${REPO}/actions/runs?per_page=1" | jq -r '.workflow_runs[0].id')

echo "Latest RUN_ID: ${RUN_ID}"

echo "Job statuses:"
curl -sSfL -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/${REPO}/actions/runs/${RUN_ID}/jobs?per_page=50" | \
  jq -r '.jobs[] | "\(.name)\t\(.status)\t\(.conclusion)"'

echo "Artifacts:"
ART_JSON=$(curl -sSfL -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/${REPO}/actions/runs/${RUN_ID}/artifacts")
echo "$ART_JSON" | jq -r '.artifacts[] | "\(.id)\t\(.name)\t\(.size_in_bytes)"'

# Try to download aggregated matrix summary if available
ART_ID=$(echo "$ART_JSON" | jq -r '.artifacts[] | select(.name=="ci-matrix-summary") | .id')
if [[ -n "$ART_ID" && "$ART_ID" != "null" ]]; then
  TMPDIR=$(mktemp -d)
  curl -sSfL -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -o "$TMPDIR/ci-summary.zip" \
    "https://api.github.com/repos/${REPO}/actions/artifacts/${ART_ID}/zip"
  unzip -q -o "$TMPDIR/ci-summary.zip" -d "$TMPDIR"
  echo "\n=== CI Matrix Summary ==="
  cat "$TMPDIR/summary.txt" || echo "summary.txt missing"
  exit 0
fi

# Fallback: download per-job summaries and print compact results
echo "\nNo aggregator found; compiling per-job summaries..."
WORKDIR=$(mktemp -d)
echo "$ART_JSON" | jq -r '.artifacts[] | select(.name|test("unit-logs|ui-logs")) | ("" + (.id|tostring) + "\t" + .name)' | while read -r line; do
  aid=$(echo "$line" | awk -F '\t' '{print $1}')
  aname=$(echo "$line" | awk -F '\t' '{print $2}')
  curl -sSfL -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -o "$WORKDIR/${aname}.zip" \
    "https://api.github.com/repos/${REPO}/actions/artifacts/${aid}/zip"
  unzip -q -o "$WORKDIR/${aname}.zip" -d "$WORKDIR/${aname}"
done

  # Prefer lightweight failures.txt extraction without inflating large xcresult bundles
  echo "$ART_JSON" | jq -r '.artifacts[] | @base64' | while read -r art; do
    _jq() { echo "$art" | base64 --decode | jq -r "$1"; }
    name=$(_jq '.name')
    id=$(_jq '.id')
    [[ -z "$name" || -z "$id" ]] && continue
    case "$name" in
      unit-logs-*|ui-logs-*)
        tmpdir=$(mktemp -d)
        zipfile="$tmpdir/$name.zip"
        curl -sS -L -H "Authorization: Bearer $GITHUB_TOKEN" "$BASE_URL/actions/artifacts/$id/zip" -o "$zipfile" || continue
        # Extract only failures, summary, and ui tail files to avoid heavy unzip
        echo "\n$name: $name"
        unzip -j -q "$zipfile" "*failures_*.txt" -d "$tmpdir" >/dev/null 2>&1 || true
        unzip -j -q "$zipfile" "summary.txt" -d "$tmpdir" >/dev/null 2>&1 || true
        unzip -j -q "$zipfile" "ui_error_tail_*.txt" -d "$tmpdir" >/dev/null 2>&1 || true
        if [[ -f "$tmpdir"/summary.txt ]]; then
          echo "Summary:"
          cat "$tmpdir"/summary.txt
        fi
        set +u
        for f in "$tmpdir"/*failures_*.txt(N); do
          [[ -e "$f" ]] || continue
          echo "Failures ($name):"
          cat "$f"
        done
        for f in "$tmpdir"/ui_error_tail_*.txt(N); do
          [[ -e "$f" ]] || continue
          echo "UI Log Tail ($name):"
          tail -n 300 "$f" || cat "$f"
        done
        set -u
        rm -rf "$tmpdir"
      ;;
    esac
  done
  echo "\nDone."
