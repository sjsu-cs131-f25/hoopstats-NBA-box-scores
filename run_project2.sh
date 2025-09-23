#!/bin/bash
#run_preject2.sh
#Usage bash -x run_porject2.sh <team_name> <dataset_file>
#Generates sample, frequency tables, Top-N, and logs into out/
#Used a CSV file, comma delimiter

TEAM_NAME=$1
DATASET_FILE=$2
OUT=out
cd /mnt/scratch/CS131_jelenag/projects/${TEAM_NAME}/
mkdir -p $OUT data/samples

#1. Create 1k sample with header
echo "Creating 1k sample with header: "
head -n 1 $DATASET_FILE > data/samples/sample.csv                     
tail -n +2 $DATASET_FILE | shuf -n 1000 >> data/samples/sample.csv

#2. Frequency table (Column 21)
echo "Creating Frequency Table 1: "
tail -n +2 $DATASET_FILE | cut -d',' -f21 | sort | uniq -c | sort -nr | tee $OUT/freq_col21.txt

#3. Top 20 list (Column 17)
echo "Top 20 list"
tail -n +2 $DATASET_FILE | cut -d',' -f17 | sort -nr | uniq -c | head -n 20 | tee $OUT/top20_col17.txt


