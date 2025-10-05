#!/bin/bash
#run_project3.sh
#Usage bash -x run_project3.sh <team_name> <dataset_file>
#define relationships and edges, extract clusters, plot distributions, compare Top-N tokens, summarize clusters,  and logs into out/


TEAM_NAME=$1
DATASET_FILE=$2
OUT=out

cd /mnt/scratch/CS131_jelenag/projects/${TEAM_NAME}/
mkdir -p $OUT data/samples



#Modify csv fields and header
echo "Modifing csv fields and header"
sed -E 's/([0-9]{4})-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/\1/' $DATASET_FILE | sed '1 s/gameDate/gameYear/' > data/samples/playerstats_1k_year.csv


#---Step 1
#Extract edges and sort by left entity, format to tsv
echo "Extracting edges and formatiing to tsv"
head -n 1 data/samples/playerstats_1k_year.csv | cut -d',' -f5,3 | sed 's/,/\t/' > $OUT/edges.tsv
awk -F',' 'NR>1 {print $5 "\t" $3}' data/samples/playerstats_1k_year.csv | sort -nr >> $OUT/edges.tsv



#---Step 2
#Get counts for left entity
echo "Getting counts for left entity"
cut -f1 $OUT/edges.tsv | tail -n +2 | sort | uniq -c | sort -nr | awk '{print $2 "\t" $1}' > $OUT/entity_counts.tsv



#Extract edges that meet the threshold of 5
echo "Extracting edeges that the threshold of 5"
head -n 1 $OUT/edges.tsv > $OUT/edges_thresholded.tsv
awk 'NR==FNR {if($2>=5) years[$1]; next} FNR>1 {if($1 in years) print}' $OUT/entity_counts.tsv $OUT/edges.tsv >> $OUT/edges_thresholded.tsv




