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
REVIEW=$REPORT_DIR/review.tsv
REVIEW_BY_COLLECTION=$REPORT_DIR/review_by_collection.tsv
INTERACTIONS=$REPORT_DIR/interactions.tsv
INTERACTIONS_BY_COLLECTION=$REPORT_DIR/interactions_by_collection.tsv

echo "updating TPT affiliated elton datasets"
#cat datasets.tsv | xargs elton update 

echo "generating review reports"
cat datasets.tsv | xargs elton review --type note >> $REVIEW

echo "generating interaction data"
cat datasets.tsv | xargs elton interactions >> $INTERACTIONS

echo "group review notes by collection"
cat $REVIEW | tail -n+2 | awk -F '\t' '{ print $9 "\t" $6 }' | sort | uniq -c | sort -nr > $REVIEW_BY_COLLECTION

echo "group interaction data by collection"
cat $INTERACTIONS | tail -n+2 | awk -F '\t' '{ print $4 "\t" $18 "\t" $19 }' | sort | uniq -c | sort -nr 
 > $INTERACTIONS_BY_COLLECTION

echo "contents of $REPORT_DIR:"
ls -1 $REPORT_DIR
