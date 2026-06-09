#!/usr/bin/env bash
# =============================================================================
# download_model_weights.sh
# Pre-download all model weights required by nf-proteindesign so the pipeline
# can run fully offline (no auto-download during execution).
#
# Usage:
#   bash download_model_weights.sh [--boltz2] [--rfdiffusion] [--all]
#
# Options:
#   --boltz2       Download Boltz-2 model weights + ligand CCD database (~6 GB)
#   --rfdiffusion  Download RFdiffusion3 (Foundry) checkpoints (~4 GB)
#   --all          Download everything (default when no flag is given)
#
# After running this script, pass the cache paths to your pipeline:
#   nextflow run main.nf \
#     --protein_design_tool rfdiffusion_v3 \
#     --rfdiffusion_v3_ckpt_dir  /path/to/foundry_checkpoints \
#     --boltz2_cache             /path/to/boltz2_cache \
#     ...
#
# Requirements:
#   - Docker (for Boltz-2 and RFdiffusion3 downloads via their own containers)
#   - ~12 GB free disk space (both caches combined)
# =============================================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(dirname "${SCRIPT_DIR}")"

BOLTZ2_CACHE_DIR="${BOLTZ2_CACHE_DIR:-${PIPELINE_DIR}/model_cache/boltz2}"
FOUNDRY_CKPT_DIR="${FOUNDRY_CKPT_DIR:-${PIPELINE_DIR}/model_cache/foundry_checkpoints}"

DO_BOLTZ2=false
DO_RFDIFFUSION=false

# ── Argument parsing ──────────────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
    DO_BOLTZ2=true
    DO_RFDIFFUSION=true
fi

for arg in "$@"; do
    case "${arg}" in
        --boltz2)      DO_BOLTZ2=true ;;
        --rfdiffusion) DO_RFDIFFUSION=true ;;
        --all)         DO_BOLTZ2=true; DO_RFDIFFUSION=true ;;
        --help|-h)
            sed -n '2,20p' "$0" | sed 's/^# //; s/^#//'
            exit 0
            ;;
        *)
            echo "Unknown option: ${arg}" >&2
            echo "Run with --help for usage." >&2
            exit 1
            ;;
    esac
done

# ── Helper ────────────────────────────────────────────────────────────────────
log() { echo "[$(date '+%H:%M:%S')] $*"; }
hr()  { echo "────────────────────────────────────────────────────────────"; }

require_docker() {
    if ! command -v docker &>/dev/null; then
        echo "ERROR: Docker is required but not installed." >&2
        exit 1
    fi
    if ! docker info &>/dev/null; then
        echo "ERROR: Docker daemon is not running or you lack permission." >&2
        exit 1
    fi
}

# =============================================================================
# 1. BOLTZ-2  (giosbiostructures/boltz2:latest)
#    Weights: boltz2_conf.ckpt (~2.2 GB), boltz2_aff.ckpt (~2.0 GB)
#    Ligand DB: mols/ CCD database (~1.8 GB unpacked)
#    Total: ~6 GB
# =============================================================================
download_boltz2() {
    hr
    log "Downloading Boltz-2 model weights → ${BOLTZ2_CACHE_DIR}"
    hr

    mkdir -p "${BOLTZ2_CACHE_DIR}"

    # Pull the container image first (cached on re-runs)
    log "Pulling container: giosbiostructures/boltz2:latest"
    docker pull giosbiostructures/boltz2:latest

    # Run `boltz download --cache` to fetch all weights into the target directory.
    log "Seeding Boltz-2 cache (this downloads ~6 GB, please wait) ..."
    docker run --rm \
        -v "${BOLTZ2_CACHE_DIR}:/boltz_cache" \
        giosbiostructures/boltz2:latest \
        boltz download --cache /boltz_cache

    log "✓ Boltz-2 weights downloaded to: ${BOLTZ2_CACHE_DIR}"
    log "  Contents:"
    ls -lh "${BOLTZ2_CACHE_DIR}" | sed 's/^/    /'
    echo ""
    log "  Pass this to the pipeline with:"
    log "    --boltz2_cache ${BOLTZ2_CACHE_DIR}"
}

# =============================================================================
# 2. RFDIFFUSION3 / FOUNDRY  (rosettacommons/foundry:latest)
#    Weights: rfd3 model checkpoints (~4 GB)
#    Downloaded via `rfd3 download` inside the container
# =============================================================================
download_rfdiffusion() {
    hr
    log "Downloading RFdiffusion3 (Foundry) checkpoints → ${FOUNDRY_CKPT_DIR}"
    hr

    mkdir -p "${FOUNDRY_CKPT_DIR}"

    # Pull the container image first
    log "Pulling container: rosettacommons/foundry:latest"
    docker pull rosettacommons/foundry:latest

    # Use the built-in `rfd3 download` command to fetch checkpoints.
    # FOUNDRY_CHECKPOINT_DIRS tells the CLI where to save them.
    log "Downloading RFdiffusion3 checkpoints (this downloads ~4 GB, please wait) ..."
    docker run --rm \
        -v "${FOUNDRY_CKPT_DIR}:/foundry_ckpts" \
        -e FOUNDRY_CHECKPOINT_DIRS="/foundry_ckpts" \
        rosettacommons/foundry:latest \
        rfd3 download

    log "✓ RFdiffusion3 checkpoints downloaded to: ${FOUNDRY_CKPT_DIR}"
    log "  Contents:"
    ls -lh "${FOUNDRY_CKPT_DIR}" | sed 's/^/    /'
    echo ""
    log "  Pass this to the pipeline with:"
    log "    --rfdiffusion_v3_ckpt_dir ${FOUNDRY_CKPT_DIR}"
}

# =============================================================================
# Main
# =============================================================================
hr
log "nf-proteindesign — model weight downloader"
log "Cache root: ${PIPELINE_DIR}/model_cache/"
hr

require_docker

[[ "${DO_BOLTZ2}"       == "true" ]] && download_boltz2
[[ "${DO_RFDIFFUSION}"  == "true" ]] && download_rfdiffusion

hr
log "All downloads complete!"
hr
echo ""
echo "Run the pipeline with pre-seeded caches:"
echo ""
echo "  nextflow run main.nf \\"
if [[ "${DO_RFDIFFUSION}" == "true" ]]; then
echo "    --protein_design_tool  rfdiffusion_v3 \\"
echo "    --rfdiffusion_v3_ckpt_dir ${FOUNDRY_CKPT_DIR} \\"
fi
if [[ "${DO_BOLTZ2}" == "true" ]]; then
echo "    --boltz2_cache         ${BOLTZ2_CACHE_DIR} \\"
fi
echo "    --input                your_samplesheet.csv \\"
echo "    --outdir               ./results"
echo ""
