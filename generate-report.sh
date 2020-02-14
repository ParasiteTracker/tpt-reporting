#!/bin/bash
#
# Script to generate TPT GloBI report and upload to https://file.io .
#
# The report summarizes how many TPT records are indexed by GloBI.
#
# Also see https://parasitetracker.org, https://globalbioticinteractions.org, and https://github.com/globalbioticinteractions/globalbioticinteractions/issues/453 . 
# 
# Prerequisites: Java and https://github.com/globalbioticinteractions/elton .
#
#

TODAY=$(date "+%Y-%m-%d")
REPORT_DIR="$PWD/output/$TODAY"
REPORT_ARCHIVE="$PWD/output/tpt-globi-report-$TODAY.zip"
mkdir -p "$REPORT_DIR"
REVIEW_SUMMARY="$REPORT_DIR/review_summary.tsv"
REVIEW_BY_COLLECTION="$REPORT_DIR/review_summary_by_collection.tsv"
REVIEW="$REPORT_DIR/review_comments.tsv.gz"
INTERACTIONS_BY_COLLECTION="$REPORT_DIR/indexed_interactions_by_collection.tsv"
INTERACTIONS_FULL="$REPORT_DIR/indexed_interactions_full.tsv.gz"
INTERACTIONS_SIMPLE="$REPORT_DIR/indexed_interactions_simple.tsv.gz"
DATASET_INFO="$REPORT_DIR/datasets_under_review.tsv"

DATASET_LIST_FILE=${1:-datasets.tsv}
DATASETS_UNDER_REVIEW="$(cat $DATASET_LIST_FILE)"
DATASETS_UNDER_REVIEW_HEAD="$(head -n1 $DATASET_LIST_FILE)"
DATASETS_UNDER_REVIEW_TAIL="$(tail -n+2 $DATASET_LIST_FILE)"


ELTON_CMD="elton"
ELTON_VERSION=$($ELTON_CMD version)

set -x

echo "using elton version $ELTON_VERSION"

# updating TPT affiliated elton datasets

function updateAll {
  # update all at once to reduce github api requests
  for dataset in $DATASETS_UNDER_REVIEW
  do
    $ELTON_CMD update "$dataset"
  done
}

updateAll

# generating review reports

echo "${DATASETS_UNDER_REVIEW_HEAD}" | xargs -L1 $ELTON_CMD review --type info,note | gzip > "$REVIEW"
echo "${DATASETS_UNDER_REVIEW_TAIL}" | xargs -L1 $ELTON_CMD review --no-header --type info,note | tail -n +2 | gzip >> "$REVIEW"

echo -e "\n"

# generating interaction data
echo "$DATASETS_UNDER_REVIEW_HEAD" | xargs -L1 $ELTON_CMD interactions | gzip > "$INTERACTIONS_FULL"
echo "$DATASETS_UNDER_REVIEW_TAIL" | xargs -L1 $ELTON_CMD interactions --no-header | gzip >> "$INTERACTIONS_FULL"

# group review issues by collection
echo -e "institutionCode\tcollectionId\tcollectionCode\tsourceCitation\tdistinctReviewCommentCount\ttype\tcomment" > "$REVIEW_BY_COLLECTION"
cat $REVIEW | gunzip | tail -n +2 | awk -F '\t' '{ print $9 "\t" $11 "\t" $10 "\t" $14 "\t" $5 "\t" $6 }' | sort | uniq -c | sort -nr | sed -E $'s/[ ]*//;s/[ ]/\t/' | awk -F '\t' '{ print $2 "\t" $3 "\t" $4 "\t" $5 "\t" $1 "\t" $6 "\t" $7 }' | sed -E $'s/\tnote\t/\tissue\t/g' | sort >> "$REVIEW_BY_COLLECTION"

# review summary
echo -e "distinctReviewCommentCount\ttype\tcomment" > "$REVIEW_SUMMARY"
cat $REVIEW | gunzip | tail -n +2 | awk -F '\t' '{ print $5 "\t" $6 }' | sort | uniq -c | sort -nr | sed -E $'s/[ ]*//;s/[ ]/\t/' | sed -E $'s/\tnote\t/\tissue\t/g' | sort >> "$REVIEW_SUMMARY"

