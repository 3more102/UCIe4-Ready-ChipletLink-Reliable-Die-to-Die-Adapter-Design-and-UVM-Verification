#!/usr/bin/env bash
set -euo pipefail

mkdir -p build/synth reports/synth

yosys -q -l reports/synth/yosys.log -p '
  read_verilog -sv rtl/ucie_adapter_pkg.sv
  read_verilog -sv rtl/ucie_link_manager.sv
  read_verilog -sv rtl/ucie_replay_buffer.sv
  read_verilog -sv rtl/ucie_adapter_tx.sv
  read_verilog -sv rtl/ucie_adapter_rx.sv
  read_verilog -sv rtl/ucie_perf_counters.sv
  read_verilog -sv rtl/ucie_adapter_top.sv
  hierarchy -check -top ucie_adapter_top
  proc
  opt
  memory
  opt
  check
  synth -top ucie_adapter_top
  check
  tee -q -o reports/synth/stat.json stat -json -top ucie_adapter_top
  write_json reports/synth/netlist.json
  write_verilog -noattr build/synth/ucie_adapter_top_synth.v
'

python - <<'PY'
import json
from pathlib import Path

stat_path = Path("reports/synth/stat.json")
data = json.loads(stat_path.read_text(encoding="utf-8"))
modules = data.get("modules", {})
top = modules.get("\\ucie_adapter_top") or modules.get("ucie_adapter_top")
if top is None:
    raise SystemExit("ucie_adapter_top missing from Yosys statistics")

summary = {
    "schema": "chipletlink.yosys-synth.v1",
    "top": "ucie_adapter_top",
    "num_wires": top.get("num_wires"),
    "num_wire_bits": top.get("num_wire_bits"),
    "num_cells": top.get("num_cells"),
    "cell_types": top.get("num_cells_by_type", {}),
}

Path("reports/synth/summary.json").write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(summary, indent=2, sort_keys=True))
PY
