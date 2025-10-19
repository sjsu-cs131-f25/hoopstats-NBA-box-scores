#!/usr/bin/env bash
# Usage: ./run_pa4.sh data/{csv}

set -euo pipefail
IFS=$'\n\t'

die() { echo "ERROR: $*" >&2; exit 1; }
log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }

TEAM_NAME=${1:-}
DATASET_PATH=${2:-}
cd ../../../${TEAM_NAME}/ || die "Cannot cd to dir"
OUT_DIR="out"
LOG_DIR="log"
mkdir -p "$OUT_DIR"/{samples,clean} "$LOG_DIR"
LOG_FILE="${LOG_DIR}/pa4_$(date '+%Y%m%d_%H%M%S').log"
exec 1> >(tee -a "$LOG_FILE") 2>&1
[ -z "$TEAM_NAME" ] && die "Usage: $0 <team-name> <input-dir>"
[ -z "$DATASET_PATH" ] && die "Usage: $0 <input-dir>"


chmod -R g+rX "$(dirname "$DATASET_PATH")" || log "warn: could not chmod inputs"

if [ -d "$DATASET_PATH" ]; then
  log "Processing all CSVs in dir: $DATASET_PATH"
  for csv in "$DATASET_PATH"/*.csv; do
    [ -f "$csv" ] || { log "No CSV files found in $DATASET_PATH"; exit 1; }
    BASENAME=$(basename "$csv")
    NAME=${BASENAME%.*}
    CLEAN="$OUT_DIR/clean/${NAME}.tsv"
    log "Cleaning & normalizing $csv -> $CLEAN"

    sed -E "
      s/\r//g; \
      s/^[[:space:]]+//; \
      s/[[:space:]]+$//; \
      s/[[:space:]]*,[[:space:]]*/,/g; \
      s/\[[^]]*\]//g; \
      s/(^|,)([Nn][Aa]|NULL)(,|$)/\1\3/g; \
      s/,,/,NA,/g; \
      s/,/\t/g; \
      s/\tNA\t/\t/g;
      s/\t\t/\tNA\t/g 
    "  "$csv" > "$CLEAN"
   log "check"
    head -n 10 "$csv" > "$OUT_DIR/samples/sample_before_${NAME}.txt"
    head -n 10 "$CLEAN" > "$OUT_DIR/samples/sample_after_${NAME}.tsv"

    log "Saved before/after samples in $OUT_DIR/samples/"


  done
  if [ -f "out/clean/Games.tsv" ]; then
      { tail -n +2 "out/clean/Games.tsv" | cut -f4; \
        tail -n +2 "out/clean/Games.tsv" | cut -f6; } \
        | sort | awk 'NF==0{$0="<EMPTY>"}{print}' | uniq -c | sort -nr \
        | awk '{print $2 "\t" $1}' | sed '1iTeam\tCount' > out/freq_team.tsv
        log "Made frequency table number 1"
  fi
  if [ -f "out/clean/Players.tsv" ]; then
      tail -n +2 "out/clean/Players.tsv" | cut -f7 | sort | uniq -c | sort -nr \
      | awk '{print $2 "\t" $1}' | sed '1iHeight\tCount' > out/freq_height.tsv
      log "Made frequency table number 2"

      tail -n +2 "out/clean/Players.tsv" | cut -f5 | grep -v '^[[:space:]]*$' | sort | uniq -c | sort -nr | head -n 20 \
      | awk '{print NR "\t" $2 "\t" $1}' | sed '1iRank\tLast_Attended\tCount' > out/top20_colleges.tsv || true
      log "Made top-N list"
  fi
  if [ -f "out/clean/PlayerStatistics.tsv" ]; then
      cut -f7,9,21,22,23 "out/clean/PlayerStatistics.tsv" | sort -u | \
      sed '1iplayerteamName\topponentteamName\tfieldGoalsAttempted\tfieldGoalsMade\tfieldGoalsPercentage' > out/skinny_table.tsv
      log "Made skinny table"
  fi  
fi

cd ./hoopstats-NBA-box-scores/proj4
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

