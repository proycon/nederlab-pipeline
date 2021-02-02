#!/usr/bin/env python3

"""
Fix independent titles (onzelfstandige titels) in DBNL FoLiA's delivered in summer 2019.
This reassigns IDs in these documents.
"""

import sys
import os
import argparse
import csv
from collections import defaultdict
try:
    import folia.main as folia
except ImportError:
    print("Missing dependency: please install folia: pip install folia",file=sys.stderr)
    sys.exit(2)

def reassignids(div):
    for e in div.select(folia.AbstractStructureElement):
        if e.metadata: e.metadata = None
        if not isinstance(e, (folia.Linebreak, folia.Whitespace)):
            parent = e.parent
            while not parent.id:
                parent = parent.parent
            e.id = parent.generate_id(e.__class__)
        if isinstance(e, folia.Sentence):
            for ent in e.select(folia.Entity):
                ent.parent.id = None #no ID on the layer
                ent.id = ent.parent.parent.generate_id(ent.__class__)

def process(filename, outputdir, metadata, oztmetadata, oztcount, ignore):
    assert os.path.exists(filename)
    doc = folia.Document(file=filename)
    doc.provenance.append( folia.Processor.create("dbnl_ozt_fix.py") )
    found = 0

    if doc.id not in metadata:
        if ignore:
            print("WARNING: Document not found in Nederlab metadata! Ignoring this and passing the document as-is!!!",file=sys.stderr)
            doc.save(os.path.join(outputdir, os.path.basename(doc.filename)))
            return
        else:
            raise Exception("Document not found in metadata")

    for key, value in metadata[doc.id].items():
        if key not in ('title','ingestTime', 'updateTime','processingMethod') and value:
            doc.metadata[key] = value

    for div in doc.select(folia.Division, False):
        if div.cls == "chapter":
            found += 1
            seq_id = str(found).zfill(4)
            ozt_id = doc.id + "_" + seq_id
            print(f"Found {ozt_id}, reassigning identifiers...",file=sys.stderr)
            div.id = ozt_id  + ".text"
            div.metadata = ozt_id  + ".metadata"
            doc.submetadata[ozt_id + ".metadata"] = folia.NativeMetaData()
            doc.submetadatatype[ozt_id+".metadata"] = "native"
            if ozt_id not in oztmetadata:
                raise Exception(f"No metadata was found for {ozt_id}")
            for key, value in oztmetadata[ozt_id].items():
                if key not in ('ingestTime', 'updateTime','processingMethod') and value:
                    doc.submetadata[ozt_id + ".metadata"][key] = value
            reassignids(div)

    obsolete_submetadata = [ key for key, value in doc.submetadata.items() if not value ]
    for key in obsolete_submetadata:
        del doc.submetadata[key]
        del doc.submetadatatype[key]

    expected = oztcount[doc.id]
    if found != expected:
        raise Exception(f"Found {found} OZT chapters for {doc.id}, expected {expected}")

    print("Saving document",file=sys.stderr)
    doc.save(os.path.join(outputdir, os.path.basename(doc.filename)))

def main():
    parser = argparse.ArgumentParser(description="", formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('-d','--datadir', type=str,help="Path to the nederlab-linguistic-enrichment repository clone (https://github.com/INL/nederlab-linguistic-enrichment). Used to get metadata.", action='store',default="./",required=True)
    parser.add_argument('-O','--outputdir', type=str,help="Output directory", action='store',default="./",required=False)
    parser.add_argument('--ignore',help="Ignore files that do not occur in the metadata, just let them pass through", action='store_true', required=False)
    parser.add_argument('files', nargs='*', help="Input documents (FoLiA XML)")
    args = parser.parse_args()

    print("Loading metadata files...",file=sys.stderr)
    metadata = {}
    count = 0
    with open(os.path.join(args.datadir,"metadata/from_sql/NLTitle.csv"), 'r') as f:
        for row in csv.DictReader(f, delimiter=',', quotechar='"'):
            fileid = row['sourceRef'] + '_01'
            row['nederlabID'] = row['nederlabID'].strip("'")
            metadata[fileid] = row
            count += 1
    print(f"  (found {count} titles)",file=sys.stderr)

    #override some of the metadata with the curated version:
    count = 0
    with open(os.path.join(args.datadir,"metadata/witnessyears-all-extended.tsv"), 'r') as f:
        for row in csv.DictReader(f, delimiter="\t"):
            if row['fileID'] in metadata:
                if row['witnessYearMin'] != metadata[row['fileID']]['witnessYearMin'] or row['witnessYearMax'] != metadata[row['fileID']]['witnessYearMax']:
                    metadata[row['fileID']]['curated'] = 1
                    count += 1
                metadata[row['fileID']]['witnessYearMin'] = row['witnessYearMin']
                metadata[row['fileID']]['witnessYearMax'] = row['witnessYearMax']
                metadata[row['fileID']]['witnessYearApprox'] = row['witnessYearApprox']
    print(f"  (found {count} curated titles)",file=sys.stderr)

    oztmetadata = {}
    oztcount = defaultdict(int) #counts the number of independent titles per parent document, used as a sanity check
    count = 0
    with open(os.path.join(args.datadir,"metadata/from_sql/NLDependentTitle.csv"), 'r') as f:
        for row in csv.DictReader(f, delimiter=',', quotechar='"'):
            oztmetadata[row['sourceRef']] = row
            row['nederlabID'] = row['nederlabID'].strip("'")
            parentid = row['sourceRef'][:-5] #strip the _0001 suffix to get the parent ID
            oztcount[parentid] += 1
            count += 1
    print(f"  (found {count} dependent titles)",file=sys.stderr)

    for i, filename in enumerate(args.files):
        seqnr = i+1
        print(f"#{seqnr} - Loading {filename}...",file=sys.stderr)
        process(filename, args.outputdir, metadata, oztmetadata, oztcount, args.ignore)


if __name__ == '__main__':
    main()
