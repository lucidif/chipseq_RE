/*
 * Map reads, sort, index BAM file and run samtools stats, flagstat and idxstats
 */

include { STAR_ALIGN        } from '../../modules/local/star_align'
include { SAMTOOLS_SPLITSPECIES } from '../../modules/local/samtools/splitspecies/main'
include { BAM_SORT_SAMTOOLS } from '../nf-core/bam_sort_samtools'

workflow ALIGN_STAR {
    take:
    reads // channel: [ val(meta), [ reads ] ]
    index // channel: /path/to/star/index/

    main:

    ch_versions = Channel.empty()

    //
    // Map reads with STAR
    //
    STAR_ALIGN ( reads, index )
    ch_versions = ch_versions.mix(STAR_ALIGN.out.versions.first())
    if( params.spikein_genome ){
        SAMTOOLS_SPLITSPECIES ( //TODO run this step only in is defined a spikein species
            STAR_ALIGN.out.bam,
            params.reference_genome,
            params.spikein_genome
        )

        ch_star_out = SAMTOOLS_SPLITSPECIES.out.refbam
    } else {
        ch_star_out = STAR_ALIGN.out.bam
    }    

    //
    // Sort, index BAM file and run samtools stats, flagstat and idxstats
    //
    BAM_SORT_SAMTOOLS ( ch_star_out )
    ch_versions = ch_versions.mix(BAM_SORT_SAMTOOLS.out.versions)

    emit:
    orig_bam       = STAR_ALIGN.out.bam             // channel: [ val(meta), bam            ]
    log_final      = STAR_ALIGN.out.log_final       // channel: [ val(meta), log_final      ]
    log_out        = STAR_ALIGN.out.log_out         // channel: [ val(meta), log_out        ]
    log_progress   = STAR_ALIGN.out.log_progress    // channel: [ val(meta), log_progress   ]
    bam_sorted     = STAR_ALIGN.out.bam_sorted      // channel: [ val(meta), bam_sorted     ]
    bam_transcript = STAR_ALIGN.out.bam_transcript  // channel: [ val(meta), bam_transcript ]
    fastq          = STAR_ALIGN.out.fastq           // channel: [ val(meta), fastq          ]
    tab            = STAR_ALIGN.out.tab             // channel: [ val(meta), tab            ]

    bam            = BAM_SORT_SAMTOOLS.out.bam      // channel: [ val(meta), [ bam ] ]
    bai            = BAM_SORT_SAMTOOLS.out.bai      // channel: [ val(meta), [ bai ] ]
    stats          = BAM_SORT_SAMTOOLS.out.stats    // channel: [ val(meta), [ stats ] ]
    flagstat       = BAM_SORT_SAMTOOLS.out.flagstat // channel: [ val(meta), [ flagstat ] ]
    idxstats       = BAM_SORT_SAMTOOLS.out.idxstats // channel: [ val(meta), [ idxstats ] ]

    versions       = ch_versions                    // channel: [ versions.yml ]
}
