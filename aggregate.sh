#!/usr/bin/env bash

# Exit on error
set -e

# Name of the output file
OUTPUT_FILE="aggregated_for_analysis.txt"

# 1. Write out a top-level header
echo "# Aggregated Project Information" > "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo >> "$OUTPUT_FILE"

# 2. Capture the directory tree (if 'tree' is installed)
echo "## Directory Structure" >> "$OUTPUT_FILE"
if command -v tree &> /dev/null
then
  # Run `tree` in current directory, ignoring the 'lib' if you want
  tree -a >> "$OUTPUT_FILE"
else
  # Fallback if 'tree' is not installed
  echo "(Note: 'tree' command not found. Below is a simpler ls -R.)" >> "$OUTPUT_FILE"
  ls -R >> "$OUTPUT_FILE"
fi
echo >> "$OUTPUT_FILE"
echo "--------------------------------------------------------" >> "$OUTPUT_FILE"
echo >> "$OUTPUT_FILE"

# 3. If diff.txt exists, append its contents
if [ -f "diff.txt" ]; then
  echo "## diff.txt Contents" >> "$OUTPUT_FILE"
  cat diff.txt >> "$OUTPUT_FILE"
  echo >> "$OUTPUT_FILE"
  echo "--------------------------------------------------------" >> "$OUTPUT_FILE"
  echo >> "$OUTPUT_FILE"
fi

# 4. Gather all Solidity files from src/, test/, script/ (adjust paths as needed)
#    For each file:
#       - Print a subheader
#       - Print code fenced content
echo "## Solidity Files" >> "$OUTPUT_FILE"

# Find .sol files under src/, test/, script/ recursively.
# Adjust these directories if your layout is different.
SOL_FILES=$(find src test script -type f -name "*.sol" 2>/dev/null || true)

if [ -z "$SOL_FILES" ]; then
  echo "No .sol files found in src/, test/, or script/." >> "$OUTPUT_FILE"
else
  for solfile in $SOL_FILES; do
    echo "### File: $solfile" >> "$OUTPUT_FILE"
    echo '```solidity' >> "$OUTPUT_FILE"
    cat "$solfile" >> "$OUTPUT_FILE"
    echo '```' >> "$OUTPUT_FILE"
    echo >> "$OUTPUT_FILE"
  done
fi

echo "--------------------------------------------------------" >> "$OUTPUT_FILE"
echo >> "$OUTPUT_FILE"

# 5. Print a final note
echo "Aggregation complete. All information is in '$OUTPUT_FILE'." >> "$OUTPUT_FILE"

# Optional: Show a summary message
echo "Created $OUTPUT_FILE with directory structure, diff.txt (if present), and all .sol files."

