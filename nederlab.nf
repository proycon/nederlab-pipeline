#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

log.info "-------------------------------------------"
log.info "Nederlab Linguistic Enrichment Pipeline"
log.info "-------------------------------------------"
log.info " (no OCR/normalisation/TICCL!)"

def env = System.getenv()

params.virtualenv =  env.containsKey('VIRTUAL_ENV') ? env['VIRTUAL_ENV'] : ""
params.language = "nld-historical"
params.extension = "xml"
params.outputdir = "nederlab_output"
params.skip = "mcpa"
params.oztids = "data/dbnl_ozt_ids.txt"
params.wikiente = false
params.spotlight = "http://127.0.0.1:2222/rest/"
params.metadatadir = ""
params.mode = "simple"
params.dolangid = false
params.uselangid = false
params.tei = false
params.tok = false
params.workers = Runtime.runtime.availableProcessors()
params.frogconfig = ""
params.recursive = false
params.outreport = "./foliavalidation.report"
params.outsummary = "./foliavalidation.summary"
params.detectlanguages = "nld,nld-vnn,dum,eng,deu,lat,swe,dan,fra,spa,ita,por,rus,tur,fas,ara"
params.langthreshold = "1.0"
params.frogerrors = "terminate"
if (env.containsKey('LM_PREFIX')) {
    params.preservation =  env['LM_PREFIX']  + "/opt/nederlab-pipeline/resources/preservation2010.txt"
    params.rules =  env['LM_PREFIX']  + "/opt/nederlab-pipeline/resources/rules.machine"
} else {
    params.preservation = "/dev/null"
    params.rules = "/dev/null"
}


if (params.containsKey('help') || !params.containsKey('inputdir') ) {
    log.info "Usage:"
    log.info "  nederlab.nf [OPTIONS]"
    log.info ""
    log.info "Mandatory parameters:"
    log.info "  --inputdir DIRECTORY     Input directory (FoLiA documents or TEI documents if --tei is set)"
    log.info ""
    log.info "Optional parameters:"
    log.info "  --mode [modernize|simple|convert]  Add modernisation layer, process original content immediately (simple), Or convert to FoLiA only (used with --tei)? Default: simple"
    log.info "  --dictionary FILE        Modernisation dictionary (required for modernize mode)"
    log.info "  --inthistlexicon FILE    INT Historical Lexicon dump file (required for modernize mode)"
    log.info "  --workers NUMBER         The number of workers (e.g. frogs) to run in parallel; input will be divided into this many batches"
    log.info "  --tei                    Input TEI XML instead of FoLiA (adds a conversion step), this https://www.tei-c.org/release/doc/tei-p5-doc/en/html/ref-encodingc.html"
    log.info "  --tok                    FoLiA Input is not tokenised yet, do so (adds a tokenisation step)"
    log.info "  --recursive              Process input directory recursively (make sure it's not also your current working directory or weird recursion may ensue)"
    log.info "  --inthistlexicon FILE    INT historical lexicon"
    log.info "  --preservation FILE      Preservation lexicon (list of words that will not be processed by the rules)"
    log.info "  --rules FILE             Substitution rules"
    log.info "  --outputdir DIRECTORY    Output directory (FoLiA documents)"
    log.info "  --metadatadir DIRECTORY  Directory including JSON metadata (one file matching each input document), needs to be an absolute path"
    log.info "  --language LANGUAGE      Language"
    log.info "  --frogconfig FILE        Path to frog.cfg (or using the default if not set)"
    log.info "  --frogerrors             How to handle errors during frogging. Set to terminate  (default) or ignore.
    log.info "  --oztids FILE            List of IDs for DBNL onzelfstandige titels (default: data/dbnl_ozt_ids.txt)"
    log.info "  --extension STR          Extension of TEI documents in input directory (default: xml)"
    log.info "  --skip=[mptncla]         Skip Tokenizer (t), Lemmatizer (l), Morphological Analyzer (a), Chunker (c), Multi-Word Units (m), Named Entity Recognition (n), or Parser (p)  (default: mcpa)"
    log.info "  --dolangid               Do language identification"
    log.info "  --detectlanguages        Languages to consider in language identification (iso-639-3 codes, comma separated list)"
    log.info "  --langthreshold          Confidence threshold in language detection"
    log.info "  --uselangid              Take language identification into account (does not perform identification but takes already present identification into account!)"
    log.info "  --wikiente               Run WikiEnte for Name Entity Recognition and entity linking"
    log.info "  --spotlight URL          URL to spotlight server (should end in rest/, defaults to http://127.0.0.1:2222/rest"
    log.info "  --virtualenv PATH        Path to Virtual Environment to load (usually path to LaMachine, autodetected if enabled)"
    exit 2
}

