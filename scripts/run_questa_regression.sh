#!/usr/bin/env bash
set -euo pipefail

SEEDS="${SEEDS:-1 7 42 31415}"
mkdir -p reports/uvm

for seed in $SEEDS; do
  echo "=== UVM seed $seed ==="
  SEED="$seed" ./scripts/run_questa.sh | tee "reports/uvm/seed_${seed}.log"
done
