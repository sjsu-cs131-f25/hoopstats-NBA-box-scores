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

# --- Step 3
#Cluster-size histogram 
# Input: out/edges_thresholded.tsv   Format: <LeftEntity>\t<RightEntity>
# Outputs: out/cluster_sizes_by_entity.tsv, out/cluster_sizes.tsv, out/cluster_histogram.png
set -euo pipefail

OUT="out"
mkdir -p "$OUT"

# Count edges per left-entity (cluster size)
cut -f1 "$OUT/edges_thresholded.tsv" | sort | uniq -c \
  | awk '{print $2 "\t" $1}' | LC_ALL=C sort -k1,1 > "$OUT/cluster_sizes_by_entity.tsv"

# Histogram: size: how many clusters have that size
cut -f2 "$OUT/cluster_sizes_by_entity.tsv" | LC_ALL=C sort -n \
  | uniq -c | awk '{print $2 "\t" $1}' | LC_ALL=C sort -n > "$OUT/cluster_sizes.tsv"

# Plot
gnuplot <<'EOF'
set terminal png size 600,400
set output 'out/cluster_histogram.png'
set style data histograms
set style fill solid 1.0 border -1
set boxwidth 0.9
set xlabel "Cluster Size (# of edges)"
set ylabel "Number of Clusters"
plot 'out/cluster_sizes.tsv' using 2:xtic(1) title "Cluster Sizes"
EOF

# --- Step 4: 
# Top-30 tokens overall vs thresholded clusters 
# Inputs: out/edges.tsv, out/edges_thresholded.tsv
# Outputs: out/top30_overall.txt, out/top30_clusters.txt, out/top30_compare.tsv, out/diff_top30.txt

# Top-30 in clusters (thresholded)
cut -f2 "$OUT/edges_thresholded.tsv" | sort | uniq -c | sort -nr | head -30 \
  | awk '{c=$1; $1=""; sub(/^ +/,""); print $0 "\t" c}' > "$OUT/top30_clusters.txt"

# Top-30 overall
cut -f2 "$OUT/edges.tsv" | sort | uniq -c | sort -nr | head -30 \
  | awk '{c=$1; $1=""; sub(/^ +/,""); print $0 "\t" c}' > "$OUT/top30_overall.txt"

# Join (needs sorted inputs on the key column)
LC_ALL=C sort -t $'\t' -k1,1 "$OUT/top30_overall.txt"  > "$OUT/top30_overall.sorted.tsv"
LC_ALL=C sort -t $'\t' -k1,1 "$OUT/top30_clusters.txt" > "$OUT/top30_clusters.sorted.tsv"

join -a1 -a2 -e 0 -o 0,1.2,2.2 -t $'\t' \
  "$OUT/top30_overall.sorted.tsv" "$OUT/top30_clusters.sorted.tsv" \
  | awk 'BEGIN{OFS="\t"; print "token","overall_count","clusters_count"}1' \
  > "$OUT/top30_compare.tsv"

# Who moved in/out of Top-30
comm -3 \
  <(cut -f1 "$OUT/top30_overall.txt" | LC_ALL=C sort) \
  <(cut -f1 "$OUT/top30_clusters.txt" | LC_ALL=C sort) \
  > "$OUT/diff_top30.txt"



#Extract edges that meet the threshold of 5
echo "Extracting edeges that the threshold of 5"
head -n 1 $OUT/edges.tsv > $OUT/edges_thresholded.tsv
awk 'NR==FNR {if($2>=5) years[$1]; next} FNR>1 {if($1 in years) print}' $OUT/entity_counts.tsv $OUT/edges.tsv >> $OUT/edges_thresholded.tsv


#Step 5: Created PNG Visual using Gephi

#Step 6: Compute cluster summary statistics
#Remove CSV header & convert CSV to TSV
tail -n +2 "$DATASET_FILE" | tr ',' '\t' > "$OUT/dataset_noheader.tsv"

#Sort edges and dataset by RightEntity ID
sort -k2,2 "$OUT/edges_thresholded.tsv" > "$OUT/edges_sorted.tsv"
sort -k3,3 "$OUT/dataset_noheader.tsv" > "$OUT/dataset_sorted.tsv"

#Join edges with dataset, extract LeftEntity + numeric outcome (assume column 16)
join -t $'\t' -1 2 -2 3 "$OUT/edges_sorted.tsv" "$OUT/dataset_sorted.tsv" | cut -f1,16 > "$OUT/leftentity_numeric.tsv"

#Remove empty numeric values
awk -F'\t' '$2 != ""' "$OUT/leftentity_numeric.tsv" > "$OUT/leftentity_numeric_clean.tsv"

#Compute summary statistics: count, mean, median per LeftEntity
sort -k1,1n "$OUT/leftentity_numeric_clean.tsv" | datamash -g 1 count 2 mean 2 median 2 > "$OUT/cluster_outcomes.tsv"

set -euo pipefail
mkdir -p out
cut -f1 out/edges_thresholded.tsv | sort | uniq -c \
 | awk '{print $2 "\t" $1}' | sort -k1,1 > out/cluster_sizes_by_entity.tsv
cut -f2 out/cluster_sizes_by_entity.tsv | sort -n \
 | uniq -c | awk '{print $2 "\t" $1}' | sort -n > out/cluster_sizes.tsv
gnuplot << 'EOF'
set terminal png size 600,400
set output 'out/cluster_histogram.png'
set style data histograms
set style fill solid 1.0 border -1
set boxwidth 0.9
set xlabel "Cluster Size (# of edges)"
set ylabel "Number of Clusters"
plot 'out/cluster_sizes.tsv' using 2:xtic(1) title "Cluster Sizes"
EOF
#Top-30 tokens in clusters vs overall
cut -f2 out/edges_thresholded.tsv | sort | uniq -c | sort -nr | head -30 \
| awk '{c=$1; $1=""; sub(/^ +/,""); print $0 "\t" c}' > out/top30_clusters.txt
cut -f2 out/edges.tsv | sort | uniq -c | sort -nr | head -30 \
| awk '{c=$1; $1=""; sub(/^ +/,""); print $0 "\t" c}' > out/top30_overall.txt
LC_ALL=C sort -t $'\t' -k1,1 out/top30_overall.txt  > out/top30_overall.sorted.tsv
LC_ALL=C sort -t $'\t' -k1,1 out/top30_clusters.txt > out/top30_clusters.sorted.tsv
join -a1 -a2 -e 0 -o 0,1.2,2.2 -t $'\t' \
  out/top30_overall.sorted.tsv out/top30_clusters.sorted.tsv \
| awk 'BEGIN{OFS="\t"; print "token","overall_count","clusters_count"}1' \
> out/top30_compare.tsv
comm -3 \
  <(cut -f1 out/top30_overall.txt | sort) \
  <(cut -f1 out/top30_clusters.txt | sort) \
  > out/diff_top30.txt
