#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

log.info "-------------------------------------------"
log.info "Fix and split DBL"
log.info "-------------------------------------------"
log.info " (no ocr/normalisation/ticcl!)"

def env = System.getenv()

params.virtualenv =  env.containsKey('VIRTUAL_ENV') ? env['VIRTUAL_ENV'] : ""
params.extension = "xml"

if (params.containsKey('help') || !params.containsKey('inputdir') || !params.containsKey('outputdir') || !params.containsKey('datadir')) {
    log.info "Usage:"
    log.info "  dbnl_fix_and_split.nf [OPTIONS]"
    log.info ""
    log.info "Mandatory parameters:"
    log.info "  --inputdir DIRECTORY     Input directory (FoLiA documents)"
    log.info "  --outputdir DIRECTORY    Output directory"
    log.info "  --datadir DIRECTORY      Directory where the inl/nederlab-linguistic-enrichment repository is cloned"
    log.info "Optional parameters:"
    log.info "  --extension STR          Extension of documents in input directory (default: xml)"
    log.info ""
}

println "Reading documents from " + params.inputdir + "/**." + params.extension
inputdocuments = Channel.fromPath(params.inputdir+"/**." + params.extension)
inputdocuments_test = Channel.fromPath(params.inputdir+"/**." + params.extension)
println "Found " + inputdocuments_test.count().val + " input documents"

process fix {
        input:
        file inputdocument from inputdocuments
        val datadir from params.datadir
        val virtualenv from params.virtualenv

        output:
        file "${inputdocument.simpleName}.fixed.folia.xml" into fixeddocuments

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        mkdir -p out
        python3 \$LM_PREFIX/opt/nederlab-pipeline/scripts/dbnl/dbnl_ozt_fix.py -d ${datadir} -O out/ ${inputdocument} || exit 1
        mv out/*xml ${inputdocument.simpleName}.fixed.folia.xml || exit 1
        """
}

process split {
        publishDir params.outputdir, mode: 'copy', overwrite: true, pattern: "*_????.folia.xml"

        input:
        file inputdocument from fixeddocuments
        val virtualenv from params.virtualenv

        output:
        file "*_????.folia.xml" into splitdocuments mode flatten

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        foliasplit -q div --submetadata --external ${inputdocument}
        """
}

process compress {
        input:
        file inputdocument from splitdocuments

        output:
        file "${inputdocument}.gz" into outputdocuments

        script:
        """
        gzip -c -k \$(realpath ${inputdocument}) > ${inputdocument}.gz
        """
}

outputdocuments
    .subscribe { println "Outputted ${it.name}" }
