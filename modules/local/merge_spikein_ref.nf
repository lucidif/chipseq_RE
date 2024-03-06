process MERGE_SPIKEIN_REF {

    input:
    path fasta_ref
    path fasta_spike
    path gtf_ref
    path gtf_spike

    output:
    path '${refname}_${spikename}'       , emit: fasta
    path '${refname}_${spikename}.gtf'       , emit: gtf

    script:

        refname=params.reference_genome
        spikename=params.spikein_genome


        """

        cat ${fasta_ref} | sed -r 's/(chr)/${refname}_\\1/g' > ${refname}_rename.fa
        cat ${fasta_spike} | sed -r 's/(chr)/${spikename}_\\1/g' > ${spikename}_rename.fa
        cat ${refname}_rename.fa ${spikename}_rename.fa > ${refname}_${spikename}.fa

        cat ${gtf_ref} | sed -e 's/(chr)/${refname}_/g' > ${refname}_rename.gtf 
        cat ${gtf_spike} | sed -e 's/(chr)/${spikename}_/g' > ${spikename}_rename.gtf
        cat ${refname}_rename.gtf ${spikename}_rename.gtf > ${refname}_${spikename}.gtf
 
        """


}