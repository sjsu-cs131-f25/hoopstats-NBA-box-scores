#!/usr/bin/awk -f

BEGIN {
    FS=","; OFS=","   # Input and output field separators
}

# Keep the header line
NR == 1 { print; next }

# Validation rules:
#  - non-empty name fields
#  - positive minutes
#  - non-negative points
#  - valid game year
($1 != "" && $2 != "" && $16 > 0 && $17 >= 0 && $5 >= 1950) {
    print
}

