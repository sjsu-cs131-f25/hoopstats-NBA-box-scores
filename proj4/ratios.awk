#!/usr/bin/awk -f

BEGIN {
    FS=","; OFS="\t"
    print "playerId", "avg_points_per_min", "games", "bucket"
}

NR == 1 { next }  # skip header

{
    playerId = $3
    minutes = $16
    points = $17

    # Guard against division by zero
    if (minutes == 0 || minutes == "") {
        ratio = 0
    } else {
        ratio = points / minutes
    }

    # Save cumulative stats per player
    games[playerId]++
    total_ratio[playerId] += ratio
}

END {
    for (id in games) {
        avg = total_ratio[id] / games[id]

        # Assign buckets
        if (avg == 0) bucket = "ZERO"
        else if (avg < 0.3) bucket = "LOW"
        else if (avg < 0.7) bucket = "MID"
        else bucket = "HIGH"

        printf "%s\t%.3f\t%d\t%s\n", id, avg, games[id], bucket
    }
}

