#!/usr/bin/awk -f

# ----------------------------
# Filter valid rows from player stats CSV
# ----------------------------

BEGIN {
    FS = ","      # Input field separator
    OFS = ","     # Output field separator
}

# Keep the header line
NR == 1 { print; next }

# Validation rules:
#  - Keep rows with non-empty names
#  - Positive minutes played
#  - Non-negative points
#  - Valid game year (>= 1950)
($1 != "" && $2 != "" &&   # firstName & lastName not empty
 $16 > 0 &&                # numMinutes > 0
 $17 >= 0 &&               # points >= 0
 $5 >= 1950) {             # gameYear >= 1950
    print
}

