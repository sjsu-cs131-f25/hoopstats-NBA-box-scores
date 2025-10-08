#!/usr/bin/env bash
set -euo pipefail

DATA=proj3/data/samples/playerstats_1k_year.csv
OUT=proj3/out
mkdir -p "$OUT"

# discover column indexes
COL_YEAR=$(head -1 "$DATA" | tr -d '\r' | awk -F, '{for(i=1;i<=NF;i++) if($i=="gameYear") print i}')
COL_PID=$( head -1 "$DATA" | tr -d '\r' | awk -F, '{for(i=1;i<=NF;i++) if($i=="personId") print i}')
COL_3PA=$( head -1 "$DATA" | tr -d '\r' | awk -F, '{for(i=1;i<=NF;i++) if($i=="threePointersAttempted") print i}')

if [ -z "${COL_YEAR:-}" ] || [ -z "${COL_PID:-}" ] || [ -z "${COL_3PA:-}" ]; then
  echo "ERROR: Missing header gameYear/personId/threePointersAttempted"; exit 1
fi

# edges: left=gameYear, right=personId
{ echo -e "gameYear\tpersonId"
  awk -F, -v y="$COL_YEAR" -v p="$COL_PID" 'NR>1{print $y "\t" $p}' "$DATA"
} > "$OUT/edges.tsv"

# token counts (by playerId) for thresholding
tail -n +2 "$OUT/edges.tsv" | cut -f2 | sort | uniq -c | sort -nr \
  | awk '{c=$1;$1="";sub(/^ +/,"");print $0 "\t" c}' \
  | sed '1itoken\tcount' > "$OUT/token_counts.tsv"

# --- threshold: THRESH_MANUAL overrides; else compute Q3 ---
if [ -n "${THRESH_MANUAL:-}" ]; then
  THRESH="$THRESH_MANUAL"; SRC="manual"
else
  tail -n +2 "$OUT/token_counts.tsv" | cut -f2 | sort -n > "$OUT/_counts.tmp"
  N=$(wc -l < "$OUT/_counts.tmp")
  if [ "$N" -gt 0 ]; then
    IDX=$(( (3*(N+1))/4 ))
    THRESH=$(awk -v k="$IDX" 'NR==k{print $1}' "$OUT/_counts.tmp")
  else
    THRESH=1
  fi
  SRC="auto_Q3"
  rm -f "$OUT/_counts.tmp"
fi
printf "source\tthreshold\n%s\t%s\n" "$SRC" "$THRESH" > "$OUT/thresholds.tsv"

# edges_thresholded: keep players with count >= THRESH
tail -n +2 "$OUT/edges.tsv"        | LC_ALL=C sort -t $'\t' -k2,2 > "$OUT/_edges.sort.byR.tsv"
tail -n +2 "$OUT/token_counts.tsv" | LC_ALL=C sort -t $'\t' -k1,1 > "$OUT/_tok.sort.tsv"
join -t $'\t' -1 2 -2 1 "$OUT/_edges.sort.byR.tsv" "$OUT/_tok.sort.tsv" \
  | awk -v t="$THRESH" '($3+0)>=t{print $2 "\t" $1}' \
  | { echo -e "gameYear\tpersonId"; cat; } > "$OUT/edges_thresholded.tsv"
rm -f "$OUT/_edges.sort.byR.tsv" "$OUT/_tok.sort.tsv"

# sizes per year (thresholded)
tail -n +2 "$OUT/edges_thresholded.tsv" | cut -f1 | sort | uniq -c | sort -k2,2 -k1,1nr \
  | awk '{c=$1;$1="";sub(/^ +/,"");print $0 "\t" c}' \
  | sed '1igameYear\tsize' > "$OUT/cluster_sizes_by_entity.tsv"

# histogram (size -> frequency)
tail -n +2 "$OUT/cluster_sizes_by_entity.tsv" | cut -f2 | sort -n | uniq -c | sort -k2,2n \
  | awk '{n=$2; f=$1; print n "\t" f}' \
  | sed '1isize\tfrequency' > "$OUT/cluster_sizes.tsv"

# Top-30 overall vs thresholded (token=playerId)
tail -n +2 "$OUT/edges.tsv" | cut -f2 | sort | uniq -c | sort -nr | head -30 \
  | awk '{c=$1;$1="";sub(/^ +/,"");print $0 "\t" c}' \
  | sed '1itoken\tcount' > "$OUT/top30_overall.txt"

tail -n +2 "$OUT/edges_thresholded.tsv" | cut -f2 | sort | uniq -c | sort -nr | head -30 \
  | awk '{c=$1;$1="";sub(/^ +/,"");print $0 "\t" c}' \
  | sed '1itoken\tcount' > "$OUT/top30_clusters.txt"

LC_ALL=C sort -t $'\t' -k1,1 "$OUT/top30_overall.txt"  > "$OUT/top30_overall.sorted.tsv"
LC_ALL=C sort -t $'\t' -k1,1 "$OUT/top30_clusters.txt" > "$OUT/top30_clusters.sorted.tsv"

join -a1 -a2 -e 0 -o 0,1.2,2.2 -t $'\t' \
  "$OUT/top30_overall.sorted.tsv" "$OUT/top30_clusters.sorted.tsv" \
  | sed '1itoken\toverall_count\tclusters_count' > "$OUT/top30_compare.tsv"

comm -3 \
  <(tail -n +2 "$OUT/top30_overall.sorted.tsv"  | cut -f1) \
  <(tail -n +2 "$OUT/top30_clusters.sorted.tsv" | cut -f1) > "$OUT/diff_top30.txt"

echo "DONE"
# --- outcomes per cluster (gameYear) using threePointersAttempted (no datamash needed) ---
# Produces: cluster_outcomes.tsv  AND  clusters_outcomes.tsv (both identical for teammates)
{
  echo -e "gameYear\tcount\tmean_3PA\tmedian_3PA"
  # Extract (year, 3PA), sort by year then value, then compute per-year stats
  awk -F, -v y="$COL_YEAR" -v v="$COL_3PA" 'NR>1 && $y!="" && $v!="" {print $y "\t" $v+0}' "$DATA" \
  | LC_ALL=C sort -t $'\t' -k1,1 -k2,2n \
  | awk -F'\t' '
      {
        if (NR==1) {prev=$1}
        if ($1!=prev) {
          mid=int((cnt+1)/2)
          if (cnt%2==1) med=vals[mid]; else med=(vals[mid]+vals[mid+1])/2
          mean=sum/cnt
          printf "%s\t%d\t%.6f\t%.6f\n", prev, cnt, mean, med
          delete vals; cnt=0; sum=0
          prev=$1
        }
        cnt++; sum+=$2; vals[cnt]=$2
      }
      END {
        if (cnt>0) {
          mid=int((cnt+1)/2)
          if (cnt%2==1) med=vals[mid]; else med=(vals[mid]+vals[mid+1])/2
          mean=sum/cnt
          printf "%s\t%d\t%.6f\t%.6f\n", prev, cnt, mean, med
        }
      }'
} > "$OUT/cluster_outcomes.tsv"

cp -f "$OUT/cluster_outcomes.tsv" "$OUT/clusters_outcomes.tsv"
