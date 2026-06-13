#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

export GENUS_RUN_ROOT="${PACKAGE_ROOT}"

GENUS_BIN="${GENUS_BIN:-genus}"
GENUS_TOP="${GENUS_TOP:-generic_fp_rd}"
export GENUS_TOP

if [ "$#" -gt 2 ]; then
    echo "Usage: $0 [clock_period_ns] [io_delay_ns]" >&2
    exit 2
fi

if [ "$#" -ge 1 ]; then
    export GENUS_CLOCK_PERIOD_NS="$1"
fi

if [ "$#" -ge 2 ]; then
    export GENUS_IO_DELAY_NS="$2"
fi

export GENUS_CLOCK_PERIOD_NS="${GENUS_CLOCK_PERIOD_NS:-10.0}"
export GENUS_IO_DELAY_NS="${GENUS_IO_DELAY_NS:-1.0}"

mkdir -p "${PACKAGE_ROOT}/work" \
         "${PACKAGE_ROOT}/logs" \
         "${PACKAGE_ROOT}/reports" \
         "${PACKAGE_ROOT}/outputs"

cd "${PACKAGE_ROOT}"

echo "GENUS_BIN=${GENUS_BIN}"
echo "GENUS_TOP=${GENUS_TOP}"
echo "GENUS_CLOCK_PERIOD_NS=${GENUS_CLOCK_PERIOD_NS}"
echo "GENUS_IO_DELAY_NS=${GENUS_IO_DELAY_NS}"

exec "${GENUS_BIN}" -files "${SCRIPT_DIR}/genus_physical_synth.tcl" \
    -log "logs/genus_${GENUS_TOP}.log"
