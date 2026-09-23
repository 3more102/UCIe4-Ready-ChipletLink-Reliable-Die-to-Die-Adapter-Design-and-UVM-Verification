.PHONY: test smoke smoke-link smoke-replay smoke-duplicate uvm clean

RTL_COMMON = \
	rtl/ucie_adapter_pkg.sv \
	rtl/ucie_link_manager.sv \
	rtl/ucie_replay_buffer.sv \
	rtl/ucie_adapter_tx.sv \
	rtl/ucie_adapter_rx.sv \
	rtl/ucie_adapter_top.sv

test:
	python -m pytest -q

smoke: smoke-link smoke-replay smoke-duplicate

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

uvm:
	@echo "Run scripts/run_questa.sh with a simulator installation that provides UVM."

clean:
	rm -rf build work transcript vsim.wlf *.log *.vcd
