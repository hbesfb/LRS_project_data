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
DOCKER_IMAGE=registry.mgmlab.net/docker-images/nextflow-slurm:v3.0.0
INPUT_DIR=/persistent/development/600_wgs_ont_human_rare_disease/input/GRCh37_run
OUTPUT_DIR=/persistent/development/600_wgs_ont_human_rare_disease/output
PIPELINE_URL=genomic-medicine-sweden/nallo
PIPELINE_VERSION='0.2.0'
RUN=GRCh37_no_annotation_rank
SCRATCH_ROOT=/scratch/nallo
RUN_ROOT=${SCRATCH_ROOT}/${SLURM_JOB_ID}

# --- Input ---
SAMPLESHEET=${INPUT_DIR}/samplesheet.csv
REF=/persistent/diagnostic/reference/g1k_v37/human_g1k_v37.fasta
SOMALIER_SITES=${INPUT_DIR}/sites.GRCh37.vcf.gz
PAR_REGIONS=${INPUT_DIR}/GRCh37_PAR.bed
CNV_XY=${INPUT_DIR}/expected_cn.hg19.XY.bed
CNV_XX=${INPUT_DIR}/expected_cn.hg19.XX.bed
CNV_EX=${INPUT_DIR}/cnv.excluded_regions.hg19.bed.gz
#TRGT_REPEATS=${INPUT_DIR}/hg19.STRchive-disease-loci.TRGT.bed
VARIANT_CATALOG=${INPUT_DIR}/variant_catalog_grch37.json
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
        nextflow run ${PIPELINE_URL} -r ${PIPELINE_VERSION} -resume -profile docker -process.executor=slurm -process.queue=low \
        	--input ${SAMPLESHEET} \
		--fasta ${REF} --somalier_sites ${SOMALIER_SITES} \
		--par_regions ${PAR_REGIONS} \
		--hificnv_xy ${CNV_XY} --hificnv_xx ${CNV_XX} --hificnv_exclude ${CNV_EX} \
		--variant_catalog ${VARIANT_CATALOG} \
		--preset ONT_R10 \
		--outdir "${OUTPUT_DIR}/${RUN}" \
		--skip_assembly_wf --skip_call_paralogs --skip_methylation_wf --skip_repeat_wf --skip_snv_annotation --skip_sv_annotation --skip_rank_variants

if [ $? -ne 0 ]
then
    term_handler
fi

# Sleep for a minute
trap - EXIT
sleep 300 &
wait


