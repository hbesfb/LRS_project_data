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
OUTPUT_DIR=/persistent/development/600_wgs_ont_human_rare_disease/output_0.7.0
PIPELINE_URL=genomic-medicine-sweden/nallo
PIPELINE_VERSION='0.7.0'
RUN=test_0.7.0_out
SCRATCH_ROOT=/scratch/nallo
RUN_ROOT=${SCRATCH_ROOT}/${SLURM_JOB_ID}

# --- Input ---
SAMPLESHEET=${INPUT_DIR}/samplesheet.csv
REF=/persistent/development/reference/GCA_000001405.15_GRCh38_no_alt_analysis_set/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna
SOMALIER_SITES=${INPUT_DIR}/sites.hg38.vcf.gz
PAR_REGIONS=${INPUT_DIR}/GRCh38_PAR.bed
CNV_XY=${INPUT_DIR}/expected_cn.hg38.XY.bed
CNV_XX=${INPUT_DIR}/expected_cn.hg38.XX.bed
CNV_EX=${INPUT_DIR}/cnv.excluded_regions.hg38.bed.gz
TRGT_REPEATS=${INPUT_DIR}/pathogenic_repeats.hg38.bed
VARIANT_CATALOG=${INPUT_DIR}/variant_catalog_grch38.json
VEP_CACHE=${INPUT_DIR}/vep_cache
VEP_PLUGINS=${INPUT_DIR}/vep_plugins.csv
SNP_DB=${INPUT_DIR}/snp_db.csv
VAR_CONSEQUENCES=${INPUT_DIR}/variant_consequences_v2.txt
SCORE_SNV=${INPUT_DIR}/rank_model_snv.ini
REDUCED_PENETRANCE=${INPUT_DIR}/reduced_penetrance.tsv

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
        -v /scratch:/scratch -v /persistent:/persistent --network host --security-opt seccomp=unconfined "$DOCKER_IMAGE" \
        nextflow run /scratch/nallo/fork/nallo -resume -profile docker -process.executor=slurm -process.queue=high \
		--input ${SAMPLESHEET} \
		--fasta ${REF} --somalier_sites ${SOMALIER_SITES} \
		--par_regions ${PAR_REGIONS} \
		--hificnv_expected_xy_cn ${CNV_XY} --hificnv_expected_xx_cn ${CNV_XX} --hificnv_excluded_regions ${CNV_EX} \
		--str_bed ${TRGT_REPEATS} --str_caller trgt \
		--skip_repeat_annotation --skip_snv_annotation --skip_rank_variants --skip_sv_annotation --skip_rank_variants \
		--outdir "${OUTPUT_DIR}/${RUN}"


if [ $? -ne 0 ]
then
    term_handler
fi

# Sleep for a minute
trap - EXIT
sleep 300 &
wait


