#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/sim/build/fp_rd_chirp"
RTL_FILELIST="${ROOT_DIR}/filelist/rtl.f"
TB_FILELIST="${ROOT_DIR}/filelist/tb.f"
SAMPLE_COUNT="${SAMPLE_COUNT:-256}"
AMPLITUDE="${AMPLITUDE:-12000}"
START_FREQUENCY="${START_FREQUENCY:-0.01}"
STOP_FREQUENCY="${STOP_FREQUENCY:-0.45}"
CUTOFF="${CUTOFF:-0.18}"
VCS_BIN="${VCS_BIN:-vcs}"

find_verdi_pli_root() {
    local verdi_path
    local verdi_root
    local candidate
    local candidates=()

    if [[ -n "${VERDI_PLI_ROOT:-}" ]]; then
        candidates+=("${VERDI_PLI_ROOT}")
    fi
    if [[ -n "${VERDI_HOME:-}" ]]; then
        candidates+=("${VERDI_HOME}/share/PLI/VCS/LINUX64")
        candidates+=("${VERDI_HOME}/share/PLI/VCS/LINUX")
    fi
    if [[ -n "${NOVAS_HOME:-}" ]]; then
        candidates+=("${NOVAS_HOME}/share/PLI/VCS/LINUX64")
        candidates+=("${NOVAS_HOME}/share/PLI/VCS/LINUX")
    fi
    if verdi_path="$(command -v verdi 2>/dev/null)"; then
        verdi_root="$(cd -- "$(dirname -- "${verdi_path}")/.." && pwd)"
        candidates+=("${verdi_root}/share/PLI/VCS/LINUX64")
        candidates+=("${verdi_root}/share/PLI/VCS/LINUX")
    fi

    for candidate in "${candidates[@]}"; do
        if [[ -f "${candidate}/novas.tab" && -f "${candidate}/pli.a" ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done
    return 1
}

configure_verdi_runtime() {
    local install_root
    local directory
    local directories=()

    install_root="$(cd -- "${VERDI_PLI_ROOT}/../../../.." && pwd)"
    directories+=("${VERDI_PLI_ROOT}")
    directories+=("${install_root}/share/PLI/VCS/LINUX64")
    directories+=("${install_root}/share/PLI/VCS/LINUX")
    directories+=("${install_root}/share/PLI/lib/LINUX64")
    directories+=("${install_root}/share/PLI/lib/LINUX")
    directories+=("${install_root}/platform/LINUX64/lib")
    directories+=("${install_root}/lib")

    for directory in "${directories[@]}"; do
        if [[ -d "${directory}" ]]; then
            case ":${LD_LIBRARY_PATH:-}:" in
                *":${directory}:"*) ;;
                *) export LD_LIBRARY_PATH="${directory}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" ;;
            esac
        fi
    done

    if [[ -n "${VERDI_EXTRA_LD_LIBRARY_PATH:-}" ]]; then
        export LD_LIBRARY_PATH="${VERDI_EXTRA_LD_LIBRARY_PATH}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
    fi
}

if ! command -v "${VCS_BIN}" >/dev/null 2>&1; then
    echo "Error: VCS executable not found: ${VCS_BIN}" >&2
    exit 1
fi
if ! VERDI_PLI_ROOT="$(find_verdi_pli_root)"; then
    echo "Error: Verdi PLI not found; set VERDI_PLI_ROOT or VERDI_HOME." >&2
    exit 1
fi
configure_verdi_runtime

cd "${ROOT_DIR}"
mkdir -p "${BUILD_DIR}/logs" "${BUILD_DIR}/csrc"

if [[ -f "${RTL_FILELIST}" && -f "${TB_FILELIST}" ]]; then
    MODEL="${ROOT_DIR}/model/fir_model.py"
    rtl_args=(-f "${RTL_FILELIST}" -f "${TB_FILELIST}")
else
    MODEL="${ROOT_DIR}/sim/fir_model.py"
    bazel build //src/filters/fp-rd:rtl
    mapfile -t RTL_SOURCES < <(
        bazel cquery --noshow_progress --output=files //src/filters/fp-rd:rtl \
            | rg '\.(sv|v)$'
    )
    rtl_args=("${RTL_SOURCES[@]}" sim/fp_rd_chirp_tb.sv)
fi

python3 "${MODEL}" \
    --out-dir "${BUILD_DIR}" \
    --sample-count "${SAMPLE_COUNT}" \
    --amplitude "${AMPLITUDE}" \
    --start-frequency "${START_FREQUENCY}" \
    --stop-frequency "${STOP_FREQUENCY}" \
    --cutoff "${CUTOFF}"

compile_args=(
    -full64
    -sverilog
    -timescale=1ns/1ps
    -debug_access+all
    -kdb
    +vcs+lic+wait
    -P "${VERDI_PLI_ROOT}/novas.tab" "${VERDI_PLI_ROOT}/pli.a"
    -top fp_rd_chirp_tb
    -Mdir="${BUILD_DIR}/csrc"
    -o "${BUILD_DIR}/simv"
    -l "${BUILD_DIR}/logs/vcs_compile.log"
)

run_args=(
    "+SAMPLE_COUNT=${SAMPLE_COUNT}"
)

if [[ -n "${VCS_ARGS:-}" ]]; then
    extra_compile_args=(${VCS_ARGS})
    compile_args+=("${extra_compile_args[@]}")
fi
if [[ -n "${SIMV_ARGS:-}" ]]; then
    extra_run_args=(${SIMV_ARGS})
    run_args+=("${extra_run_args[@]}")
fi

"${VCS_BIN}" "${compile_args[@]}" "${rtl_args[@]}"

"${BUILD_DIR}/simv" "${run_args[@]}" \
    -l "${BUILD_DIR}/logs/simv.log"

echo "Model response: ${BUILD_DIR}/response.csv"
echo "DUT response:   ${BUILD_DIR}/dut_output.csv"
echo "FSDB:           ${BUILD_DIR}/waves.fsdb"
