#!/bin/bash
#SBATCH -A p30771
#SBATCH -p gengpu
#SBATCH --gres=gpu:a100:2
#SBATCH --constraint=sxm
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --cpus-per-task=16
#SBATCH -t 04:00:00
#SBATCH -o ./logfiles/EXTRACT_analysis.%x-%j.out # STDOUT
#SBATCH --job-name="EXTRACT_analysis"
#SBATCH --mem=128G

module purge all

cd ~

#path to file 

INPUT_pathToMotionCorrectedFile=$1
INPUT_numPartitions=$2
INPUT_savePath=$3

echo $INPUT_pathToMotionCorrectedFile


# ---- new optional inputs (with defaults) ----
INPUT_avg_cell_radius="${4:-9}"
INPUT_trace_output_option="${5:-no_constraint}"   # string
INPUT_cellfind_min_snr="${6:-8}"
INPUT_T_min_snr="${7:-15}"
INPUT_dendrite_aware="${8:-0}"                   # 0 or 1

echo "file:  $INPUT_pathToMotionCorrectedFile"
echo "parts: $INPUT_numPartitions"
echo "save:  $INPUT_savePath"
echo "avg_cell_radius: $INPUT_avg_cell_radius"
echo "trace_output_option: $INPUT_trace_output_option"
echo "cellfind_min_snr: $INPUT_cellfind_min_snr"
echo "T_min_snr: $INPUT_T_min_snr"
echo "dendrite_aware: $INPUT_dendrite_aware"


#add project directory to PATH
export PATH=$PATH/projects/p30771/


#load modules to use
module load matlab/r2023b

#cd to script directory
cd /home/jma819/EXTRACT_analysis_JJM
#run analysis 

echo "Using $SLURM_CPUS_PER_TASK CPUs on GPU $CUDA_VISIBLE_DEVICES"

matlab -nosplash -nodesktop -r "addpath(genpath('/home/jma819/EXTRACT-public'));addpath(genpath('/home/jma819/EXTRACT_analysis_JJM'));nCPUs=str2double(getenv('SLURM_CPUS_PER_TASK'));maxNumCompThreads(nCPUs);filePath='$INPUT_pathToMotionCorrectedFile';num_partitions=str2double('$INPUT_numPartitions');savePath='$INPUT_savePath'; \
avg_cell_radius=str2double('$INPUT_avg_cell_radius'); \
trace_output_option='$INPUT_trace_output_option'; \
cellfind_min_snr=str2double('$INPUT_cellfind_min_snr'); \
T_min_snr=str2double('$INPUT_T_min_snr'); \
dendrite_aware=str2double('$INPUT_dendrite_aware');run('runEXTRACT_JJM_quest_takeInputs_multGPU.m');exit;"

echo 'finished analysis'
