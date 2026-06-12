#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

export GENUS_RUN_ROOT="${PACKAGE_ROOT}"

GENUS_BIN="${GENUS_BIN:-genus}"
GENUS_TOP="${GENUS_TOP:-generic_fp_rd}"
export GENUS_TOP

mkdir -p "${PACKAGE_ROOT}/work" \
         "${PACKAGE_ROOT}/logs" \
         "${PACKAGE_ROOT}/reports" \
         "${PACKAGE_ROOT}/outputs"

cd "${PACKAGE_ROOT}"

exec "${GENUS_BIN}" -files "${SCRIPT_DIR}/genus_physical_synth.tcl" \
    -log "logs/genus_${GENUS_TOP}.log"
