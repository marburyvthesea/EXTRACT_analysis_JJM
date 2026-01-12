#!/bin/bash
#SBATCH -A p30771
#SBATCH -p gengpu
#SBATCH --gres=gpu:a100:1
#SBATCH --constraint=sxm
#SBATCH -N 1
#SBATCH --cpus-per-task=10
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

#add project directory to PATH
export PATH=$PATH/projects/p30771/


#load modules to use
module load matlab/r2023b

#cd to script directory
cd /home/jma819/EXTRACT_analysis_JJM
#run analysis 

echo "Using $SLURM_CPUS_PER_TASK CPUs on GPU $CUDA_VISIBLE_DEVICES"

matlab -nosplash -nodesktop -r "addpath(genpath('/home/jma819/EXTRACT-public'));addpath(genpath('/home/jma819/EXTRACT_analysis_JJM'));nCPUs=str2double(getenv('SLURM_CPUS_PER_TASK'));maxNumCompThreads(nCPUs);filePath='$INPUT_pathToMotionCorrectedFile';num_partitions='$INPUT_numPartitions';savePath='$INPUT_savePath';run('runEXTRACT_JJM_quest_YZ_328.m');exit;"

echo 'finished analysis'
