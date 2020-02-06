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
REPORT_DIR=output/$TODAY
REPORT_ARCHIVE=output/tpt-globi-report-$TODAY.zip
mkdir -p $REPORT_DIR
REVIEW=$REPORT_DIR/review_issues.tsv
REVIEW_SUMMARY=$REPORT_DIR/review_summary.tsv
REVIEW_BY_COLLECTION=$REPORT_DIR/review_issues_by_collection.tsv
INTERACTIONS=$REPORT_DIR/indexed-interactions.tsv
NAMES=$REPORT_DIR/indexed-names.tsv
INTERACTION_TYPES_BY_COLLECTION=$REPORT_DIR/interaction_types_by_collection.tsv
INTERACTIONS_BY_COLLECTION=$REPORT_DIR/interactions_by_collection.tsv

echo "using elton version $(elton version)"

# updating TPT affiliated elton datasets
if [[ -z "${GITHUB_CLIENT_ID}" ]]; then
  echo "Please set GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET environment variables to avoid GitHub API rate limiting (see https://developer.github.com/v3/rate_limit/) ." 
fi

cat datasets.tsv | xargs elton update

echo -e "\n"

# generating review reports
cat datasets.tsv | xargs -L1 elton review --type note,summary | tail -n +2 >> $REVIEW

cat $REVIEW | cut -f1-6 | grep "summary" > $REVIEW_SUMMARY

echo -e "\n"

# generating interaction data
cat datasets.tsv | xargs -L1 elton interactions | tail -n +2 >> $INTERACTIONS

# generate names
cat datasets.tsv | xargs -L1 elton names | tail -n +2 >> $NAMES

# group review issues by collection
echo -e "#issues\tinstitutionCode\tcollectionCode\tnote" > $REVIEW_BY_COLLECTION
cat $REVIEW | awk -F '\t' '{ print $9 "\t" $10 "\t" $6 }' | sort | uniq -c | sort -nr | sed -E $'s/[ ]*//;s/[ ]/\t/' >> $REVIEW_BY_COLLECTION

# group interaction data by collection
echo -e "#records\tinstitutionCode\tcollectionCode\tinteractionTypeId\tinteractionTypeName" > $INTERACTIONS_BY_COLLECTION
cat $INTERACTIONS | awk -F '\t' '{ print $5 "\t" $4 "\t" $18 "\t" $19 }' | sort | uniq -c | sort -nr | sed -E $'s/[ ]*//;s/[ ]/\t/' >> $INTERACTIONS_BY_COLLECTION

echo -e "\n---- interaction types by institution/collection ----"
echo -e "#institutionCode\tcollectionCode\tinteractionTypeId\tinteractionTypeName" > $INTERACTION_TYPES_BY_COLLECTION
cat $INTERACTIONS | awk -F '\t' '{ print $5 "\t" $4 "\t" $18 "\t" $19 }' | sort | uniq | sort >> $INTERACTION_TYPES_BY_COLLECTION

echo -e "\n---- interaction record count by interaction type by collection ----"
cat $INTERACTION_TYPES_BY_COLLECTION

echo -e "\n---- interaction record count by interaction type by collection ----"
cat $INTERACTIONS_BY_COLLECTION

echo -e "\n---- review notes by institution/collection ----"
cat $REVIEW_BY_COLLECTION

echo -e "\nFor more information, see $PWD/$REPORT_DIR"

NUMBER_OF_INTERACTIONS=$(cat $INTERACTIONS | sort | uniq | wc -l)

if [ $NUMBER_OF_INTERACTIONS -gt 1 ]
then
  zip $REPORT_ARCHIVE $REPORT_DIR/*
  echo -e "\nDownload the full report [$REPORT_ARCHIVE] using single-use, and expiring, file.io link at:"
  curl -F "file=@$REPORT_ARCHIVE" https://file.io 
else
  echo -e "\nCannot create report because no interaction records were found. Please check log."
  exit 1
fi
