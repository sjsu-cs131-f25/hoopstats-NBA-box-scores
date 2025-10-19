#!/bin/bash

# Exit on error
set -e

# Create output directory
mkdir -p out

# Step 1: Filter invalid rows from the raw CSV
echo "Running filter_valid.awk now"
awk -f filter_valid.awk ../proj3/data/samples/playerstats_1k_year.csv > out/valid_rows.csv
echo "Valid rows written to out/valid_rows.csv"

# Step 2: Compute ratios and assign buckets
echo "Running ratios.awk now"
awk -f ratios.awk out/valid_rows.csv > out/ratios_summary.tsv
echo "Ratios summary written to out/ratios_summary.tsv"

# Step 3: Summarize total number of players in each bucket
echo "Summarizing buckets now"
awk 'NR>1 {counts[$4]++} END {for (b in counts) print b, counts[b]}' out/ratios_summary.tsv > out/bucket_summary.tsv
echo "Bucket summary written to out/bucket_summary.tsv"

echo "All steps have been completed"
