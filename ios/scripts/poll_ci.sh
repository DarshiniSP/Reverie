#!/usr/bin/env zsh
set -euo pipefail

# Polls CI until all 4 jobs have a conclusion (success/failure/skipped)
# Usage: export REPO="IrigamGit/iAlly"; zsh scripts/poll_ci.sh

REPO=${REPO:-"IrigamGit/iAlly"}

function print_summary() {
  # Clean previously downloaded local artifacts to avoid size growth
  zsh /Users/irigamdeveloper/Projects/iAlly/scripts/clean_artifacts.sh || true
  # Fetch latest CI summary and artifacts listing
  zsh /Users/irigamdeveloper/Projects/iAlly/scripts/ci_summary.sh || true
}

echo "Polling CI for ${REPO}..."
while true; do
  output=$(print_summary)
  echo "$output"
  # Count jobs with a final conclusion
  concluded=$(echo "$output" | awk -F"\t" '/\t(completed|in_progress|queued)\t/ {print $3}' | grep -c -E 'success|failure|skipped' || true)
  total=4
  if [[ "$concluded" -ge "$total" ]]; then
    echo "All jobs concluded ($concluded/$total)."
    break
  fi
  sleep 60
done

echo "Final CI summary:"
print_summary
