#!/usr/bin/env bash
set -euo pipefail

SEEDS="${SEEDS:-1 7 42 31415}"
REPORT_DIR="${REPORT_DIR:-reports/uvm}"
RESULTS_TSV="$REPORT_DIR/results.tsv"
SUMMARY_JSON="$REPORT_DIR/summary.json"

mkdir -p "$REPORT_DIR"
: > "$RESULTS_TSV"
overall_status=0

for seed in $SEEDS; do
  echo "=== UVM seed $seed ==="
  log="$REPORT_DIR/seed_${seed}.log"

  if SEED="$seed" ./scripts/run_questa.sh 2>&1 | tee "$log"; then
    verdict="PASS"
  else
    verdict="FAIL"
    overall_status=1
  fi

  printf '%s\t%s\t%s\n' "$seed" "$verdict" "$log" >> "$RESULTS_TSV"
done

python - "$RESULTS_TSV" "$SUMMARY_JSON" <<'PY'
import json
import pathlib
import sys

results_path = pathlib.Path(sys.argv[1])
summary_path = pathlib.Path(sys.argv[2])

runs = []
for raw in results_path.read_text(encoding="utf-8").splitlines():
    if not raw.strip():
        continue
    seed, status, log = raw.split("\t", 2)
    runs.append({"seed": int(seed), "status": status, "log": log})

summary = {
    "schema": "chipletlink.uvm-regression.v1",
    "runs": runs,
    "passed": sum(run["status"] == "PASS" for run in runs),
    "failed": sum(run["status"] == "FAIL" for run in runs),
    "overall": "PASS" if runs and all(run["status"] == "PASS" for run in runs) else "FAIL",
}

summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
print(f"Wrote {summary_path}")
PY

exit "$overall_status"
