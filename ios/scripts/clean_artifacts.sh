#!/usr/bin/env zsh
set -euo pipefail

# Clean local CI artifact downloads to avoid size growth
# Usage: zsh scripts/clean_artifacts.sh

ART_DIR="/Users/irigamdeveloper/Projects/iAlly/artifacts"

echo "Cleaning local artifacts in ${ART_DIR}..."

rm -rf ${ART_DIR}/ui-logs-iPhone18 ${ART_DIR}/ui-logs-iPhone17 \
       ${ART_DIR}/unit-logs-iPhone18 ${ART_DIR}/unit-logs-iPhone17 || true

rm -f ${ART_DIR}/ui-logs-iPhone18.zip ${ART_DIR}/ui-logs-iPhone17.zip \
      ${ART_DIR}/unit-logs-iPhone18.zip ${ART_DIR}/unit-logs-iPhone17.zip || true

rm -f ${ART_DIR}/ci-summary.zip ${ART_DIR}/ci-summary.txt || true

echo "Done."