# group interaction data by collection
echo -e "institutionCode\tcollectionId\tcollectionCode\tsourceCitation\tindexedInteractionRecordCount\tinteractionTypeName\tinteractionTypeId" > "$INTERACTIONS_BY_COLLECTION"
cat "$INTERACTIONS_FULL" | gunzip | tail -n +2 | awk -F '\t' '{ print $6 "\t" $5 "\t" $4 "\t" $49 "\t" $20 "\t" $19 }' | sort | uniq -c | sort -nr | sed -E $'s/[ ]*//;s/[ ]/\t/' | awk -F '\t' '{ print $2 "\t" $3 "\t" $4 "\t" $5 "\t" $1  "\t" $6 "\t" $7 }' | sort >> "$INTERACTIONS_BY_COLLECTION"

cat "$INTERACTIONS_FULL" | gunzip | awk -F '\t' '{ print $6 "\t" $5 "\t" $4 "\t" $3 "\t" $8 "\t" $20 "\t" $27 }' | gzip > "$INTERACTIONS_SIMPLE"

echo -e "\n---- distinct review comments by type ----"
cat "$REVIEW_SUMMARY"

echo -e "\n---- indexed interaction record count by institutionCode, collectionId, collectionCode, and interaction type ----"
cat "$INTERACTIONS_BY_COLLECTION"

echo -e "\n---- distinct review comment count by institution, collection and review comment type ----"
cat "$REVIEW_BY_COLLECTION"

echo "$DATASETS_UNDER_REVIEW" | xargs -L1 $ELTON_CMD datasets > "$DATASET_INFO"

DATASET_REFERENCES=$(cat $DATASET_INFO | cut -f2,3,4 | tail -n +2 | sed -E 's/\t/ accessed via /' | sed -E 's/^/ - /g' | sed -E 's/\t/ on /')

cat <<EOF > "$REPORT_DIR/README"
GloBI Data Review Report

Datasets under review:
$DATASET_REFERENCES

Generated on:
$TODAY

by:
GloBI's Elton $ELTON_VERSION 
(see https://github.com/globalbioticinteractions/elton).



Note that all files ending with .tsv are files formatted 
as UTF8 encoded tab-separated values files.

https://www.iana.org/assignments/media-types/text/tab-separated-values


Included in this review archive are:

README:
  This file.

review_summary.tsv:
  Summary across all reviewed collections of total number of distinct review comments.

review_summary_by_collection.tsv:
  Summary by reviewed collection of total number of distinct review comments.

indexed_interactions_by_collection.tsv: 
  Summary of number of indexed interaction records by institutionCode and collectionCode.

review_comments.tsv.gz:
  All review comments by collection.

indexed_interactions_full.tsv.gz:
  All indexed interactions for all reviewed collections.

indexed_interactions_simple.tsv.gz:
  All indexed interactions for all reviewed collections selecting only sourceInstitutionCode, sourceCollectionCode, sourceCatalogNumber, sourceTaxonName, interactionTypeName and targetTaxonName.

datasets_under_review.tsv:
  Details on the datasets under review.

EOF

echo -e "\nFor more information, see $REPORT_DIR"

NUMBER_OF_INTERACTIONS=$(cat "$INTERACTIONS_FULL" | gunzip | sort | uniq | wc -l)

if [ $NUMBER_OF_INTERACTIONS -gt 1 ]
then
  OLD_DIR=$PWD
  cd "$REPORT_DIR"
  zip "$REPORT_ARCHIVE" README review_summary.tsv review_summary_by_collection.tsv review_comments.tsv.gz indexed_interactions_full.tsv.gz indexed_interactions_simple.tsv.gz datasets_under_review.tsv 
  cd "$OLD_DIR"
  echo -e "\nDownload the full report [$REPORT_ARCHIVE] using single-use, and expiring, file.io link at:"
  curl -F "file=@$REPORT_ARCHIVE" https://file.io 
else
  echo "Cannot create report because no interaction records were found. Please check log."
  echo "Please check you have the latest elton installed. You are using Elton v[$ELTON_VERSION]. See https://github.com/globalbioticinteractions/elton#install for install instructions and https://github.com/globalbioticinteractions/elton/releases/latest for latest version )."

  exit 1
fi
