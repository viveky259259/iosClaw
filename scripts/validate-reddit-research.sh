#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
reports=(
  "$repo_dir/reddit-research-batch-root.md"
  "$repo_dir/reddit-research-batch-a.md"
  "$repo_dir/reddit-research-batch-b.md"
  "$repo_dir/reddit-research-batch-c.md"
  "$repo_dir/reddit-research-supplement.md"
  "$repo_dir/reddit-research-supplement-2.md"
)

for report in "${reports[@]}"; do
  [[ -s "$report" ]] || { echo "missing report: $report" >&2; exit 1; }
done

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

for report in "${reports[@]}"; do
  rg '^\| ?[0-9]* ?\|? ?\*?\*?r/' "$report" \
    | sed -E 's/.*\| ?(\*\*)?(r\/[^|* ]+).*/\2/'
done | sort -u > "$tmp_file"

unique_count="$(wc -l < "$tmp_file" | tr -d ' ')"
if [[ "$unique_count" -ne 100 ]]; then
  echo "expected 100 unique subreddits, found $unique_count" >&2
  exit 1
fi

echo "Reddit research validation passed: $unique_count unique subreddits across ${#reports[@]} reports."
