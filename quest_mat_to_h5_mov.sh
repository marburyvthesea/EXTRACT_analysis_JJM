#!/bin/bash
#SBATCH -A p30771
#SBATCH -p short
#SBATCH -N 1
#SBATCH --ntasks-per-node=4
#SBATCH --mem=25G
#SBATCH --time=02:00:00
#SBATCH --job-name=mat_to_h5
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  sbatch quest_mat_to_h5_mov.sbatch MAT_PATH H5_PATH [VAR_NAME] [DSET_NAME] [FRAMES_PER_CHUNK] [CAST_TO] [FRAME_START] [FRAME_END]

Positional arguments:
  MAT_PATH          Input MAT-file path
  H5_PATH           Output HDF5 file path
  VAR_NAME          MATLAB variable name (default: Y)
  DSET_NAME         HDF5 dataset name (default: /mov)
  FRAMES_PER_CHUNK  Frames per chunk (default: 200)
  CAST_TO           Output datatype, e.g. single, uint16 (default: keep source type)
  FRAME_START       First frame to export (default: 1)
  FRAME_END         Last frame to export (default: full movie)

Example:
  sbatch quest_mat_to_h5_mov.sbatch \
    /path/input.mat /path/output.h5 Y /mov 200 single 1000 2000

Notes:
  - This script expects mat_to_h5_mov.m at:
    /Users/johnmarshall/Documents/MATLAB/EXTRACT_analysis_JJM/mat_to_h5_mov.m
  - You can still override Slurm resources at submission time, e.g.:
    sbatch -A p30771 -p short --mem=40G quest_mat_to_h5_mov.sbatch ...
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 2 ]]; then
  usage >&2
  exit 1
fi

MATLAB_FUNC_DIR="/Users/johnmarshall/Documents/MATLAB/EXTRACT_analysis_JJM"
MATLAB_FUNC_FILE="${MATLAB_FUNC_DIR}/mat_to_h5_mov.m"

if [[ ! -f "${MATLAB_FUNC_FILE}" ]]; then
  echo "Error: cannot find ${MATLAB_FUNC_FILE}" >&2
  exit 1
fi

MAT_PATH="$1"
H5_PATH="$2"
VAR_NAME="${3:-Y}"
DSET_NAME="${4:-/mov}"
FRAMES_PER_CHUNK="${5:-200}"
CAST_TO="${6:-}"
FRAME_START="${7:-}"
FRAME_END="${8:-}"

matlab_quote() {
  local s="${1//\'/\'\'}"
  printf "'%s'" "$s"
}

if ! [[ "${FRAMES_PER_CHUNK}" =~ ^[0-9]+$ ]]; then
  echo "Error: FRAMES_PER_CHUNK must be an integer. Got: ${FRAMES_PER_CHUNK}" >&2
  exit 1
fi

MAT_PATH_Q=$(matlab_quote "${MAT_PATH}")
H5_PATH_Q=$(matlab_quote "${H5_PATH}")
VAR_NAME_Q=$(matlab_quote "${VAR_NAME}")
DSET_NAME_Q=$(matlab_quote "${DSET_NAME}")
CAST_TO_Q=$(matlab_quote "${CAST_TO}")

MATLAB_CMD="addpath($(matlab_quote "${MATLAB_FUNC_DIR}"));"
MATLAB_CMD+=" mat_to_h5_mov(${MAT_PATH_Q}, ${H5_PATH_Q}"

if [[ $# -ge 3 ]]; then
  MATLAB_CMD+=", ${VAR_NAME_Q}"
fi

if [[ $# -ge 4 ]]; then
  MATLAB_CMD+=", ${DSET_NAME_Q}"
fi

if [[ $# -ge 5 ]]; then
  MATLAB_CMD+=", ${FRAMES_PER_CHUNK}"
fi

if [[ $# -ge 6 ]]; then
  MATLAB_CMD+=", ${CAST_TO_Q}"
fi

if [[ $# -ge 7 || $# -ge 8 ]]; then
  if [[ $# -lt 8 ]]; then
    echo "Error: FRAME_START and FRAME_END must be provided together." >&2
    exit 1
  fi
  if ! [[ "${FRAME_START}" =~ ^[0-9]+$ && "${FRAME_END}" =~ ^[0-9]+$ ]]; then
    echo "Error: FRAME_START and FRAME_END must be integers." >&2
    exit 1
  fi
  MATLAB_CMD+=", ${FRAME_START}, ${FRAME_END}"
fi

MATLAB_CMD+=");"

module purge
module load matlab

echo "Starting MATLAB job on ${SLURM_JOB_NODELIST:-unknown-node}"
echo "MAT_PATH=${MAT_PATH}"
echo "H5_PATH=${H5_PATH}"
echo "VAR_NAME=${VAR_NAME}"
echo "DSET_NAME=${DSET_NAME}"
echo "FRAMES_PER_CHUNK=${FRAMES_PER_CHUNK}"
echo "CAST_TO=${CAST_TO:-<source type>}"
if [[ -n "${FRAME_START}" ]]; then
  echo "FRAME_RANGE=${FRAME_START}-${FRAME_END}"
else
  echo "FRAME_RANGE=full movie"
fi

matlab -batch "${MATLAB_CMD}"
