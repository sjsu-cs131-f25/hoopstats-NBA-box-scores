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

#Step 4: temporal summary (Year + 3PA)
echo "temporal_summary.tsv"
printf "year\tcount\tavg_3PA\n" > out/temporal_summary.tsv
awk -F'\t' 'BEGIN{OFS="\t"} NR==1{for(i=1;i<=NF;i++){h=$i;if(h~/^gameYear$/)yi=i;if(h~/^(threePA|3PA|threePointAttempts|3pt_attempts)$/)ai=i}next}{y=$yi+0;v=$ai+0;c[y]++;s[y]+=v}END{for(y in c)printf "%d\t%d\t%.3f\n",y,c[y],s[y]/c[y]}' out/filtered_data.tsv | sort -k1,1n >> out/temporal_summary.tsv

#Step 6: ranked numeric signals (plusMinus, points, assists, steals | win vs loss)
echo "ranked_signals.tsv"
printf "metric\tmean\tstd\tmin\tmax\toutliers>3sd\twin_avg\tloss_avg\twin_loss_diff\n" > out/ranked_signals.tsv
awk -F'\t' 'BEGIN{OFS="\t"} NR==1{for(i=1;i<=NF;i++){h=$i;if(h~/^(plusMinus|plusMinusPoints)$/)ipm=i;else if(h=="points")ipts=i;else if(h=="assists")iast=i;else if(h=="steals")istl=i;else if(h~/^(win|isWin|won)$/)iwin=i}next}{n++;vpm=$ipm+0;vpts=$ipts+0;vast=$iast+0;vstl=$istl+0;sum_pm+=vpm;sum_pts+=vpts;sum_ast+=vast;sum_stl+=vstl;sq_pm+=vpm*vpm;sq_pts+=vpts*vpts;sq_ast+=vast*vast;sq_stl+=vstl*vstl;if(n==1){min_pm=max_pm=vpm;min_pts=max_pts=vpts;min_ast=max_ast=vast;min_stl=max_stl=vstl}if(vpm<min_pm)min_pm=vpm;if(vpm>max_pm)max_pm=vpm;if(vpts<min_pts)min_pts=vpts;if(vpts>max_pts)max_pts=vpts;if(vast<min_ast)min_ast=vast;if(vast>max_ast)max_ast=vast;if(vstl<min_stl)min_stl=vstl;if(vstl>max_stl)max_stl=vstl;A_pm[n]=vpm;A_pts[n]=vpts;A_ast[n]=vast;A_stl[n]=vstl;if($iwin==1){w_pm+=vpm;cw_pm++;w_pts+=vpts;cw_pts++;w_ast+=vast;cw_ast++;w_stl+=vstl;cw_stl++}else if($iwin==0){l_pm+=vpm;cl_pm++;l_pts+=vpts;cl_pts++;l_ast+=vast;cl_ast++;l_stl+=vstl;cl_stl++}}END{m_pm=sum_pm/n;sd_pm=sqrt(sq_pm/n-m_pm*m_pm);m_pts=sum_pts/n;sd_pts=sqrt(sq_pts/n-m_pts*m_pts);m_ast=sum_ast/n;sd_ast=sqrt(sq_ast/n-m_ast*m_ast);m_stl=sum_stl/n;sd_stl=sqrt(sq_stl/n-m_stl*m_stl);thr_pm=m_pm+3*sd_pm;thr_pts=m_pts+3*sd_pts;thr_ast=m_ast+3*sd_ast;thr_stl=m_stl+3*sd_stl;for(i=1;i<=n;i++){if(A_pm[i]>thr_pm)o_pm++;if(A_pts[i]>thr_pts)o_pts++;if(A_ast[i]>thr_ast)o_ast++;if(A_stl[i]>thr_stl)o_stl++}wavg_pm=(cw_pm?w_pm/cw_pm:0);lavg_pm=(cl_pm?l_pm/cl_pm:0);diff_pm=wavg_pm-lavg_pm;wavg_pts=(cw_pts?w_pts/cw_pts:0);lavg_pts=(cl_pts?l_pts/cl_pts:0);diff_pts=wavg_pts-lavg_pts;wavg_ast=(cw_ast?w_ast/cw_ast:0);lavg_ast=(cl_ast?l_ast/cl_ast:0);diff_ast=wavg_ast-lavg_ast;wavg_stl=(cw_stl?w_stl/cw_stl:0);lavg_stl=(cl_stl?l_stl/cl_stl:0);diff_stl=wavg_stl-lavg_stl;printf "%s\t%.3f\t%.3f\t%.1f\t%.1f\t%d\t%.3f\t%.3f\t%.3f\n","plusMinus",m_pm,sd_pm,min_pm,max_pm,o_pm+0,wavg_pm,lavg_pm,diff_pm;printf "%s\t%.3f\t%.3f\t%.1f\t%.1f\t%d\t%.3f\t%.3f\t%.3f\n","points",m_pts,sd_pts,min_pts,max_pts,o_pts+0,wavg_pts,lavg_pts,diff_pts;printf "%s\t%.3f\t%.3f\t%.1f\t%.1f\t%d\t%.3f\t%.3f\t%.3f\n","assists",m_ast,sd_ast,min_ast,max_ast,o_ast+0,wavg_ast,lavg_ast,diff_ast;printf "%s\t%.3f\t%.3f\t%.1f\t%.1f\t%d\t%.3f\t%.3f\t%.3f\n","steals",m_stl,sd_stl,min_stl,max_stl,o_stl+0,wavg_stl,lavg_stl,diff_stl}' out/filtered_data.tsv | sort -k9,9nr >> out/ranked_signals.tsv

echo "All steps have been completed"

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
