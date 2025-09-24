## Data Card — PlayerStatistics.csv
- Source: Kaggle – Historical NBA Data & Player Box Scores (Eoin Moore)
  Link: https://www.kaggle.com/datasets/eoinamoore/historical-nba-data-and-player-box-scores
- Format(s): CSV
- Compression: ZIP package (download); CSV uncompressed on disk
- Size: ~293 MB; Rows ≈ 1,627,439 (including header); Columns = 35
- Delimiter: comma
- Header: present
- Encoding: UTF-8 (verified via `file -bi`)
- Notes: some missing fields, some stats that you would expect to be integers appear as decimals
- Reproducibility checks:
  - `unzip -p PlayerStatistics.zip PlayerStatistics.csv | wc -l  # row count`
  - `unzip -p PlayerStatistics.zip PlayerStatistics.csv | head -n1 | awk -F',' '{print NF}'  # columns`
