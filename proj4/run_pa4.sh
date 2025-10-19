#!/bin/bash

# Exit on error
set -e

# Create output directory
mkdir -p out

# Step 1: filter invalid rows from the raw CSV
echo "Running filter_valid.awk now"
awk -f filter_valid.awk ../proj3/data/samples/playerstats_1k_year.csv > out/filtered_data.tsv
echo "Valid rows written to out/filtered_data.tsv"

# Step 2: compute ratios and assign buckets
echo "Running ratios.awk now"
awk -f ratios.awk out/filtered_data.tsv > out/entity_summary.tsv
echo "Ratios summary written to out/entity_summary.tsv"

# Step 3: summarize total number of players in each bucket
echo "Summarizing buckets now"
awk 'NR>1 {counts[$4]++} END {for (b in counts) print b, counts[b]}' out/entity_summary.tsv > out/bucket_summary.tsv
echo "Bucket summary written to out/bucket_summary.tsv"

echo "All steps have been completed"

