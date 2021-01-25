[![Build Status](https://travis-ci.org/ParasiteTracker/tpt-reporting.svg?branch=master)](https://travis-ci.org/ParasiteTracker/tpt-reporting) [![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.3690022.svg)](https://doi.org/10.5281/zenodo.3690022) 



# tpt-reporting
Terrestrial Parasite Tracking Reporting Methods 

Please click on above travis badge to view current TPT reports. 


## Archived reports from TPT project

Date of release | DOI
--- | --- |
February 24, 2020 | [![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.3685365.svg)](https://doi.org/10.5281/zenodo.3685365)
April 29, 2020 | [![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.3778773.svg)](https://doi.org/10.5281/zenodo.3778773)


## Creating a new archived report
1. Check for new datasets in the TPT integration table

> curl -Ls "https://raw.githubusercontent.com/globalbioticinteractions/globalbioticinteractions.github.io/master/_data/parasitetracker.tsv" | tail -n+2 | cut -f9 | sort | uniq

2. Update datasets.tsv with the new datasets

3. run report script: generate-report.sh
