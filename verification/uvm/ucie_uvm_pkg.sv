package ucie_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class ucie_flit extends uvm_sequence_item;
    rand bit [255:0] data;
    rand bit inject_data_error;
    rand bit inject_crc_error;
    rand int unsigned bit_index;

    constraint c_bit_index { bit_index < 256; }
    constraint c_errors { !(inject_data_error && inject_crc_error); }

    `uvm_object_utils_begin(ucie_flit)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_int(inject_data_error, UVM_ALL_ON)
      `uvm_field_int(inject_crc_error, UVM_ALL_ON)
      `uvm_field_int(bit_index, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name="ucie_flit"); super.new(name); endfunction
  endclass

  class ucie_sequence extends uvm_sequence #(ucie_flit);
    `uvm_object_utils(ucie_sequence)
    rand int unsigned count = 100;
    function new(string name="ucie_sequence"); super.new(name); endfunction

    task body();
      repeat (count) begin
        ucie_flit tr = ucie_flit::type_id::create("tr");
        start_item(tr);
        if (!tr.randomize() with {
          inject_data_error dist {1 := 5, 0 := 95};
          inject_crc_error  dist {1 := 5, 0 := 95};
        }) `uvm_fatal("RAND", "Randomization failed")
        finish_item(tr);
      end
    endtask
  endclass

  class ucie_driver extends uvm_driver #(ucie_flit);
    `uvm_component_utils(ucie_driver)
    virtual fdi_if vif;
    virtual error_inject_if err_vif;

    function new(string name, uvm_component parent); super.new(name,parent); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual fdi_if)::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","fdi_if not configured")
      if (!uvm_config_db#(virtual error_inject_if)::get(this,"","err_vif",err_vif))
        `uvm_fatal("NOVIF","error_inject_if not configured")
    endfunction

    task run_phase(uvm_phase phase);
      vif.drv_cb.valid <= 0;
      err_vif.inject_data_error <= 0;
      err_vif.inject_crc_error <= 0;
      forever begin
        seq_item_port.get_next_item(req);
        vif.drv_cb.data  <= req.data;
        vif.drv_cb.valid <= 1;
        err_vif.inject_data_error <= req.inject_data_error;
        err_vif.inject_crc_error  <= req.inject_crc_error;
        err_vif.bit_index <= req.bit_index;
        do @(vif.drv_cb); while (!vif.drv_cb.ready);
        vif.drv_cb.valid <= 0;
        err_vif.inject_data_error <= 0;
        err_vif.inject_crc_error <= 0;
        seq_item_port.item_done();
      end
    endtask
  endclass

  class ucie_monitor extends uvm_component;
    `uvm_component_utils(ucie_monitor)
    virtual fdi_if vif;
    uvm_analysis_port #(ucie_flit) ap;

    function new(string name, uvm_component parent);
      super.new(name,parent); ap = new("ap",this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual fdi_if)::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","fdi_if not configured")
    endfunction

    task run_phase(uvm_phase phase);
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.rst_n && vif.mon_cb.valid && vif.mon_cb.ready) begin
          ucie_flit tr = ucie_flit::type_id::create("mon_tr");
          tr.data = vif.mon_cb.data;
          ap.write(tr);
        end
      end
    endtask
  endclass

  class ucie_agent extends uvm_agent;
    `uvm_component_utils(ucie_agent)
    uvm_sequencer #(ucie_flit) seqr;
    ucie_driver drv;
    ucie_monitor mon;

    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      seqr = new("seqr",this);
      drv = ucie_driver::type_id::create("drv",this);
      mon = ucie_monitor::type_id::create("mon",this);
    endfunction
    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
  endclass

  `uvm_analysis_imp_decl(_exp)
  `uvm_analysis_imp_decl(_act)

  class ucie_scoreboard extends uvm_component;
    `uvm_component_utils(ucie_scoreboard)
    uvm_analysis_imp_exp #(ucie_flit, ucie_scoreboard) exp_imp;
    uvm_analysis_imp_act #(ucie_flit, ucie_scoreboard) act_imp;
    bit [255:0] expected_q[$];
    int unsigned matches;
    int unsigned mismatches;

    function new(string name, uvm_component parent);
      super.new(name,parent);
      exp_imp = new("exp_imp",this);
      act_imp = new("act_imp",this);
    endfunction

    function void write_exp(ucie_flit t);
      expected_q.push_back(t.data);
    endfunction

    function void write_act(ucie_flit t);
      bit [255:0] exp;
      if (expected_q.size() == 0) begin
        mismatches++;
        `uvm_error("SCB","Unexpected output flit")
        return;
      end
      exp = expected_q.pop_front();
      if (exp !== t.data) begin
        mismatches++;
        `uvm_error("SCB",$sformatf("Mismatch exp=%h act=%h",exp,t.data))
      end else matches++;
    endfunction

    function void check_phase(uvm_phase phase);
      if (expected_q.size() != 0)
        `uvm_error("SCB",$sformatf("%0d expected flits were not delivered",expected_q.size()))
      `uvm_info("SCB",$sformatf("matches=%0d mismatches=%0d",matches,mismatches),UVM_LOW)
    endfunction
  endclass

  class ucie_reliability_coverage extends uvm_component;
    `uvm_component_utils(ucie_reliability_coverage)
    virtual reliability_if vif;

    covergroup reliability_cg with function sample(
      bit [2:0] state,
      bit backpressure,
      bit crc_error,
      bit sequence_error,
      bit duplicate_event,
      bit replay_miss,
      bit retry_exhausted
    );
      option.per_instance = 1;

      cp_state: coverpoint state {
        bins reset    = {3'd0};
        bins init     = {3'd1};
        bins active   = {3'd2};
        bins recovery = {3'd3};
        bins disabled = {3'd4};
        illegal_bins reserved = default;
      }

      cp_backpressure: coverpoint backpressure {
        bins flowing = {0};
        bins stalled = {1};
      }

      cp_crc_error: coverpoint crc_error { bins hit = {1}; }
      cp_sequence_error: coverpoint sequence_error { bins hit = {1}; }
      cp_duplicate: coverpoint duplicate_event { bins hit = {1}; }

      cp_fatal: coverpoint {retry_exhausted, replay_miss} {
        bins none            = {2'b00};
        bins replay_miss     = {2'b01};
        bins retry_exhausted = {2'b10};
        illegal_bins both    = {2'b11};
      }

      cx_state_crc: cross cp_state, cp_crc_error;
      cx_state_sequence: cross cp_state, cp_sequence_error;
      cx_state_backpressure: cross cp_state, cp_backpressure;
    endgroup

    function new(string name, uvm_component parent);
      super.new(name,parent);
      reliability_cg = new();
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual reliability_if)::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","reliability_if not configured")
    endfunction

    task run_phase(uvm_phase phase);
      forever begin
        @(posedge vif.clk);
        if (vif.rst_n) begin
          reliability_cg.sample(
            vif.link_state,
            vif.rdi_valid && !vif.rdi_ready,
            vif.crc_error,
            vif.sequence_error,
            vif.duplicate,
            vif.replay_miss,
            vif.retry_exhausted
          );
        end
      end
    endtask
  endclass

  class ucie_env extends uvm_env;
    `uvm_component_utils(ucie_env)
    ucie_agent src;
    ucie_monitor dst_mon;
    ucie_scoreboard scb;
    ucie_reliability_coverage cov;

    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      src = ucie_agent::type_id::create("src",this);
      dst_mon = ucie_monitor::type_id::create("dst_mon",this);
      scb = ucie_scoreboard::type_id::create("scb",this);
      cov = ucie_reliability_coverage::type_id::create("cov",this);
    endfunction
    function void connect_phase(uvm_phase phase);
      src.mon.ap.connect(scb.exp_imp);
      dst_mon.ap.connect(scb.act_imp);
    endfunction
  endclass

  class ucie_reliability_test extends uvm_test;
    `uvm_component_utils(ucie_reliability_test)
    ucie_env env;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = ucie_env::type_id::create("env",this);
    endfunction
    task run_phase(uvm_phase phase);
      ucie_sequence seq = ucie_sequence::type_id::create("seq");
      phase.raise_objection(this);
      seq.count = 250;
      seq.start(env.src.seqr);
      repeat (100) #10ns;
      phase.drop_objection(this);
    endtask
  endclass
endpackage
