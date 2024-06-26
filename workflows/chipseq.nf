/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Modify fasta channel to include meta data
if (params.fasta) { ch_fasta =  Channel.fromPath(params.fasta) } else { exit 1, 'Fasta reference genome not specified!' }
ch_fasta_meta = ch_fasta.map{ it -> [[id:it[0].baseName], it] }.collect()
//ch_fasta_meta.view()

def valid_params = [
    aligners       : [ 'bwa', 'bowtie2', 'chromap', 'star' ]
]

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowChipseq.initialise(params, log, valid_params)

// Check input path parameters to see if they exist
def checkPathParamList = [
    params.input, params.multiqc_config,
    params.fasta,
    params.gtf, params.gff, params.gene_bed,
    params.bwa_index, params.bowtie2_index, params.chromap_index, params.star_index,
    params.blacklist,
    params.bamtools_filter_pe_config, params.bamtools_filter_se_config
]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

// Save AWS IGenomes file containing annotation version
def anno_readme = params.genomes[ params.genome ]?.readme
if (anno_readme && file(anno_readme).exists()) {
    file("${params.outdir}/genome/").mkdirs()
    file(anno_readme).copyTo("${params.outdir}/genome/")
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

// JSON files required by BAMTools for alignment filtering
ch_bamtools_filter_se_config = file(params.bamtools_filter_se_config, checkIfExists: true)
ch_bamtools_filter_pe_config = file(params.bamtools_filter_pe_config, checkIfExists: true)

// Header files for MultiQC
ch_spp_nsc_header           = file("$projectDir/assets/multiqc/spp_nsc_header.txt", checkIfExists: true)
ch_spp_rsc_header           = file("$projectDir/assets/multiqc/spp_rsc_header.txt", checkIfExists: true)
ch_spp_correlation_header   = file("$projectDir/assets/multiqc/spp_correlation_header.txt", checkIfExists: true)
ch_peak_count_header        = file("$projectDir/assets/multiqc/peak_count_header.txt", checkIfExists: true)
ch_frip_score_header        = file("$projectDir/assets/multiqc/frip_score_header.txt", checkIfExists: true)
ch_peak_annotation_header   = file("$projectDir/assets/multiqc/peak_annotation_header.txt", checkIfExists: true)
ch_deseq2_pca_header        = file("$projectDir/assets/multiqc/deseq2_pca_header.txt", checkIfExists: true)
ch_deseq2_clustering_header = file("$projectDir/assets/multiqc/deseq2_clustering_header.txt", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { BEDTOOLS_GENOMECOV                  } from '../modules/local/bedtools_genomecov'
include { FRIP_SCORE                          } from '../modules/local/frip_score'
include { PLOT_MACS2_QC                       } from '../modules/local/plot_macs2_qc'
include { PLOT_HOMER_ANNOTATEPEAKS            } from '../modules/local/plot_homer_annotatepeaks'
include { MACS2_CONSENSUS                     } from '../modules/local/macs2_consensus'
include { ANNOTATE_BOOLEAN_PEAKS              } from '../modules/local/annotate_boolean_peaks'
include { DESEQ2_QC                           } from '../modules/local/deseq2_qc'
include { IGV                                 } from '../modules/local/igv'
include { MULTIQC                             } from '../modules/local/multiqc'
include { MULTIQC_CUSTOM_PHANTOMPEAKQUALTOOLS } from '../modules/local/multiqc_custom_phantompeakqualtools'
include { MULTIQC_CUSTOM_PEAKS                } from '../modules/local/multiqc_custom_peaks'

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK         } from '../subworkflows/local/input_check'
include { PREPARE_GENOME      } from '../subworkflows/local/prepare_genome'
include { FILTER_BAM_BAMTOOLS } from '../subworkflows/local/filter_bam_bamtools'
include { ALIGN_BOWTIE2          } from '../subworkflows/local/align_bowtie2'
include { ALIGN_STAR                          } from '../subworkflows/local/align_star'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//

include { PICARD_MERGESAMFILES          } from '../modules/nf-core/modules/picard/mergesamfiles/main'
include { PICARD_COLLECTMULTIPLEMETRICS } from '../modules/nf-core/modules/picard/collectmultiplemetrics/main'
include { PRESEQ_LCEXTRAP               } from '../modules/nf-core/modules/preseq/lcextrap/main'
include { PHANTOMPEAKQUALTOOLS          } from '../modules/nf-core/modules/phantompeakqualtools/main'
include { UCSC_BEDGRAPHTOBIGWIG         } from '../modules/nf-core/modules/ucsc/bedgraphtobigwig/main'
include { UCSC_BEDGRAPHTOBIGWIG  as RAW_UCSC_BEDGRAPHTOBIGWIG } from '../modules/nf-core/modules/ucsc/bedgraphtobigwig/main'
include { DEEPTOOLS_COMPUTEMATRIX       } from '../modules/nf-core/modules/deeptools/computematrix/main'
include { DEEPTOOLS_PLOTPROFILE         } from '../modules/nf-core/modules/deeptools/plotprofile/main'
include { DEEPTOOLS_PLOTHEATMAP         } from '../modules/nf-core/modules/deeptools/plotheatmap/main'
include { DEEPTOOLS_PLOTFINGERPRINT     } from '../modules/nf-core/modules/deeptools/plotfingerprint/main'
include { KHMER_UNIQUEKMERS             } from '../modules/nf-core/modules/khmer/uniquekmers/main'
include { MACS2_CALLPEAK                } from '../modules/nf-core/modules/macs2/callpeak/main'
include { SUBREAD_FEATURECOUNTS         } from '../modules/nf-core/modules/subread/featurecounts/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS   } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'
include { SAMTOOLS_FAIDX                } from '../modules/nf-core/modules/samtools/faidx/main'
include { SAMTOOLS_INDEX                } from '../modules/nf-core/modules/samtools/index/main'
include { DEEPTOOLS_BAMCOVERAGE         } from '../modules/nf-core/modules/deeptools/bamcoverage/main'

include { HOMER_ANNOTATEPEAKS as HOMER_ANNOTATEPEAKS_MACS2     } from '../modules/nf-core/modules/homer/annotatepeaks/main'
include { HOMER_ANNOTATEPEAKS as HOMER_ANNOTATEPEAKS_CONSENSUS } from '../modules/nf-core/modules/homer/annotatepeaks/main'

//
// SUBWORKFLOW: Consisting entirely of nf-core/modules
//

include { FASTQC_TRIMGALORE      } from '../subworkflows/nf-core/fastqc_trimgalore'
include { ALIGN_BWA_MEM          } from '../subworkflows/nf-core/align_bwa_mem'
//include { ALIGN_BOWTIE2          } from '../subworkflows/nf-core/align_bowtie2'
include { ALIGN_CHROMAP          } from '../subworkflows/nf-core/align_chromap'
//include { ALIGN_STAR             } from '../subworkflows/nf-core/align_star'
include { MARK_DUPLICATES_PICARD } from '../subworkflows/nf-core/mark_duplicates_picard'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow CHIPSEQ {

    ch_versions = Channel.empty()


    SAMTOOLS_FAIDX (
            ch_fasta_meta,
            [[], []]
        )

    //ch_fasta_meta.set{faidx_path}
    //ch_fasta_meta.view()
    SAMTOOLS_FAIDX.out.fai.map{meta,path -> [path]}.set{faidx_path}


    //
    // SUBWORKFLOW: Uncompress and prepare reference genome files
    //
    //TODO inside this add if condition, if there is only ref gtf, fasta and index map only on that reference
    PREPARE_GENOME (
        params.aligner
    )
    ch_versions = ch_versions.mix(PREPARE_GENOME.out.versions)

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        file(params.input),
        params.seq_center
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    //
    // SUBWORKFLOW: Read QC and trim adapters
    //
    FASTQC_TRIMGALORE (
        INPUT_CHECK.out.reads,
        params.skip_fastqc || params.skip_qc,
        params.skip_trimming
    )
    ch_versions = ch_versions.mix(FASTQC_TRIMGALORE.out.versions)

    //
    // SUBWORKFLOW: Alignment with BWA & BAM QC
    //
    ch_genome_bam        = Channel.empty()
    ch_genome_bam_index  = Channel.empty()
    ch_samtools_stats    = Channel.empty()
    ch_samtools_flagstat = Channel.empty()
    ch_samtools_idxstats = Channel.empty()
    if (params.aligner == 'bwa') {
        ALIGN_BWA_MEM (
            FASTQC_TRIMGALORE.out.reads,
            PREPARE_GENOME.out.bwa_index
        )
        ch_genome_bam        = ALIGN_BWA_MEM.out.bam
        ch_genome_bam_index  = ALIGN_BWA_MEM.out.bai
        ch_samtools_stats    = ALIGN_BWA_MEM.out.stats
        ch_samtools_flagstat = ALIGN_BWA_MEM.out.flagstat
        ch_samtools_idxstats = ALIGN_BWA_MEM.out.idxstats
        ch_versions = ch_versions.mix(ALIGN_BWA_MEM.out.versions.first())
    }

    //
    // SUBWORKFLOW: Alignment with Bowtie2 & BAM QC
    //
    if (params.aligner == 'bowtie2') {
        ch_bowtie2_index = [ [:], file(params.bowtie2_spikeref_index) ]
        ALIGN_BOWTIE2 (
            FASTQC_TRIMGALORE.out.reads,
            //PREPARE_GENOME.out.bowtie2_index, //TODO ho messo direttamente l'index da parametro senza passare per prepare genome, va fatto meglio
            ch_bowtie2_index,
            params.save_unaligned
        )
        ch_genome_bam        = ALIGN_BOWTIE2.out.bam
        ch_genome_bam_index  = ALIGN_BOWTIE2.out.bai
        ch_samtools_stats    = ALIGN_BOWTIE2.out.stats
        ch_samtools_flagstat = ALIGN_BOWTIE2.out.flagstat
        ch_samtools_idxstats = ALIGN_BOWTIE2.out.idxstats
        ch_versions = ch_versions.mix(ALIGN_BOWTIE2.out.versions.first())
    }

    //
    // SUBWORKFLOW: Alignment with Chromap & BAM QC
    //
    if (params.aligner == 'chromap') {
        ALIGN_CHROMAP (
            FASTQC_TRIMGALORE.out.reads,
            PREPARE_GENOME.out.chromap_index,
            PREPARE_GENOME.out.fasta
        )

        // Filter out paired-end reads until the issue below is fixed
        // https://github.com/nf-core/chipseq/issues/291
        // ch_genome_bam = ALIGN_CHROMAP.out.bam
        ALIGN_CHROMAP
            .out
            .bam
            .branch {
                meta, bam ->
                    single_end: meta.single_end
                        return [ meta, bam ]
                    paired_end: !meta.single_end
                        return [ meta, bam ]
            }
            .set { ch_genome_bam_chromap }

        ch_genome_bam_chromap
            .paired_end
            .collect()
            .map { 
                it ->
                    def count = it.size()
                    if (count > 0) {
                        log.warn "=============================================================================\n" +
                        "  Paired-end files produced by chromap cannot be used by some downstream tools due to the issue below:\n" +
                        "  https://github.com/nf-core/chipseq/issues/291\n" +
                        "  They will be excluded from the analysis. Consider using a different aligner\n" +
                        "==================================================================================="
                    }
            }

        ch_genome_bam        = ch_genome_bam_chromap.single_end
        ch_genome_bam_index  = ALIGN_CHROMAP.out.bai
        ch_samtools_stats    = ALIGN_CHROMAP.out.stats
        ch_samtools_flagstat = ALIGN_CHROMAP.out.flagstat
        ch_samtools_idxstats = ALIGN_CHROMAP.out.idxstats
        ch_versions = ch_versions.mix(ALIGN_CHROMAP.out.versions.first())
    }

    //
    // SUBWORKFLOW: Alignment with STAR & BAM QC
    //
    if (params.aligner == 'star') {
        // ALIGN_STAR (
        //     FASTQC_TRIMGALORE.out.reads,
        //     PREPARE_GENOME.out.star_index
        // )
        //TODO if spikein species not specified try alligment on ref 

        if( params.spikein_genome ){
            ch_star_idx=PREPARE_GENOME.out.star_spikein_ref_index
        }else{
            ch_star_idx=PREPARE_GENOME.out.star_index
        }

        
        ALIGN_STAR (
            FASTQC_TRIMGALORE.out.reads,
            ch_star_idx
        )

        ch_genome_bam        = ALIGN_STAR.out.bam
        ch_genome_bam_index  = ALIGN_STAR.out.bai
        ch_transcriptome_bam = ALIGN_STAR.out.bam_transcript
        ch_samtools_stats    = ALIGN_STAR.out.stats
        ch_samtools_flagstat = ALIGN_STAR.out.flagstat
        ch_samtools_idxstats = ALIGN_STAR.out.idxstats
        ch_star_multiqc      = ALIGN_STAR.out.log_final
        //= ALIGN_STAR.out.star_spikein_ref_index

        ch_versions = ch_versions.mix(ALIGN_STAR.out.versions)
    }

    //
    // MODULE: Merge resequenced BAM files
    //
    ch_genome_bam
        .map {
            meta, bam ->
                def meta_clone = meta.clone()
                meta_clone.remove('read_group')
                meta_clone.id = meta_clone.id.split('_')[0..-2].join('_')
                [ meta_clone, bam ] 
        }
        .groupTuple(by: [0])
        .map { 
            it ->
                [ it[0], it[1].flatten() ] 
        }
        .set { ch_sort_bam }

    PICARD_MERGESAMFILES (
        ch_sort_bam
    )
    ch_versions = ch_versions.mix(PICARD_MERGESAMFILES.out.versions.first().ifEmpty(null))

    //
    // SUBWORKFLOW: Mark duplicates & filter BAM files after merging
    //
    MARK_DUPLICATES_PICARD (
        PICARD_MERGESAMFILES.out.bam
    )
    ch_versions = ch_versions.mix(MARK_DUPLICATES_PICARD.out.versions)

    //
    // SUBWORKFLOW: Filter BAM file with BamTools
    //

    //
    // FILTER DISABLE
    //
    if(params.filters_disable){
        ch_bam_to_analyze = MARK_DUPLICATES_PICARD.out.bam
        ch_flagstats_to_analyze = MARK_DUPLICATES_PICARD.out.flagstat
        ch_stats_to_analyze = MARK_DUPLICATES_PICARD.out.stats
        ch_idxstats_to_analyze = MARK_DUPLICATES_PICARD.out.idxstats
    }else{
        FILTER_BAM_BAMTOOLS (
        MARK_DUPLICATES_PICARD.out.bam.join(MARK_DUPLICATES_PICARD.out.bai, by: [0]),
        PREPARE_GENOME.out.filtered_bed.first(),
        ch_bamtools_filter_se_config,
        ch_bamtools_filter_pe_config
    )

    ch_versions = ch_versions.mix(FILTER_BAM_BAMTOOLS.out.versions.first().ifEmpty(null))
    ch_bam_to_analyze = FILTER_BAM_BAMTOOLS.out.bam
    ch_flagstats_to_analyze = FILTER_BAM_BAMTOOLS.out.flagstat
    ch_stats_to_analyze = FILTER_BAM_BAMTOOLS.out.stats
    ch_idxstats_to_analyze = FILTER_BAM_BAMTOOLS.out.idxstats
    }


    //
    // MODULE: Preseq coverage analysis
    //
    ch_preseq_multiqc = Channel.empty()
    if (!params.skip_preseq) {
        PRESEQ_LCEXTRAP (
            MARK_DUPLICATES_PICARD.out.bam
        )
        ch_preseq_multiqc = PRESEQ_LCEXTRAP.out.lc_extrap
        ch_versions = ch_versions.mix(PRESEQ_LCEXTRAP.out.versions.first())
    }

    //
    // MODULE: Picard post alignment QC
    //
    ch_picardcollectmultiplemetrics_multiqc = Channel.empty()
    if (!params.skip_picard_metrics) {
        PICARD_COLLECTMULTIPLEMETRICS (
            ch_bam_to_analyze,
            PREPARE_GENOME.out.fasta,
            []
        )
        ch_picardcollectmultiplemetrics_multiqc = PICARD_COLLECTMULTIPLEMETRICS.out.metrics
        ch_versions = ch_versions.mix(PICARD_COLLECTMULTIPLEMETRICS.out.versions.first())
    }

    //
    // MODULE: Phantompeaktools strand cross-correlation and QC metrics
    //
    PHANTOMPEAKQUALTOOLS (
        ch_bam_to_analyze
    )
    ch_versions = ch_versions.mix(PHANTOMPEAKQUALTOOLS.out.versions.first())

    //
    // MODULE: MultiQC custom content for Phantompeaktools
    //
    MULTIQC_CUSTOM_PHANTOMPEAKQUALTOOLS (
        PHANTOMPEAKQUALTOOLS.out.spp.join(PHANTOMPEAKQUALTOOLS.out.rdata, by: [0]),
        ch_spp_nsc_header,
        ch_spp_rsc_header,
        ch_spp_correlation_header
    )

    //
    // MODULE: deeptools bigwig
    //

    //ch_bam_to_analyze
    //ch_bam_to_analyze.view()

    SAMTOOLS_INDEX(ch_bam_to_analyze)

    ch_deepcov=ch_bam_to_analyze.join(SAMTOOLS_INDEX.out.bai, by: [0])

    DEEPTOOLS_BAMCOVERAGE (
        ch_deepcov,
        params.fasta,
        faidx_path
    )


    //
    // MODULE: BedGraph coverage tracks
    //
    BEDTOOLS_GENOMECOV (
        ch_bam_to_analyze.join(ch_flagstats_to_analyze, by: [0])
    )
    ch_versions = ch_versions.mix(BEDTOOLS_GENOMECOV.out.versions.first())

    //
    // MODULE: BigWig coverage tracks
    //
    UCSC_BEDGRAPHTOBIGWIG (
        BEDTOOLS_GENOMECOV.out.bedgraph,
        PREPARE_GENOME.out.chrom_sizes
    )

    RAW_UCSC_BEDGRAPHTOBIGWIG (
        BEDTOOLS_GENOMECOV.out.rawbedgraph,
        PREPARE_GENOME.out.chrom_sizes
    )

    ch_versions = ch_versions.mix(UCSC_BEDGRAPHTOBIGWIG.out.versions.first())

    ch_deeptoolsplotprofile_multiqc = Channel.empty()
    if (!params.skip_plot_profile) {
        //
        // MODULE: deepTools matrix generation for plotting
        //
        DEEPTOOLS_COMPUTEMATRIX (
            UCSC_BEDGRAPHTOBIGWIG.out.bigwig,
            PREPARE_GENOME.out.gene_bed
        )
        ch_versions = ch_versions.mix(DEEPTOOLS_COMPUTEMATRIX.out.versions.first())

        //
        // MODULE: deepTools profile plots
        //
        DEEPTOOLS_PLOTPROFILE (
            DEEPTOOLS_COMPUTEMATRIX.out.matrix
        )
        ch_deeptoolsplotprofile_multiqc = DEEPTOOLS_PLOTPROFILE.out.table
        ch_versions = ch_versions.mix(DEEPTOOLS_PLOTPROFILE.out.versions.first())

        //
        // MODULE: deepTools heatmaps
        //
        DEEPTOOLS_PLOTHEATMAP (
            DEEPTOOLS_COMPUTEMATRIX.out.matrix
        )
        ch_versions = ch_versions.mix(DEEPTOOLS_PLOTHEATMAP.out.versions.first())
    }

    //
    // Create channels: [ meta, [ ip_bam, control_bam ] [ ip_bai, control_bai ] ]
    //

    if(params.filters_disable){        
        MARK_DUPLICATES_PICARD
        .out
        .bam
        .join(MARK_DUPLICATES_PICARD.out.bai, by: [0])
        .set { ch_genome_bam_bai }
    }else{
        FILTER_BAM_BAMTOOLS
        .out
        .bam
        .join(FILTER_BAM_BAMTOOLS.out.bai, by: [0])
        .set { ch_genome_bam_bai }
    }
    
    ch_genome_bam_bai
        .combine(ch_genome_bam_bai)
        .map { 
            meta1, bam1, bai1, meta2, bam2, bai2 ->
                meta1.control == meta2.id ? [ meta1, [ bam1, bam2 ], [ bai1, bai2 ] ] : null
        }
        .set { ch_ip_control_bam_bai }
    
    //
    // MODULE: deepTools plotFingerprint joint QC for IP and control
    //
    ch_deeptoolsplotfingerprint_multiqc = Channel.empty()
    if (!params.skip_plot_fingerprint) {
        DEEPTOOLS_PLOTFINGERPRINT (
            ch_ip_control_bam_bai
        )
        ch_deeptoolsplotfingerprint_multiqc = DEEPTOOLS_PLOTFINGERPRINT.out.matrix
        ch_versions = ch_versions.mix(DEEPTOOLS_PLOTFINGERPRINT.out.versions.first())
    }

    //
    // MODULE: Calculute genome size with khmer
    //
    ch_macs_gsize                     = Channel.empty()
    ch_custompeaks_frip_multiqc       = Channel.empty()
    ch_custompeaks_count_multiqc      = Channel.empty()
    ch_plothomerannotatepeaks_multiqc = Channel.empty()
    ch_subreadfeaturecounts_multiqc   = Channel.empty()
    ch_macs_gsize = params.macs_gsize
    if (!params.macs_gsize) {
        KHMER_UNIQUEKMERS (
            PREPARE_GENOME.out.fasta,
            params.read_length
        )
        ch_macs_gsize = KHMER_UNIQUEKMERS.out.kmers.map { it.text.trim() }
    }

    // Create channels: [ meta, ip_bam, control_bam ]
    ch_ip_control_bam_bai
        .map { 
            meta, bams, bais -> 
                [ meta , bams[0], bams[1] ] 
        }
        .set { ch_ip_control_bam }

    //
    // MODULE: Call peaks with MACS2
    //
    MACS2_CALLPEAK (
        ch_ip_control_bam,
        ch_macs_gsize
    )
    ch_versions = ch_versions.mix(MACS2_CALLPEAK.out.versions.first())

    //
    // Filter out samples with 0 MACS2 peaks called
    //
    MACS2_CALLPEAK
        .out
        .peak
        .filter { meta, peaks -> peaks.size() > 0 }
        .set { ch_macs2_peaks }

    // Create channels: [ meta, ip_bam, peaks ]
    ch_ip_control_bam
        .join(ch_macs2_peaks, by: [0])
        .map { 
            it -> 
                [ it[0], it[1], it[3] ] 
        }
        .set { ch_ip_bam_peaks }

    //
    // MODULE: Calculate FRiP score
    //
    FRIP_SCORE (
        ch_ip_bam_peaks
    )
    ch_versions = ch_versions.mix(FRIP_SCORE.out.versions.first())

    // Create channels: [ meta, peaks, frip ]
    ch_ip_bam_peaks
        .join(FRIP_SCORE.out.txt, by: [0])
        .map { 
            it -> 
                [ it[0], it[2], it[3] ] 
        }
        .set { ch_ip_peaks_frip }

    //
    // MODULE: FRiP score custom content for MultiQC
    //
    MULTIQC_CUSTOM_PEAKS (
        ch_ip_peaks_frip,
        ch_peak_count_header,
        ch_frip_score_header
    )
    ch_custompeaks_frip_multiqc  = MULTIQC_CUSTOM_PEAKS.out.frip
    ch_custompeaks_count_multiqc = MULTIQC_CUSTOM_PEAKS.out.count

    if (!params.skip_peak_annotation) {
        //
        // MODULE: Annotate peaks with MACS2
        //
        HOMER_ANNOTATEPEAKS_MACS2 (
            ch_macs2_peaks,
            PREPARE_GENOME.out.fasta,
            PREPARE_GENOME.out.gtf
        )
        ch_versions = ch_versions.mix(HOMER_ANNOTATEPEAKS_MACS2.out.versions.first())

        if (!params.skip_peak_qc) {
            //
            // MODULE: MACS2 QC plots with R
            //
            PLOT_MACS2_QC (
                ch_macs2_peaks.collect{it[1]}
            )
            ch_versions = ch_versions.mix(PLOT_MACS2_QC.out.versions)

            //
            // MODULE: Peak annotation QC plots with R
            //
            PLOT_HOMER_ANNOTATEPEAKS (
                HOMER_ANNOTATEPEAKS_MACS2.out.txt.collect{it[1]},
                ch_peak_annotation_header,
                "_peaks.annotatePeaks.txt"
            )
            ch_plothomerannotatepeaks_multiqc = PLOT_HOMER_ANNOTATEPEAKS.out.tsv
            ch_versions = ch_versions.mix(PLOT_HOMER_ANNOTATEPEAKS.out.versions)
        }
    }

    //
    //  Consensus peaks analysis
    //
    ch_macs2_consensus_bed_lib   = Channel.empty()
    ch_macs2_consensus_txt_lib   = Channel.empty()
    ch_deseq2_pca_multiqc        = Channel.empty()
    ch_deseq2_clustering_multiqc = Channel.empty()
    if (!params.skip_consensus_peaks) {
        // Create channels: [ meta , [ peaks ] ]
            // Where meta = [ id:antibody, multiple_groups:true/false, replicates_exist:true/false ]
        ch_macs2_peaks
            .map { 
                meta, peak -> 
                    [ meta.antibody, meta.id.split('_')[0..-2].join('_'), peak ] 
            }
            .groupTuple()
            .map {
                antibody, groups, peaks ->
                    [
                        antibody,
                        groups.groupBy().collectEntries { [(it.key) : it.value.size()] },
                        peaks
                    ] 
            }
            .map {
                antibody, groups, peaks ->
                    def meta_new = [:]
                    meta_new.id = antibody
                    meta_new.multiple_groups = groups.size() > 1
                    meta_new.replicates_exist = groups.max { groups.value }.value > 1
                    [ meta_new, peaks ] 
            }
            .set { ch_antibody_peaks }

        //
        // MODULE: Generate consensus peaks across samples
        //
        MACS2_CONSENSUS (
            ch_antibody_peaks
        )
        ch_macs2_consensus_bed_lib = MACS2_CONSENSUS.out.bed
        ch_macs2_consensus_txt_lib = MACS2_CONSENSUS.out.txt
        ch_versions = ch_versions.mix(MACS2_CONSENSUS.out.versions)

        if (!params.skip_peak_annotation) {
            //
            // MODULE: Annotate consensus peaks
            //
            HOMER_ANNOTATEPEAKS_CONSENSUS (
                MACS2_CONSENSUS.out.bed,
                PREPARE_GENOME.out.fasta,
                PREPARE_GENOME.out.gtf
            )
            ch_versions = ch_versions.mix(HOMER_ANNOTATEPEAKS_CONSENSUS.out.versions)

            //
            // MODULE: Add boolean fields to annotated consensus peaks to aid filtering
            //
            ANNOTATE_BOOLEAN_PEAKS (
                MACS2_CONSENSUS.out.boolean_txt.join(HOMER_ANNOTATEPEAKS_CONSENSUS.out.txt, by: [0]),
            )
            ch_versions = ch_versions.mix(ANNOTATE_BOOLEAN_PEAKS.out.versions)
        }

        // Create channels: [ antibody, [ ip_bams ] ]
        ch_ip_control_bam
            .map { 
                meta, ip_bam, control_bam ->
                    [ meta.antibody, ip_bam ]
            }
            .groupTuple()
            .set { ch_antibody_bams }

        // Create channels: [ meta, [ ip_bams ], saf ]
        MACS2_CONSENSUS
            .out
            .saf
            .map { 
                meta, saf -> 
                    [ meta.id, meta, saf ] 
            }
            .join(ch_antibody_bams)
            .map {
                antibody, meta, saf, bams ->
                    [ meta, bams.flatten().sort(), saf ]
            }
            .set { ch_saf_bams }

        //
        // MODULE: Quantify peaks across samples with featureCounts
        //
        SUBREAD_FEATURECOUNTS (
            ch_saf_bams
        )
        ch_subreadfeaturecounts_multiqc = SUBREAD_FEATURECOUNTS.out.summary
        ch_versions = ch_versions.mix(SUBREAD_FEATURECOUNTS.out.versions.first())

        if (!params.skip_deseq2_qc) {
            //
            // MODULE: Generate QC plots with DESeq2
            //
            DESEQ2_QC (
                SUBREAD_FEATURECOUNTS.out.counts,
                ch_deseq2_pca_header,
                ch_deseq2_clustering_header
            )
            ch_deseq2_pca_multiqc        = DESEQ2_QC.out.pca_multiqc
            ch_deseq2_clustering_multiqc = DESEQ2_QC.out.dists_multiqc
        }
    }

    //
    // MODULE: Create IGV session
    //
    if (!params.skip_igv) {
        IGV (
            params.aligner,
            params.narrow_peak ? 'narrowPeak' : 'broadPeak',
            PREPARE_GENOME.out.fasta,
            UCSC_BEDGRAPHTOBIGWIG.out.bigwig.collect{it[1]}.ifEmpty([]),
            ch_macs2_peaks.collect{it[1]}.ifEmpty([]),
            ch_macs2_consensus_bed_lib.collect{it[1]}.ifEmpty([]),
            ch_macs2_consensus_txt_lib.collect{it[1]}.ifEmpty([])
        )
        ch_versions = ch_versions.mix(IGV.out.versions)
    }

    //
    // MODULE: Pipeline reporting
    //
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    if (!params.skip_multiqc) {
        workflow_summary    = WorkflowChipseq.paramsSummaryMultiqc(workflow, summary_params)
        ch_workflow_summary = Channel.value(workflow_summary)

        MULTIQC (
            ch_multiqc_config,
            ch_multiqc_custom_config.collect().ifEmpty([]),
            CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect(),
            ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'),

            FASTQC_TRIMGALORE.out.fastqc_zip.collect{it[1]}.ifEmpty([]),
            FASTQC_TRIMGALORE.out.trim_zip.collect{it[1]}.ifEmpty([]),
            FASTQC_TRIMGALORE.out.trim_log.collect{it[1]}.ifEmpty([]),

            ch_samtools_stats.collect{it[1]}.ifEmpty([]),
            ch_samtools_flagstat.collect{it[1]}.ifEmpty([]),
            ch_samtools_idxstats.collect{it[1]}.ifEmpty([]),

            MARK_DUPLICATES_PICARD.out.stats.collect{it[1]}.ifEmpty([]),
            MARK_DUPLICATES_PICARD.out.flagstat.collect{it[1]}.ifEmpty([]),
            MARK_DUPLICATES_PICARD.out.idxstats.collect{it[1]}.ifEmpty([]),
            MARK_DUPLICATES_PICARD.out.metrics.collect{it[1]}.ifEmpty([]),

            ch_stats_to_analyze.collect{it[1]}.ifEmpty([]),
            ch_flagstats_to_analyze.collect{it[1]}.ifEmpty([]),
            ch_idxstats_to_analyze.collect{it[1]}.ifEmpty([]),
            ch_picardcollectmultiplemetrics_multiqc.collect{it[1]}.ifEmpty([]),

            ch_preseq_multiqc.collect{it[1]}.ifEmpty([]),
    
            ch_deeptoolsplotprofile_multiqc.collect{it[1]}.ifEmpty([]),
            ch_deeptoolsplotfingerprint_multiqc.collect{it[1]}.ifEmpty([]),
    
            PHANTOMPEAKQUALTOOLS.out.spp.collect{it[1]}.ifEmpty([]),
            MULTIQC_CUSTOM_PHANTOMPEAKQUALTOOLS.out.nsc.collect{it[1]}.ifEmpty([]),
            MULTIQC_CUSTOM_PHANTOMPEAKQUALTOOLS.out.rsc.collect{it[1]}.ifEmpty([]),
            MULTIQC_CUSTOM_PHANTOMPEAKQUALTOOLS.out.correlation.collect{it[1]}.ifEmpty([]),

            ch_custompeaks_frip_multiqc.collect{it[1]}.ifEmpty([]),
            ch_custompeaks_count_multiqc.collect{it[1]}.ifEmpty([]),
            ch_plothomerannotatepeaks_multiqc.collect().ifEmpty([]),
            ch_subreadfeaturecounts_multiqc.collect{it[1]}.ifEmpty([]),

            ch_deseq2_pca_multiqc.collect().ifEmpty([]),
            ch_deseq2_clustering_multiqc.collect().ifEmpty([])
        )
        multiqc_report = MULTIQC.out.report.toList()
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
