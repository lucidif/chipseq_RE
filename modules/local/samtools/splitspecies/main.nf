process SAMTOOLS_SPLITSPECIES {
    tag "$meta.id"
    label 'process_low'

    // conda "${moduleDir}/environment.yml"
    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //     'https://depot.galaxyproject.org/singularity/samtools:1.18--h50ea8bc_1' :
    //     'quay.io/biocontainers/samtools:1.18--h50ea8bc_1' }"
    conda (params.enable_conda ? "bioconda::samtools=1.15.1" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0' :
        'quay.io/biocontainers/samtools:1.15.1--h1170115_0' }"

    //if workflow don't find the docker image sudo docker pull quay.io/biocontainers/samtools:1.18--h50ea8bc_1 TODO risolvi il problema al primo aggiornamento stabile che fanno (in cui dovrebbero passare a samtools 1.18)   

    input:
    tuple val(meta), path(input)
    val ref_name
    val spikein_name

    //tuple val(meta2), path(fasta)


    output:
    tuple val(meta), path("*_${ref_name}.bam"), path("*_${ref_name}.bam.bai") ,  emit: refbambai
    tuple val(meta), path("*_${spikein_name}.bam"), path("*_${spikein_name}.bam.bai") ,  emit: spikebambai
    //tuple val(meta), path("*_${ref_name}.bam"), path("*_${spikein_name}.bam") ,  emit: allbam
    tuple val(meta), path("*_${ref_name}.bam") ,  emit: refbam
    //tuple val(meta), path("*_${ref_name}.bam.bai"), path("*_${spikein_name}.bam.bai"), emit : bai
    //tuple val(meta), path("*_${ref_name}.bam"), path("*_${ref_name}.bam.bai"), emit: refpath
    //tuple val(meta), path("*_${spikein_name}.bam"), path("*_${spikein_name}.bam.bai"), emit: spikepath

    path  "versions.yml",            emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    //def args = task.ext.args ?: ''
    //def args2 = task.ext.args2 ?: ''
    //def prefix = task.ext.prefix ?: "${meta.id}"
    //def reference = fasta ? "--reference ${fasta}" : ""
    //def readnames = qname ? "--qname-file ${qname}": ""
    // def file_type = args.contains("--output-fmt sam") ? "sam" :
    //                 args.contains("--output-fmt bam") ? "bam" :
    //                 args.contains("--output-fmt cram") ? "cram" :
    //                 input.getExtension()
    //def filter_params    = meta.single_end ? '-F 0x004' : '-F 0x004 -F 0x0008 -f 0x001'


    """

    samtools \\
        view \\
        --threads ${task.cpus-1} \\
        -h \\
        ${input} | grep -v ${spikein_name} | sed s/${ref_name}\\_chr/chr/g | samtools view -bhS - > ${meta.id}_${ref_name}.bam

    samtools \\
        view \\
        --threads ${task.cpus-1} \\
        -h \\
        ${input} | grep -v ${ref_name} | sed s/${spikein_name}\\_chr/chr/g | samtools view -bhS - > ${meta.id}_${spikein_name}.bam 

    samtools index ${meta.id}_${ref_name}.bam ${meta.id}_${ref_name}.bam.bai
    samtools index ${meta.id}_${spikein_name}.bam ${meta.id}_${spikein_name}.bam.bai

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """

    stub:

    """
    touch ${meta.id}.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}
