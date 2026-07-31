#!/usr/bin/env bash
# Usage: ./open-project.sh <project-name>
# Generates a per-project workspace file from the template and opens VS Code.
set -euo pipefail

PROJECT="${1:?Usage: $0 <project-name>}"
PROJECT="${PROJECT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${SCRIPT_DIR}/workspace-template.code-workspace"
OUTPUT="${SCRIPT_DIR}/${PROJECT}.code-workspace"

sed "s/__PROJECT__/${PROJECT}/g" "$TEMPLATE" > "$OUTPUT"
code "$OUTPUT"
