/*
 * Filter BAM file
 */
process BAM_REMOVE_DUPLICATES {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::bamtools=2.5.2 bioconda::samtools=1.15.1" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-0560a8046fc82aa4338588eca29ff18edab2c5aa:5687a7da26983502d0a8a9a6b05ed727c740ddc4-0' :
        'quay.io/biocontainers/mulled-v2-0560a8046fc82aa4338588eca29ff18edab2c5aa:5687a7da26983502d0a8a9a6b05ed727c740ddc4-0' }"

    input:
    tuple val(meta), path(bam), path(bai)
    path bed


    output:
    tuple val(meta), path("*.bam"), emit: bam
    path "versions.yml"           , emit: versions

    script:
    def prefix           = task.ext.prefix ?: "${meta.id}"
    def dup_params       = params.keep_dups ? '' : '-F 0x0400'
    def blacklist_params = params.blacklist ? "-L $bed" : ''
    
    """
    samtools view \\
        $dup_params \\
        $blacklist_params \\
        -b $bam \\
        -o ${prefix}.dprm.bam 

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
        bamtools: \$(echo \$(bamtools --version 2>&1) | sed 's/^.*bamtools //; s/Part .*\$//')
    END_VERSIONS
    """
}
