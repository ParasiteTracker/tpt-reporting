#!/bin/bash
#
# Script to generate TPT GloBI report.
#
# The report summarizes how many TPT records are indexed by GloBI.
#
# Also see https://parasitetracker.org, https://globalbioticinteractions.org, and https://github.com/globalbioticinteractions/globalbioticinteractions/issues/453 . 
# 
# Prerequisites: Java and https://github.com/globalbioticinteractions/elton .
# 

TODAY=`date --iso-8601`
REPORT_DIR=output/$TODAY
mkdir -p $REPORT_DIR
REVIEW=$REPORT_DIR/review_notes.tsv
REVIEW_BY_COLLECTION=$REPORT_DIR/review_notes_by_collection.tsv
INTERACTIONS=$REPORT_DIR/interactions.tsv
INTERACTIONS_BY_COLLECTION=$REPORT_DIR/interactions_by_collection.tsv

# updating TPT affiliated elton datasets
#cat datasets.tsv | xargs elton update 

# generating review reports
cat datasets.tsv | xargs elton review --type note > $REVIEW

# generating interaction data
cat datasets.tsv | xargs elton interactions > $INTERACTIONS

# group review notes by collection
echo -e "#notes\tcollectionCode\tnote" > $REVIEW_BY_COLLECTION
cat $REVIEW | tail -n+2 | awk -F '\t' '{ print $9 "\t" $6 }' | sort | uniq -c | sort -nr | sed 's/[ ]*//;s/[ ]/\t/' >> $REVIEW_BY_COLLECTION

echo "group interaction data by collection"
echo -e "#records\tcollectionCode\tinteractionTypeId\tinteractionTypeName" > $INTERACTIONS_BY_COLLECTION
cat $INTERACTIONS | tail -n+2 | awk -F '\t' '{ print $4 "\t" $18 "\t" $19 }' | sort | uniq -c | sort -nr | sed 's/[ ]*//;s/[ ]/\t/' >> $INTERACTIONS_BY_COLLECTION

echo "---- interaction record by interaction type by collection"
cat $INTERACTIONS_BY_COLLECTION

echo -e "\n---- review notes by collection"
cat $REVIEW_BY_COLLECTION

echo -e "\nfor more information, see $REPORT_DIR"