if (params.mode == "modernize" && (!params.containsKey('dictionary') || !params.containsKey('inthistlexicon'))) {
    log.error "Modernisation mode requires --dictionary and --inthislexicon"
    exit 2
}

if (params.recursive) {
    inputpattern = "**"
} else {
    inputpattern = "*"
}


try {
    if (!nextflow.version.matches('>= 0.25')) { //ironically available since Nextflow 0.25 only
        log.error "Requires Nextflow >= 0.25, your version is too old"
        exit 2
    }
} catch(ex) {
    log.error "Requires Nextflow >= 0.25, your version is too old"
    exit 2
}

println "Reading documents from " + params.inputdir + "/" + inputpattern + "." + params.extension
inputdocuments_test = Channel.fromPath(params.inputdir+"/" + inputpattern + "." + params.extension)
println "Found " + inputdocuments_test.count().val + " input documents"

inputdocuments_counter = Channel.fromPath(params.inputdir+"/" + inputpattern + "." + params.extension)

if (params.tei) {
    teidocuments = Channel.fromPath(params.inputdir+"/" + inputpattern + "." + params.extension)

    oztfile = Channel.fromPath(params.oztids)

    process tei2folia {
        //Extract text from TEI documents and convert to FoLiA

        if (params.mode == "convert" && params.metadatadir == "") {
            publishDir params.outputdir, mode: 'copy', overwrite: true
        }

        input:
        file teidocument from teidocuments
        val virtualenv from params.virtualenv

        output:
        file "${teidocument.simpleName}.folia.xml" into foliadocuments

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        tei2folia --traceback --dtddir /tmp "${teidocument}"
        """
    }

    if (params.metadatadir != "") {
        process addmetadata {
            if (params.mode == "convert" && params.metadatadir != "") {
                publishDir params.outputdir, mode: 'copy', overwrite: true
            }

            input:
            each file(inputdocument) from foliadocuments
            val virtualenv from params.virtualenv
            val metadatadir from params.metadatadir
            file oztfile

            output:
            file "${inputdocument.simpleName}.withmetadata.folia.xml" into foliadocuments_untokenized

            script:
            """
            set +u
            if [ ! -z "${virtualenv}" ]; then
                source ${virtualenv}/bin/activate
            fi
            set -u

            python ${LM_PREFIX}/opt/nederlab-pipeline/scripts/dbnl/addmetadata.py --oztfile ${oztfile} -d ${metadatadir} -o ${inputdocument.simpleName}.withmetadata.folia.xml ${inputdocument}
            """
        }
    } else {
        foliadocuments.set { foliadocuments_untokenized }
    }

    if (params.mode == "convert") {
        // we only did conversion so we're all done
        foliadocuments_untokenized.subscribe { println it }
        return
    }

    //foliadocuments_tokenized.subscribe { println it }
} else {
    foliadocuments_untokenized = Channel.fromPath(params.inputdir+"/" + inputpattern + ".folia.xml")
}

if ((params.tok) && (params.mode != "convert")) {
    //documents need to be tokenised
    if (!params.tei) {
        foliadocuments_untokenized = Channel.fromPath(params.inputdir+"/" + inputpattern + ".folia.xml")
    }
    process tokenize_ucto {
        //tokenize the text

        input:
        file inputdocument from foliadocuments_untokenized
        val language from params.language
        val virtualenv from params.virtualenv

        output:
        file "${inputdocument.simpleName}.tok.folia.xml" into foliadocuments_tokenized

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        if [[ "${inputdocument}" != "${inputdocument.simpleName}.tok.folia.xml" ]]; then
            ucto -L "${language}" -X -F "${inputdocument}" "${inputdocument.simpleName}.tok.folia.xml"
        else
            exit 0
        fi
        """
    }
} else {
    foliadocuments_untokenized.set { foliadocuments_tokenized }
}


