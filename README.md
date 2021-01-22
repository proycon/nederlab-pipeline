[![Language Machines Badge](http://applejack.science.ru.nl/lamabadge.php/nederlab-pipeline)](http://applejack.science.ru.nl/languagemachines/)
[![Build Status](https://travis-ci.com/proycon/nederlab-pipeline.svg?branch=master)](https://travis-ci.org/proycon/nederlab-pipeline)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/proycon/nederlab-pipeline)

[![Project Status: Active – The project has reached a stable, usable state and is being actively developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)

# Nederlab Pipeline

## Introduction

This repository contains the NLP pipeline for the linguistic enrichment of
historical dutch, as developed in the scope of the [Nederlab
project](https://www.nederlab.nl/). This repository covers only the pipeline
logic, powered by [Nextflow](https://www.nextflow.io), not the individual components. It depends on the following tools:

* [ucto](https://languagemachines.github.io/ucto) for tokenisation.
* [Frog](https://languagemachines.github.io/frog) for PoS-tagging, lemmatisation and Named Entity Recognition for Dutch,
    Middle Dutch, and Early New Dutch (vroegnieuwnederlands)
* [FoLiA-utils](https://github.com/LanguageMachines) for:
    * ``FoLiA-wordtranslate`` - Implements Erik Tjong Kim Sang's word-by-word modernisation method. This is a
        reimplementation of his initial prototype, with some improvements of my own.
* [Colibri Utils](https://github.com/proycon/colibri-utils) for:
    * ``colibri-lang`` - Language Identification (including models for Middle Dutch and Early new Dutch)
* [FoLiA Tools](https://github.com/proycon/foliatools) for:
    * ``foliavalidator`` - Validation
    * ``foliaupgrade`` - Upgrades to FoLiA v2
    * ``tei2folia`` - Conversion from a subset of TEI to FoLiA.
    * ``foliamerge`` - Merges annotations between two FoLiA documents.
* [wikiente](https://github.com/proycon/wikiente) for Named Entity Recognition and Linking using [DBPedia Spotlight](https://www.dbpedia-spotlight.org)

## Format

All tools in this pipeline take and produce documents in the [FoLiA](https://proycon.github.io/folia) XML format (version 2). Provenance information of all the tools is recorded in the documents themselves. Please take note of the [FoLiA Guidelines](https://folia.readthedocs.io/en/latest/guidelines.html) if you work with this pipeline or any documents produced by it.

The following linguistic enrichments can be performed, note that different FoLiA (tag)sets can be produced, even at the same
time, based on what methodology was choosen and what time period the document covers:

* Modernisation of 17th century dutch
    * Produces [text annotation](https://folia.readthedocs.io/en/latest/text_annotation.html) with the class ``contemporary``, e.g. ``<t class="contemporary">``
* Part-of-Speech tagging
    * Produces [part-of-speech annotation](https://folia.readthedocs.io/en/latest/pos_annotation.html#pos-annotation) in one or more the following sets:
		* http://ilk.uvt.nl/folia/sets/frog-mbpos-nl - Part-of-Speech tags as produced by Frog by default for contemporary dutch.
        * http://rdf.ivdnt.org/pos/cgn-bab - A CGN-like tagset, but converted from another tagset used for the Brieven als Buit corpus (early new dutch)
		* http://rdf.ivdnt.org/pos/cgn-mnl - A CGN-like tagset, but converted from another tagset used for Corpys Gysseling and Corpus Reenen Mulder (middle dutch)
* Language Identification
	* Produces [language annotation](https://folia.readthedocs.io/en/latest/lang_annotation.html) in the following set:
		* http://raw.github.com/proycon/folia/master/setdefinitions/iso639_3.foliaset - ISO-639-3 language codes
* Lemmatisation
	* Produces [lemma annotation](https://folia.readthedocs.io/en/latest/lemma_annotation.html) in the following sets:
		* http://ilk.uvt.nl/folia/sets/frog-mblem-nl - Lemmas as produced by Frog by default for contemporary dutch.
		* http://rdf.ivdnt.org/lemma/corpus-brieven-als-buit - Lemmas from Brieven als Buit (early new dutch/vroegnieuwnederlands)
		* http://rdf.ivdnt.org/lemma/corpus-gysseling - Lemmas from Corpus Gysseling and Corpus Reenen Mulder (middle dutch/middelnederlands)
		* https://raw.githubusercontent.com/proycon/folia/master/setdefinitions/int_lemmaid_withcompounds.foliaset.ttl - Lemma IDs from the INT Historical Lexicon, with compound lemmas.
		* https://raw.githubusercontent.com/proycon/folia/master/setdefinitions/int_lemmatext_withcompounds.foliaset.ttl - Lemma (words) from the INT Historical Lexicon, with compound lemmas.
* Named Entity Recognition
	* Produces [entity annotation](https://folia.readthedocs.io/en/latest/entity_annotation.html) in the following sets:
		* http://ilk.uvt.nl/folia/sets/frog-ner-nl - Broad named entity classes as produced by Frog (per,loc,org, etc..)
		* https://raw.githubusercontent.com/proycon/folia/master/setdefinitions/spotlight/dbpedia.foliaset.ttl - Links directly to individual DBPedia resources (class is a full URI), produced by WikiEnte

In addition to the linguistic annotations, the tei2folia converter produces a wide variety of [structural
annotations](https://folia.readthedocs.io/en/latest/structure_annotation_category.html) and also [markup
annotations](https://folia.readthedocs.io/en/latest/textmarkup_annotation_category.html), as it's objective is to retain all information from the original TEI source.

### Changes from older versions

As there are documents produced with previous versions of this pipeline, it is important to be aware of the biggest changes:

* **1)** Older versions of this pipeline incorporated [foliaentity](https://github.com/ErwinKomen/foliaentity) instead of wikiente, which performed entity linking separate from entity recognition and encoded it in the FoLiA documents as *alignments* (now called [relation annotation](https://folia.readthedocs.io/en/latest/relation_annotation.html) since FoliA v2). This is something to be aware of when you are interested in the linking information and are processing documents (always FoLiA v1.4 or v1.5) produced by predecessors of this pipeline.

* **2)** Older versions of this pipeline used Erik Tjong Kim Sangs's TEI to FoLiA converter for converting DBNL documents. This converter was deemed too fragile and hard to maintain and was replaced by the new ``tei2folia`` in [FoLiA tools](https://github.com/proycon/foliatools). Older versions can be recognised as they predate FoLiA v2. Older documents also miss a lot of metadata as this was not really handled by the previous converter.

* **3)** Older versions lack provenance information

* **4)** Older DBNL versions were split, in the sense that independent titles (onzelfstandige titels), were separate
    documents. The current TEI-to-FoLiA converter no longer does this, but each independent title is clearer marked
    using FoLiA's submetadata mechanism.

This pipeline itself used to be part of [PICCL](https://github.com/LanguageMachines/PICCL), but was split-off for maintainability and clarity.

## Installation

The pipeline and all components on which it depends is shipped as a part of [LaMachine](https://proycon.github.io/LaMachine), which comes in various flavours (Virtual Machine, Docker container, local installation, etc..).

## Usage

Inside LaMachine, you can invoke the workflow as follows:

```
$ nederlab.nf
```

or:

```
$ nextflow run $(which nederlab.nf)
```

For instructions, run ``nederlab.nf --help``.

You can also let Nextflow manage Docker and LaMachine for you, but we won't go into that here.


### Fix and split pipeline

There was a problem with the DBNL collection as delivered in 2019 (described in [internal issue
TT-709](https://jira.socialhistoryservices.org/browse/TT-709)). Also, it was decided that it was better to split the
independent titles after all. A Nextflow script has been written to handle this.

Put the collection you want to process in some input directory, create an output directory, and run something like:

```
$ dbnl_fix_and_split.nf --inputdir input/ --outputdir output/ --datadir /path/to/nederlab-linguistic-enrichment
```

The data directory should point to where you checked out the [nederlab-linguistic-enrichment repository](https://github.com/INL/nederlab-linguistic-enrichment) (a private repository by INT).

Note: pass ``--extension folia.xml.gz`` if the input files are compressed. The script will compress all output files by
default too.

## Resources

Resources for Erik Tjong Kim Sang's modernisation method are included in this repository:

* ``preservation2010.txt`` - Preservation lexicon
* ``rules.machine`` - Rewrite rules
* ``lexicon.1637-2010.250.lexserv.vandale.tsv`` - Automatically extracted translation lexicon (from Statenbijbel) for use in modernisation procedure (disabled due to too many errors, use of INT Historical Lexicon is preferred)

Not included is the INT Historical Lexicon, as it is copyrighted material.


