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

set -x

TODAY=$(date "+%Y-%m-%d")
REPORT_DIR="$PWD/output/$TODAY"
REPORT_ARCHIVE="$PWD/output/tpt-globi-report-$TODAY.zip"
mkdir -p "$REPORT_DIR"
DATASET_INFO="$REPORT_DIR/datasets_under_review.tsv"
REVIEW="$REPORT_DIR/review_issues.tsv"
REVIEW_BY_COLLECTION="$REPORT_DIR/review_issues_by_collection.tsv"
REVIEW_SUMMARY="$REPORT_DIR/review_summary.tsv"
INTERACTIONS="$REPORT_DIR/indexed_interactions.tsv"
NAMES="$REPORT_DIR/indexed_names.tsv"
INTERACTIONS_BY_COLLECTION="$REPORT_DIR/indexed_interactions_by_collection.tsv"

DATASETS_UNDER_REVIEW="$(cat datasets.tsv)"

ELTON_VERSION=$(elton version)

echo "using elton version $ELTON_VERSION"

# updating TPT affiliated elton datasets
if [[ -z "${GITHUB_CLIENT_ID}" ]]; then
  echo "Please set GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET environment variables to avoid GitHub API rate limiting (see https://developer.github.com/v3/rate_limit/) ." 
fi

echo "$DATASETS_UNDER_REVIEW" | xargs -L1 elton update

echo -e "\n"

# generating review reports

echo "$DATASETS_UNDER_REVIEW" | xargs -L1 elton review --type info,note | tail -n +2 > "$REVIEW"

echo -e "\n"

# generating interaction data
echo "$DATASETS_UNDER_REVIEW" | xargs -L1 elton interactions > "$INTERACTIONS"

# generate names
echo "$DATASETS_UNDER_REVIEW" | xargs -L1 elton names > "$NAMES"

# group review issues by collection
echo -e "institutionCode\tcollectionCode\tdistinctReviewCommentCount\ttype\tcomment" > "$REVIEW_BY_COLLECTION"
cat $REVIEW | awk -F '\t' '{ print $9 "\t" $10 "\t" $5 "\t" $6 }' | sort | uniq -c | sort -nr | sed -E $'s/[ ]*//;s/[ ]/\t/' | awk -F '\t' '{ print $2 "\t" $3 "\t" $1 "\t" $4 "\t" $5 }' | sed -E $'s/\tnote\t/\tissue\t/g' | sort >> "$REVIEW_BY_COLLECTION"
# review summary
echo -e "distinctReviewCommentCount\ttype\tcomment" > "$REVIEW_SUMMARY"
cat $REVIEW | awk -F '\t' '{ print $5 "\t" $6 }' | sort | uniq -c | sort -nr | sed -E $'s/[ ]*//;s/[ ]/\t/' | sed -E $'s/\tnote\t/\tissue\t/g' | sort >> "$REVIEW_SUMMARY"

# group interaction data by collection
echo -e "institutionCode\tcollectionCode\tindexedInteractionRecordCount\tinteractionTypeId\tinteractionTypeName" > "$INTERACTIONS_BY_COLLECTION"
cat "$INTERACTIONS" | awk -F '\t' '{ print $5 "\t" $4 "\t" $18 "\t" $19 }' | sort | uniq -c | sort -nr | sed -E $'s/[ ]*//;s/[ ]/\t/' | awk -F '\t' '{ print $2 "\t" $3 "\t" $1 "\t" $4 "\t" $5 }' | sort >> "$INTERACTIONS_BY_COLLECTION"

echo -e "\n---- distinct review comments by type ----"
cat "$REVIEW_SUMMARY"

echo -e "\n---- indexed interaction record count by institution, collectionCode, and interaction type ----"
cat "$INTERACTIONS_BY_COLLECTION"

echo -e "\n---- distinct review comment count by institution, collection and review comment type ----"
cat "$REVIEW_BY_COLLECTION"

echo "$DATASETS_UNDER_REVIEW" | xargs -L1 elton datasets > "$DATASET_INFO"

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

indexed_interactions_by_collection.tsv: 
  Summary of number of indexed interaction records by institutionCode and collectionCode.

indexed_interactions.tsv:
  Table of all indexed interactions.

indexed_names.tsv:
  Table with all indexed names.

review_issues_by_collection.tsv:
  Summary of total number of distinct review comments by institutionCode, collectionCode and review comment type.

review_comments.tsv:
  Table with all review comments.

review_summary.tsv
  Summary of total number of distinct review comments by review type.

dataset_info.tsv
  Details on the datasets under review.

EOF

echo -e "\nFor more information, see $PWD/$REPORT_DIR"

NUMBER_OF_INTERACTIONS=$(cat "$INTERACTIONS" | sort | uniq | wc -l)

if [ $NUMBER_OF_INTERACTIONS -gt 1 ]
then
  OLD_DIR=$PWD
  cd "$REPORT_DIR"
  zip "$REPORT_ARCHIVE" *; 
  cd "$OLD_DIR"
  echo -e "\nDownload the full report [$REPORT_ARCHIVE] using single-use, and expiring, file.io link at:"
  curl -F "file=@$REPORT_ARCHIVE" https://file.io 
else
  echo -e "\nCannot create report because no interaction records were found. Please check log."
  exit 1
fi
