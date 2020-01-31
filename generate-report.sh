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

TODAY=`date --iso-8601`
REPORT_DIR=output/$TODAY
REPORT_ARCHIVE=output/tpt-globi-report-$TODAY.zip
mkdir -p $REPORT_DIR
REVIEW=$REPORT_DIR/review_notes.tsv
REVIEW_BY_COLLECTION=$REPORT_DIR/review_notes_by_collection.tsv
INTERACTIONS=$REPORT_DIR/interactions.tsv
INTERACTIONS_BY_COLLECTION=$REPORT_DIR/interactions_by_collection.tsv

# updating TPT affiliated elton datasets
if [[ -z "${GITHUB_CLIENT_ID}" ]]; then
  cat datasets.tsv | xargs java -Xmx4G -Dgithub.client.id=$GITHUB_CLIENT_ID -Dgithub.client.secret=$GITHUB_CLIENT_SECRET -jar $(which elton) update 
else
  cat datasets.tsv | xargs java -Xmx4G -jar $(which elton) update
fi

echo -e "\n"

# generating review reports
cat datasets.tsv | xargs -L1 java -Xmx4G -jar $(which elton) review --type note | tail -n+2 >> $REVIEW

echo -e "\n"

# generating interaction data
cat datasets.tsv | xargs -L1 java -Xmx4G -jar $(which elton) interactions | tail -n+2 >> $INTERACTIONS

# group review notes by collection
echo -e "#notes\tnamespace\tinstitutionCode\tcollectionCode\tnote" > $REVIEW_BY_COLLECTION
cat $REVIEW | awk -F '\t' '{ print $4 "\t" $9 "\t" $10 "\t" $6 }' | sort | uniq -c | sort -nr | sed 's/[ ]*//;s/[ ]/\t/' >> $REVIEW_BY_COLLECTION

# group interaction data by collection
echo -e "#records\tnamespace\tinstitutionCode\tcollectionCode\tinteractionTypeId\tinteractionTypeName" > $INTERACTIONS_BY_COLLECTION
cat $INTERACTIONS | awk -F '\t' '{ print $46 "\t" $5 "\t" $4 "\t" $18 "\t" $19 }' | sort | uniq -c | sort -nr | sed 's/[ ]*//;s/[ ]/\t/' >> $INTERACTIONS_BY_COLLECTION

echo -e "\n---- interaction record by interaction type by collection ----"
cat $INTERACTIONS_BY_COLLECTION

echo -e "\n---- review notes by collection ----"
cat $REVIEW_BY_COLLECTION

echo -e "\nFor more information, see $PWD/$REPORT_DIR"

zip $REPORT_ARCHIVE $REPORT_DIR/*
echo -e "\nDownload the full report [$REPORT_ARCHIVE] using single-use, and expiring, file.io link at:"
curl -F "file=@$REPORT_ARCHIVE" https://file.io 
