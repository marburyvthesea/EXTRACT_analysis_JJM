#!/bin/bash
#SBATCH -A p30771
#SBATCH -p normal
#SBATCH -N 1
#SBATCH --ntasks-per-node=4
#SBATCH --mem=25G
#SBATCH --time=02:00:00
#SBATCH -e ./logfiles/mat_to_h5_tds.%x-%j.err
#SBATCH -o ./logfiles/mat_to_h5_tds.%x-%j.out # STDOUT
#SBATCH --job-name="mat_to_h5"
#SBATCH --error=%x-%j.err

set -euo pipefail


usage() {
  cat <<'EOF'
Usage:
  sbatch quest_mat_to_h5_mov_tds.sbatch MAT_PATH H5_PATH [VAR_NAME] [DSET_NAME] [FRAMES_PER_CHUNK] [CAST_TO] [FRAME_START] [FRAME_END]
  sbatch SLURM_quest_mat_to_h5_mov_tds.sh MAT_PATH H5_PATH [VAR_NAME] [DSET_NAME] [FRAMES_PER_CHUNK] [CAST_TO] [FRAME_START] [FRAME_END] [DOWNSAMPLE_INPUT]
  sbatch SLURM_quest_mat_to_h5_mov_tds.sh MAT_PATH H5_PATH [VAR_NAME] [DSET_NAME] [FRAMES_PER_CHUNK] [CAST_TO] [--downsample-input N]

Positional arguments:
  MAT_PATH          Input MAT-file path
  CAST_TO           Output datatype, e.g. single, uint16 (default: keep source type)
  FRAME_START       First frame to export (default: 1)
  FRAME_END         Last frame to export (default: full movie)
  DOWNSAMPLE_INPUT  Temporal step size; 1 keeps every frame, 2 keeps every other frame, etc. (default: 1)

Example:
  sbatch quest_mat_to_h5_mov_tds.sbatch \
    /path/input.mat /path/output.h5 Y /mov 200 single 1000 2000
  sbatch SLURM_quest_mat_to_h5_mov._tdssh \
    /path/input.mat /path/output.h5 Y /mov 200 single 1000 2000 2

  sbatch SLURM_quest_mat_to_h5_mov_tds.sh \
    /path/input.mat /path/output.h5 Y /mov 200 single --downsample-input 2

Notes:
  - This script expects mat_to_h5_mov.m at:
    /Users/johnmarshall/Documents/MATLAB/EXTRACT_analysis_JJM/mat_to_h5_mov.m
  - This script expects mat_to_h5_mov_tds.m at:
    /home/jma819/EXTRACT_analysis_JJM/mat_to_h5_mov_tds.m
  - You can still override Slurm resources at submission time, e.g.:
    sbatch -A p30771 -p short --mem=40G quest_mat_to_h5_mov.sbatch ...
    sbatch -A p30771 -p short --mem=40G SLURM_quest_mat_to_h5_mov.sh ...
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi
POSITIONAL_ARGS=()
DOWNSAMPLE_INPUT=""
DOWNSAMPLE_EXPLICIT=0

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
MATLAB_FUNC_FILE="${MATLAB_FUNC_DIR}/mat_to_h5_mov.m"
MATLAB_FUNC_FILE="${MATLAB_FUNC_DIR}/mat_to_h5_mov_tds.m"

if [[ ! -f "${MATLAB_FUNC_FILE}" ]]; then
  echo "Error: cannot find ${MATLAB_FUNC_FILE}" >&2
CAST_TO="${6:-}"
FRAME_START="${7:-}"
FRAME_END="${8:-}"
if [[ "${DOWNSAMPLE_EXPLICIT}" -eq 0 ]]; then
  DOWNSAMPLE_INPUT="${9:-1}"
  if [[ $# -ge 9 ]]; then
    DOWNSAMPLE_EXPLICIT=1
  fi
fi

matlab_quote() {
  local s="${1//\'/\'\'}"
  exit 1
fi

if ! [[ "${DOWNSAMPLE_INPUT}" =~ ^[0-9]+$ ]] || [[ "${DOWNSAMPLE_INPUT}" -lt 1 ]]; then
  echo "Error: DOWNSAMPLE_INPUT must be a positive integer. Got: ${DOWNSAMPLE_INPUT}" >&2
  exit 1
fi

MAT_PATH_Q=$(matlab_quote "${MAT_PATH}")
H5_PATH_Q=$(matlab_quote "${H5_PATH}")
VAR_NAME_Q=$(matlab_quote "${VAR_NAME}")
CAST_TO_Q=$(matlab_quote "${CAST_TO}")

MATLAB_CMD="addpath($(matlab_quote "${MATLAB_FUNC_DIR}"));"
MATLAB_CMD+=" mat_to_h5_mov(${MAT_PATH_Q}, ${H5_PATH_Q}"
MATLAB_CMD+=" mat_to_h5_mov_tds(${MAT_PATH_Q}, ${H5_PATH_Q}"

if [[ $# -ge 3 ]]; then
  MATLAB_CMD+=", ${VAR_NAME_Q}"
    exit 1
  fi
  MATLAB_CMD+=", ${FRAME_START}, ${FRAME_END}"
elif [[ "${DOWNSAMPLE_EXPLICIT}" -eq 1 ]]; then
  MATLAB_CMD+=", [], []"
fi

if [[ "${DOWNSAMPLE_EXPLICIT}" -eq 1 ]]; then
  MATLAB_CMD+=", ${DOWNSAMPLE_INPUT}"
fi

MATLAB_CMD+=");"

module purge
else
  echo "FRAME_RANGE=full movie"
fi
echo "DOWNSAMPLE_INPUT=${DOWNSAMPLE_INPUT}"

matlab -batch "${MATLAB_CMD}"