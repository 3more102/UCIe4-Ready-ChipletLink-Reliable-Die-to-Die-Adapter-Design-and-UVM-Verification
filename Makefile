.PHONY: test lint smoke smoke-link smoke-replay smoke-duplicate smoke-timeout smoke-disable smoke-reset smoke-perf uvm clean

RTL_COMMON = \
	rtl/ucie_adapter_pkg.sv \
	rtl/ucie_link_manager.sv \
	rtl/ucie_replay_buffer.sv \
	rtl/ucie_adapter_tx.sv \
	rtl/ucie_adapter_rx.sv \
	rtl/ucie_perf_counters.sv \
	rtl/ucie_adapter_top.sv

test:
	python -m pytest -q

lint:
	verilator --lint-only -Wall -Wno-fatal --top-module ucie_adapter_top $(RTL_COMMON)

smoke: smoke-link smoke-replay smoke-duplicate smoke-timeout smoke-disable smoke-reset smoke-perf

smoke-link:
	mkdir -p build
	iverilog -g2012 -o build/smoke_link.vvp $(RTL_COMMON) smoke/tb_smoke.sv
	vvp build/smoke_link.vvp

smoke-replay:
	mkdir -p build
	iverilog -g2012 -o build/smoke_replay.vvp \
		rtl/ucie_adapter_pkg.sv rtl/ucie_replay_buffer.sv smoke/tb_replay_buffer.sv
	vvp build/smoke_replay.vvp

smoke-duplicate:
	mkdir -p build
	iverilog -g2012 -o build/smoke_duplicate.vvp \
		rtl/ucie_adapter_pkg.sv rtl/ucie_adapter_rx.sv smoke/tb_duplicate.sv
	vvp build/smoke_duplicate.vvp

smoke-timeout:
	mkdir -p build
	iverilog -g2012 -o build/smoke_timeout.vvp $(RTL_COMMON) smoke/tb_timeout.sv
	vvp build/smoke_timeout.vvp

smoke-disable:
	mkdir -p build
	iverilog -g2012 -o build/smoke_disable.vvp $(RTL_COMMON) smoke/tb_disable_flush.sv
	vvp build/smoke_disable.vvp

smoke-reset:
	mkdir -p build
	iverilog -g2012 -o build/smoke_reset.vvp $(RTL_COMMON) smoke/tb_reset_outstanding.sv
	vvp build/smoke_reset.vvp

smoke-perf:
	mkdir -p build
	iverilog -g2012 -o build/smoke_perf.vvp $(RTL_COMMON) smoke/tb_perf_counters.sv
	vvp build/smoke_perf.vvp

uvm:
	@echo "Run scripts/run_questa.sh with a simulator installation that provides UVM."

clean:
	rm -rf build work transcript vsim.wlf *.log *.vcd
