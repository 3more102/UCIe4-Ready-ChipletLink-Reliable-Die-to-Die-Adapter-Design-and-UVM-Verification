#!/usr/bin/env bash
set -euo pipefail

SEED="${SEED:-1}"
TEST="${TEST:-ucie_reliability_test}"

rm -rf work
vlib work
vlog -sv \
  +incdir+$UVM_HOME/src \
  $UVM_HOME/src/uvm_pkg.sv \
  rtl/ucie_adapter_pkg.sv \
  rtl/ucie_link_manager.sv \
  rtl/ucie_replay_buffer.sv \
  rtl/ucie_adapter_tx.sv \
  rtl/ucie_adapter_rx.sv \
  rtl/ucie_adapter_top.sv \
  verification/interfaces/fdi_if.sv \
  verification/interfaces/error_inject_if.sv \
  verification/interfaces/reliability_if.sv \
  verification/channel/ucie_channel_model.sv \
  verification/uvm/ucie_uvm_pkg.sv \
  verification/sva/ucie_adapter_sva.sv \
  verification/top/tb_top.sv

vsim -c -sv_seed "$SEED" tb_top +UVM_TESTNAME="$TEST" -do "run -all; quit -f"
