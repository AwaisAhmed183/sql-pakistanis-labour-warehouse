#!/usr/bin/env bash
# Build the whole project from scratch: fresh database, all checks, all
# analysis results. One command, from the project root:
#
#     bash build.sh
#
# It deletes labour_warehouse.db and rebuilds it from the CSVs in data/,
# then runs every SQL file and regenerates everything in results/.
# The database file itself is not committed (see .gitignore) — it is
# always rebuilt by this script.
set -euo pipefail
cd "$(dirname "$0")"

rm -f labour_warehouse.db
python3 load_data.py
python3 run_queries.py
python3 verify.py

echo ""
echo "Done."
echo "  Database: labour_warehouse.db"
echo "  Results:  results/"
echo "  Explore:  sqlite3 labour_warehouse.db"
echo "  Dashboard: streamlit run app.py"
