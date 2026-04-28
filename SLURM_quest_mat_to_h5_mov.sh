#!/bin/bash
#SBATCH -A p30771
#SBATCH -p normal
#SBATCH -N 1
#SBATCH --ntasks-per-node=4
#SBATCH --mem=25G
#SBATCH --time=02:00:00
#SBATCH -e ./logfiles/mat_to_h5.%x-%j.err
#SBATCH -o ./logfiles/mat_to_h5.%x-%j.out # STDOUT
#SBATCH --job-name="mat_to_h5"

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  sbatch SLURM_quest_mat_to_h5_mov.sh MAT_PATH H5_PATH [VAR_NAME] [DSET_NAME] [FRAMES_PER_CHUNK] [CAST_TO] [FRAME_START] [FRAME_END] [DOWNSAMPLE_INPUT]
  sbatch SLURM_quest_mat_to_h5_mov.sh MAT_PATH H5_PATH [VAR_NAME] [DSET_NAME] [FRAMES_PER_CHUNK] [CAST_TO] [--downsample-input N]
  sbatch SLURM_quest_mat_to_h5_mov.sh MAT_PATH H5_PATH [VAR_NAME] [DSET_NAME] [FRAMES_PER_CHUNK] [CAST_TO] [--downsample-input N] [--deflate-level N]

Positional arguments:
  MAT_PATH          Input MAT-file path
  H5_PATH           Output HDF5 file path
  VAR_NAME          MATLAB variable name (default: Y)
  DSET_NAME         HDF5 dataset name (default: /mov)
  FRAMES_PER_CHUNK  Frames per chunk (default: 200)
  CAST_TO           Output datatype, e.g. single, uint16, uint16_scaled (default: keep source type)
  FRAME_START       First frame to export (default: 1)
  FRAME_END         Last frame to export (default: full movie)
  DOWNSAMPLE_INPUT  Temporal step size; 1 keeps every frame, 2 keeps every other frame, etc. (default: 1)
  DEFLATE_LEVEL     HDF5 gzip compression level from 0-9 (default: 0)

Example:
  sbatch SLURM_quest_mat_to_h5_mov.sh \
    /path/input.mat /path/output.h5 Y /mov 200 single 1000 2000 2

  sbatch SLURM_quest_mat_to_h5_mov.sh \
    /path/input.mat /path/output.h5 Y /mov 200 single --downsample-input 2

  sbatch SLURM_quest_mat_to_h5_mov.sh \
    /path/input.mat /path/output.h5 Y /mov 200 uint16_scaled --downsample-input 2 --deflate-level 4

Notes:
  - This script expects mat_to_h5_mov_tds.m at:
    /home/jma819/EXTRACT_analysis_JJM/mat_to_h5_mov_tds.m
  - You can still override Slurm resources at submission time, e.g.:
    sbatch -A p30771 -p short --mem=40G SLURM_quest_mat_to_h5_mov.sh ...
EOF
}

POSITIONAL_ARGS=()
DOWNSAMPLE_INPUT=""
DOWNSAMPLE_EXPLICIT=0
DEFLATE_LEVEL=""
DEFLATE_EXPLICIT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --downsample-input)
      if [[ $# -lt 2 ]]; then
        echo "Error: --downsample-input requires a value." >&2
        exit 1
      fi
      DOWNSAMPLE_INPUT="$2"
      DOWNSAMPLE_EXPLICIT=1
      shift 2
      ;;
    --deflate-level)
      if [[ $# -lt 2 ]]; then
        echo "Error: --deflate-level requires a value." >&2
        exit 1
      fi
      DEFLATE_LEVEL="$2"
      DEFLATE_EXPLICIT=1
      shift 2
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        POSITIONAL_ARGS+=("$1")
        shift
      done
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"

if [[ $# -lt 2 ]]; then
  usage >&2
  exit 1
fi

MATLAB_FUNC_DIR="/home/jma819/EXTRACT_analysis_JJM"
MATLAB_FUNC_FILE="${MATLAB_FUNC_DIR}/mat_to_h5_mov_tds.m"

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
if [[ "${DOWNSAMPLE_EXPLICIT}" -eq 0 ]]; then
  DOWNSAMPLE_INPUT="${9:-1}"
  if [[ $# -ge 9 ]]; then
    DOWNSAMPLE_EXPLICIT=1
  fi
fi

if [[ "${DEFLATE_EXPLICIT}" -eq 0 ]]; then
  DEFLATE_LEVEL="${10:-0}"
  if [[ $# -ge 10 ]]; then
    DEFLATE_EXPLICIT=1
  fi
fi

matlab_quote() {
  local s="${1//\'/\'\'}"
  printf "'%s'" "$s"
}

if ! [[ "${FRAMES_PER_CHUNK}" =~ ^[0-9]+$ ]]; then
  echo "Error: FRAMES_PER_CHUNK must be an integer. Got: ${FRAMES_PER_CHUNK}" >&2
  exit 1
fi

if ! [[ "${DOWNSAMPLE_INPUT}" =~ ^[0-9]+$ ]] || [[ "${DOWNSAMPLE_INPUT}" -lt 1 ]]; then
  echo "Error: DOWNSAMPLE_INPUT must be a positive integer. Got: ${DOWNSAMPLE_INPUT}" >&2
  exit 1
fi

if ! [[ "${DEFLATE_LEVEL}" =~ ^[0-9]+$ ]] || [[ "${DEFLATE_LEVEL}" -gt 9 ]]; then
  echo "Error: DEFLATE_LEVEL must be an integer from 0 to 9. Got: ${DEFLATE_LEVEL}" >&2
  exit 1
fi

MAT_PATH_Q=$(matlab_quote "${MAT_PATH}")
H5_PATH_Q=$(matlab_quote "${H5_PATH}")
VAR_NAME_Q=$(matlab_quote "${VAR_NAME}")
DSET_NAME_Q=$(matlab_quote "${DSET_NAME}")
CAST_TO_Q=$(matlab_quote "${CAST_TO}")

MATLAB_CMD="addpath($(matlab_quote "${MATLAB_FUNC_DIR}"));"
MATLAB_CMD+=" mat_to_h5_mov_tds(${MAT_PATH_Q}, ${H5_PATH_Q}"

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
elif [[ "${DOWNSAMPLE_EXPLICIT}" -eq 1 || "${DEFLATE_EXPLICIT}" -eq 1 ]]; then
  MATLAB_CMD+=", [], []"
fi

if [[ "${DOWNSAMPLE_EXPLICIT}" -eq 1 || "${DEFLATE_EXPLICIT}" -eq 1 ]]; then
  MATLAB_CMD+=", ${DOWNSAMPLE_INPUT}"
fi

if [[ "${DEFLATE_EXPLICIT}" -eq 1 ]]; then
  MATLAB_CMD+=", ${DEFLATE_LEVEL}"
fi

MATLAB_CMD+=");"

mkdir -p logfiles

module purge
module load matlab/r2023b


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
echo "DOWNSAMPLE_INPUT=${DOWNSAMPLE_INPUT}"
echo "DEFLATE_LEVEL=${DEFLATE_LEVEL}"

matlab -batch "${MATLAB_CMD}"
