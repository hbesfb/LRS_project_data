#!/bin/bash -u
#SBATCH --partition=sched
#SBATCH --time 240:00:00
#SBATCH --mem=2000M
#SBATCH --account=slurmrunner
#SBATCH --uid=6666
#SBATCH -o /scratch/log/manual-600-%j.log

# Asks SLURM to send the USR1 signal 120 seconds before end of the time limit
#SBATCH --signal=B:USR1@120

# --- Environment ---
DOCKER_IMAGE=registry.mgmlab.net/docker-images/nextflow-slurm:v4.1.0
INPUT_DIR=/persistent/development/600_wgs_ont_human_rare_disease/input
OUTPUT_DIR=/persistent/development/600_wgs_ont_human_rare_disease/human-variation-full/output_2025.1
PIPELINE_URL=epi2me-labs/wf-human-variation
PIPELINE_VERSION='2.4.1'
RUN=wf_human_variation_test
SCRATCH_ROOT=/scratch/wf_human_variation
RUN_ROOT=${SCRATCH_ROOT}/${SLURM_JOB_ID}

# --- Input ---
BAM=${INPUT_DIR}/giab_2025.1/HG002/PAW71238/calls.sorted.bam
#REF=/persistent/development/reference/GCA_000001405.15_GRCh38_no_alt_analysis_set/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna
REF=/persistent/development/reference/GRCh38_GIABv3_no_alt_analysis_set_maskedGRC_decoys_MAP2K3_KMT2C_KCNJ18/GRCh38_GIABv3_no_alt_analysis_set_maskedGRC_decoys_MAP2K3_KMT2C_KCNJ18.fasta.gz

# Function to post failed message to psr
# and exit with 1
function term_handler() {
    #curl -X POST {{ psrUrl }}/{{ .UID }}/failed
    # Untrap before exiting to avoid term handler being called at exit
    trap - EXIT
    exit 1
}

# Detect timeout or scancel
# and run term_handler if they are detected
trap term_handler EXIT

if [ -z "$DOCKER_IMAGE" ]
then
    echo "DOCKER_IMAGE is empty"
    term_handler
fi

# --- Command ---
docker run --rm  -v /run/munge:/run/munge:ro -v /etc/munge:/etc/munge:ro -v /etc/slurm-llnl:/etc/slurm-llnl:ro \
        -e NXF_SCM_FILE="/scratch/nallo/scm" -e NXF_WORK="${RUN_ROOT}/work" -e NXF_HOME="${RUN_ROOT}/.nextflow"  -w "${RUN_ROOT}" \
        -v /scratch:/scratch -v /persistent:/persistent \
	--network host --security-opt seccomp=unconfined "$DOCKER_IMAGE"  \
	nextflow run ${PIPELINE_URL} -r prerelease -resume -profile standard -process.executor=slurm -process.queue=high \
		--bam ${BAM} \
		--ref ${REF} \
		--snp \
		--sv \
		--mod \
		--str \
		--phased \
		--out_dir ${OUTPUT_DIR} \
		--override_basecaller_cfg dna_r10.4.1_e8.2_400bps_hac@v5.0.0

if [ $? -ne 0 ]
then
    term_handler
fi

# Sleep for a minute
trap - EXIT
sleep 300 &
wait