if (params.dolangid) {
    process langid {
        input:
        file inputdocument from foliadocuments_tokenized
        val detectlanguages from params.detectlanguages
        val virtualenv from params.virtualenv

        output:
        file "${inputdocument.simpleName}.lang.folia.xml" into foliadocuments_postlangid

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        #strip extra components from input file
        mv ${inputdocument} ${inputdocument.simpleName}.folia.xml

        if [[ "${inputdocument}" != "${inputdocument.simpleName}.langid.folia.xml" ]]; then
            colibri-lang -t s -l "${detectlanguages}" "${inputdocument.simpleName}.folia.xml"
            echo "Output should be in ${inputdocument.simpleName}.lang.folia.xml"
        else
            exit 0
        fi
        """
    }
} else {
    foliadocuments_tokenized.set { foliadocuments_postlangid }
}


//split the tokenized documents into batches, fork into two channels
//foliadocuments_postlangid
//    .buffer( size: Math.ceil(inputdocuments_counter.count().val / params.workers).toInteger(), remainder: true)
//    .into { foliadocuments_batches_tokenized1; foliadocuments_batches_tokenized2 }

if (params.mode == "simple") {

    process frog_original {
        //Linguistic enrichment on the original text of the document (pre-modernization)
        //Receives multiple input files in batches

        if ((!params.wikiente) && (params.mode == "simple")) {
            publishDir params.outputdir, mode: 'copy', overwrite: true
        }

        errorStrategy params.frogerrors

        input:
        file foliadocument from foliadocuments_postlangid //foliadocuments is a collection/batch for multiple files
        val skip from params.skip
        val uselangid from params.uselangid
        val virtualenv from params.virtualenv
        val frogconfig from params.frogconfig

        output:
        file "${foliadocument.simpleName}.frogoriginal.folia.xml" into foliadocuments_frogged_original

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        opts=""
        if [ ! -z "$frogconfig" ]; then
            opts="-c $frogconfig"
        fi
        if [ ! -z "$skip" ]; then
            opts="\$opts --skip=${skip}"
        fi
        if [[ "$uselangid" == "true" ]]; then
            opts="\$opts --language=nld"
        fi

        frog \$opts --override tokenizer.rulesFile=tokconfig-nld-historical -x ${foliadocument} -X ${foliadocument.simpleName}.frogoriginal.folia.xml --nostdout
        """
    }

}


