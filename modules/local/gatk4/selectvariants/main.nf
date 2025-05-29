process SELECTVARIANTS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gatk4:4.5.0.0--py36hdfd78af_0':
        'biocontainers/gatk4:4.5.0.0--py36hdfd78af_0' }"

    input:
    tuple val(meta), path(input), path(vcf_idx), path(intervals), path(intervals_index)
    tuple val(meta2), path(fasta)
    tuple val(meta3), path(fai)
    tuple val(meta4), path(dict) // required if input is a GenomicsDB?

    output:
    tuple val(meta), path("*.g.vcf.gz")       , emit: gvcf
    tuple val(meta), path("*.g.vcf.gz.tbi")   , emit: gtbi
    tuple val(meta), path("$interval_list"), optional:true, emit: intervallist
    path "versions.yml"		                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def input_command = input.name.endsWith(".vcf") || input.name.endsWith(".vcf.gz") ? "$input" : "gendb://$input"
    def interval = intervals ? "--intervals ${intervals}" : ""

	interval_list = intervals ? intervals : "${prefix}.interval_list"
    def avail_mem = 3072
    if (!task.memory) {
        log.info '[GATK SelectVariants] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this.'
    } else {
        avail_mem = (task.memory.mega*0.8).intValue()
    }
    """
    # head -n 10 ${intervals} | awk '{printf("%s\\t%i\\t100000\\n", \$1, \$2)}' > foo.bed;
    cat ${intervals} > intervals.bed;
    gatk --java-options "-Xmx${avail_mem}M -XX:-UsePerfData" \\
        SelectVariants \\
        --variant $input_command \\
        --output ${prefix}.g.vcf.gz \\
        --reference $fasta \\
        --intervals intervals.bed \\
        --tmp-dir . \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gatk4: \$(echo \$(gatk --version 2>&1) | sed 's/^.*(GATK) v//; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.g.vcf.gz
    touch ${prefix}.g.vcf.gz.tbi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gatk4: \$(echo \$(gatk --version 2>&1) | sed 's/^.*(GATK) v//; s/ .*\$//')
    END_VERSIONS
    """
}
