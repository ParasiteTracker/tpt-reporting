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

#set -x

echo "using elton version $ELTON_VERSION"

# updating TPT affiliated elton datasets

function checkRateLimit() {
  GITHUB_VARS=""
  if [[ -z "${GITHUB_CLIENT_ID}" ]]; then
    echo "Please set GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET environment variables to avoid GitHub API rate limiting (see https://developer.github.com/v3/rate_limit/) ."
    echo current limit:
  else
    echo current limits for clientId/Secret:
    GITHUB_VARS="-u $GITHUB_CLIENT_ID:$GITHUB_CLIENT_SECRET"
  fi
  REMAINING_SEARCH=$(curl --silent $GITHUB_VARS https://api.github.com/rate_limit | grep --after-context 2 search | grep remaining | sed -E 's/[^[0-9]]*//g')
  echo "[$REMAINING_SEARCH] github search requests left"
  return $REMAINING_SEARCH
}

function updateAll {
  # update all at once to reduce github api requests
  for dataset in $DATASETS_UNDER_REVIEW
  do
    local SLEEP_TIME=5
    local MINIMUM_REQUEST_QUOTA=10
    checkRateLimit
    local requestsLeft=$?
    while [ $requestsLeft -lt $MINIMUM_REQUEST_QUOTA ]
    do 
      echo "sleep [$SLEEP_TIME]s to wait for at least [$MINIMUM_REQUEST_QUOTA] request quota"
      sleep $SLEEP_TIME
      checkRateLimit
      requestsLeft=$?
    done
    $ELTON_CMD update "$dataset"
  done
}

updateAll

echo -e "\n"

# generating review reports

echo "${DATASETS_UNDER_REVIEW_HEAD}" | xargs -L1 $ELTON_CMD review --type note | gzip > "$REVIEW"
echo "${DATASETS_UNDER_REVIEW_TAIL}" | xargs -L1 $ELTON_CMD review --no-header --type note | tail -n +2 | gzip >> "$REVIEW"

echo -e "\n"

# generating interaction data
echo "$DATASETS_UNDER_REVIEW_HEAD" | xargs -L1 $ELTON_CMD interactions | gzip > "$INTERACTIONS_FULL"
echo "$DATASETS_UNDER_REVIEW_TAIL" | xargs -L1 $ELTON_CMD interactions --no-header | gzip >> "$INTERACTIONS_FULL"

# group review issues by collection
echo -e "institutionCode\tcollectionId\tcollectionCode\tsourceCitation\tdistinctReviewCommentCount\ttype\tcomment" > "$REVIEW_BY_COLLECTION"
zcat $REVIEW | tail -n +2 | awk -F '\t' '{ print $9 "\t" $11 "\t" $10 "\t" $14 "\t" $5 "\t" $6 }' | sort | uniq -c | sort -nr | sed -E $'s/[ ]*//;s/[ ]/\t/' | awk -F '\t' '{ print $2 "\t" $3 "\t" $4 "\t" $5 "\t" $1 "\t" $6 "\t" $7 }' | sed -E $'s/\tnote\t/\tissue\t/g' | sort >> "$REVIEW_BY_COLLECTION"

# review summary
echo -e "distinctReviewCommentCount\ttype\tcomment" > "$REVIEW_SUMMARY"
zcat $REVIEW | tail -n +2 | awk -F '\t' '{ print $5 "\t" $6 }' | sort | uniq -c | sort -nr | sed -E $'s/[ ]*//;s/[ ]/\t/' | sed -E $'s/\tnote\t/\tissue\t/g' | sort >> "$REVIEW_SUMMARY"

# group interaction data by collection
echo -e "institutionCode\tcollectionId\tcollectionCode\tsourceCitation\tindexedInteractionRecordCount\tinteractionTypeName\tinteractionTypeId" > "$INTERACTIONS_BY_COLLECTION"
zcat "$INTERACTIONS_FULL" | tail -n +2 | awk -F '\t' '{ print $6 "\t" $5 "\t" $4 "\t" $49 "\t" $20 "\t" $19 }' | sort | uniq -c | sort -nr | sed -E $'s/[ ]*//;s/[ ]/\t/' | awk -F '\t' '{ print $2 "\t" $3 "\t" $4 "\t" $5 "\t" $1  "\t" $6 "\t" $7 }' | sort >> "$INTERACTIONS_BY_COLLECTION"

zcat "$INTERACTIONS_FULL" | awk -F '\t' '{ print $6 "\t" $5 "\t" $4 "\t" $3 "\t" $8 "\t" $20 "\t" $27 }' | gzip > "$INTERACTIONS_SIMPLE"

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

echo -e "\nFor more information, see $PWD/$REPORT_DIR"

NUMBER_OF_INTERACTIONS=$(cat "$INTERACTIONS_FULL" | sort | uniq | wc -l)

if [ $NUMBER_OF_INTERACTIONS -gt 1 ]
then
  OLD_DIR=$PWD
  cd "$REPORT_DIR"
  zip "$REPORT_ARCHIVE" README review_summary.tsv review_summary_by_collection.tsv review_comments.tsv.gz indexed_interactions_full.tsv.gz indexed_interactions_simple.tsv.gz datasets_under_review.tsv 
  cd "$OLD_DIR"
  echo -e "\nDownload the full report [$REPORT_ARCHIVE] using single-use, and expiring, file.io link at:"
  curl -F "file=@$REPORT_ARCHIVE" https://file.io 
else
  echo -e "\nCannot create report because no interaction records were found. Please check log."
  exit 1
fi