//foliadocuments_frogged_original.subscribe { println "DBNL debug pipeline output document: " + it.name }
if (params.mode == "modernize") {

    inputdocuments_counter2 = Channel.fromPath(params.inputdir+"/" + inputpattern + "." + params.extension)

    //add the necessary input files to each batch
    foliadocuments_postlangid
        .map { inputdocument -> tuple(inputdocument, file(params.dictionary), file(params.preservation), file(params.rules), file(params.inthistlexicon)) }
        .set { foliadocuments_withdata }

    process modernize {
        //translate the document to contemporary dutch for PoS tagging
        //adds an extra <t class="contemporary"> layer
        input:
        set file(inputdocument), file(dictionary), file(preservationlexicon), file(rulefile), file(inthistlexicon) from foliadocuments_withdata
        val virtualenv from params.virtualenv
        val uselangid from params.uselangid

        output:
        file "${inputdocument.simpleName}.translated.folia.xml" into foliadocuments_modernized

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        if [[ "${uselangid}" == "true" ]]; then
            opts="-l nld"
        else
            opts=""
        fi

        FoLiA-wordtranslate \$opts --outputclass contemporary -t 1 -d "${dictionary}" -p "${preservationlexicon}" -r "${rulefile}" -H "${inthistlexicon}" ${inputdocument}
        """
    }

    process frog_modernized {
        if ((!params.wikiente) && (params.mode == "modernize")) {
            publishDir params.outputdir, mode: 'copy', overwrite: true
        }

        errorStrategy params.frogerrors

        input:
        file inputdocuments from foliadocuments_modernized
        val skip from params.skip
        val virtualenv from params.virtualenv
        val uselangid from params.uselangid
        val frogconfig from params.frogconfig

        output:
        file "*.frogmodernized.folia.xml" into foliadocuments_frogged_modernized

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        opts=""
        if [ ! -z "$frogconfig" ]; then
            opts="-c $frogconfig"
        fi
        if [ ! -z "$skip" ]; then
            opts="\$opts --skip=${skip}"
        fi
        if [[ "$uselangid" == "true" ]]; then
            opts="\$opts --language=nld"
        fi

        frog \$opts --override tokenizer.rulesFile=tokconfig-nld-historical -x ${inputdocument} -X ${inputdocument.simpleName}.frogmodernized.folia.xml --textclass contemporary --nostdout
        """
    }



    } else {
        //modernize mode
        foliadocuments_frogged_modernized
            .set { foliadocuments_merged }
    }
} else {
    //simple mode

    foliadocuments_frogged_original
        .set { foliadocuments_merged }

}

if (params.wikiente) {
    process wikiente {
        errorStrategy task.attempt >= 9 ? 'ignore' : 'retry'
        maxRetries 10

        input:
        file document from foliadocuments_merged
        val virtualenv from params.virtualenv
        val spotlightserver from params.spotlight

        output:
        file "${document.simpleName}.linked.folia.xml" into foliadocuments_linked


        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        #Note: We ignore (-i) connection errors here, this may lead to some misses! (but at least doesn't crash the pipeline)
        wikiente -i -s "${spotlightserver}" -l nld -c 0.75 -o "${document.simpleName}.linked.folia.xml" "${document}"
        """
    }

} else {
    foliadocuments_merged.set { foliadocuments_linked }
}

process foliavalidator {
    validExitStatus 0,1

    publishDir params.outputdir, mode: 'copy', overwrite: true, pattern: "*.nederlab.folia.xml"

    input:
    file doc from foliadocuments_linked
    val virtualenv from params.virtualenv

    output:
    file "*.foliavalidator" into validationresults
    file "${doc.simpleName}.nederlab.folia.xml" into outputdocuments

    script:
    """
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u
    date=\$(date +"%Y-%m-%d %H:%M:%S")
    echo "--------------- \$date ---------------" > "${doc}.foliavalidator"
    echo "md5 checksum: "\$(md5sum ${doc}) >> "${doc}.foliavalidator"
    foliavalidator -o "${doc}" > ${doc.simpleName}.nederlab.folia.xml 2>> "${doc}.foliavalidator"
    if [ \$? -eq 0 ]; then
        echo \$(readlink "${doc}")"\tOK" >> "${doc}.foliavalidator"
    else
        echo \$(readlink "${doc}")"\tFAILED" >> "${doc}.foliavalidator"
    fi
    """
}

//split channel
validationresults_report = Channel.create()
validationresults_summary = Channel.create()
validationresults.into { validationresults_report; validationresults_summary }

process validationreport {
    input:
    file "*.foliavalidator" from validationresults_report.collect()

    output:
    file "foliavalidation.report" into report

    script:
    """
    find -name "*.foliavalidator" | xargs -n 1 cat > foliavalidation.report
    """
}

process summary {
    input:
    file "*.foliavalidator" from validationresults_summary.collect()

    output:
    file "foliavalidation.summary" into summary

    script:
    """
    find -name "*.foliavalidator" | xargs -n 1 tail -n 1 > foliavalidation.summary
    """
}
//validationresults.subscribe { print it.text }

report
    .collectFile(name: params.outreport)

summary
    .collectFile(name: params.outsummary)
    .println { it.text }
