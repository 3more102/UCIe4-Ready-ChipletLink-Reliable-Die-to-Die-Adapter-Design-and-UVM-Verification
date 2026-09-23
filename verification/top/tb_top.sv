`timescale 1ns/1ps
module tb_top;
  import uvm_pkg::*;
  import ucie_adapter_pkg::*;
  import ucie_uvm_pkg::*;

  logic clk = 0;
  always #5ns clk = ~clk;
  logic rst_n;
  logic enable;

  fdi_if src_if(clk);
  fdi_if dst_if(clk);
  error_inject_if err_if(clk);

  logic a_link_active, b_link_active;
  link_state_e a_state, b_state;

  logic a_tx_v, a_tx_r;
  logic [FLIT_W-1:0] a_tx_d;
  logic [SEQ_W-1:0] a_tx_s;
  logic [CRC_W-1:0] a_tx_c;

  logic b_rx_v, b_rx_r;
  logic [FLIT_W-1:0] b_rx_d;
  logic [SEQ_W-1:0] b_rx_s;
  logic [CRC_W-1:0] b_rx_c;

  logic b_ack_v, b_retry_v;
  logic [SEQ_W-1:0] b_ack_s, b_retry_s;

  logic unused_a_rx_ready, unused_b_tx_valid;
  logic [FLIT_W-1:0] unused_b_tx_data;
  logic [SEQ_W-1:0] unused_b_tx_seq;
  logic [CRC_W-1:0] unused_b_tx_crc;
  logic a_crc_err, b_crc_err, a_replay_miss, b_replay_miss;
  logic a_dup, b_dup, a_seq_err, b_seq_err, a_seq_block, b_seq_block;

  ucie_adapter_top u_a (
    .clk(clk), .rst_n(rst_n), .link_enable_i(enable),
    .fdi_tx_valid_i(src_if.valid), .fdi_tx_ready_o(src_if.ready), .fdi_tx_data_i(src_if.data),
    .fdi_rx_valid_o(), .fdi_rx_ready_i(1'b1), .fdi_rx_data_o(),
    .rdi_tx_valid_o(a_tx_v), .rdi_tx_ready_i(a_tx_r), .rdi_tx_data_o(a_tx_d), .rdi_tx_seq_o(a_tx_s), .rdi_tx_crc_o(a_tx_c),
    .rdi_rx_valid_i(1'b0), .rdi_rx_ready_o(unused_a_rx_ready), .rdi_rx_data_i('0), .rdi_rx_seq_i('0), .rdi_rx_crc_i('0),
    .peer_ack_valid_i(b_ack_v), .peer_ack_seq_i(b_ack_s), .peer_retry_valid_i(b_retry_v), .peer_retry_seq_i(b_retry_s),
    .local_ack_valid_o(), .local_ack_seq_o(), .local_retry_valid_o(), .local_retry_seq_o(),
    .link_active_o(a_link_active), .link_state_o(a_state), .crc_error_o(a_crc_err), .replay_miss_o(a_replay_miss),
    .duplicate_o(a_dup), .sequence_error_o(a_seq_err), .seq_wrap_block_o(a_seq_block)
  );

  ucie_channel_model u_ch_ab (
    .clk(clk), .rst_n(rst_n),
    .tx_valid_i(a_tx_v), .tx_ready_o(a_tx_r), .tx_data_i(a_tx_d), .tx_seq_i(a_tx_s), .tx_crc_i(a_tx_c),
    .rx_valid_o(b_rx_v), .rx_ready_i(b_rx_r), .rx_data_o(b_rx_d), .rx_seq_o(b_rx_s), .rx_crc_o(b_rx_c),
    .inject_data_error_i(err_if.inject_data_error), .inject_crc_error_i(err_if.inject_crc_error), .bit_index_i(err_if.bit_index)
  );

  ucie_adapter_top u_b (
    .clk(clk), .rst_n(rst_n), .link_enable_i(enable),
    .fdi_tx_valid_i(1'b0), .fdi_tx_ready_o(), .fdi_tx_data_i('0),
    .fdi_rx_valid_o(dst_if.valid), .fdi_rx_ready_i(dst_if.ready), .fdi_rx_data_o(dst_if.data),
    .rdi_tx_valid_o(unused_b_tx_valid), .rdi_tx_ready_i(1'b1), .rdi_tx_data_o(unused_b_tx_data), .rdi_tx_seq_o(unused_b_tx_seq), .rdi_tx_crc_o(unused_b_tx_crc),
    .rdi_rx_valid_i(b_rx_v), .rdi_rx_ready_o(b_rx_r), .rdi_rx_data_i(b_rx_d), .rdi_rx_seq_i(b_rx_s), .rdi_rx_crc_i(b_rx_c),
    .peer_ack_valid_i(1'b0), .peer_ack_seq_i('0), .peer_retry_valid_i(1'b0), .peer_retry_seq_i('0),
    .local_ack_valid_o(b_ack_v), .local_ack_seq_o(b_ack_s), .local_retry_valid_o(b_retry_v), .local_retry_seq_o(b_retry_s),
    .link_active_o(b_link_active), .link_state_o(b_state), .crc_error_o(b_crc_err), .replay_miss_o(b_replay_miss),
    .duplicate_o(b_dup), .sequence_error_o(b_seq_err), .seq_wrap_block_o(b_seq_block)
  );

  ucie_adapter_sva sva_a (
    .clk(clk), .rst_n(rst_n), .link_active(a_link_active),
    .fdi_tx_ready(src_if.ready),
    .rdi_tx_valid(a_tx_v), .rdi_tx_ready(a_tx_r),
    .rdi_tx_data(a_tx_d), .rdi_tx_seq(a_tx_s), .rdi_tx_crc(a_tx_c),
    .crc_error(a_crc_err), .sequence_error(a_seq_err),
    .local_ack_valid(1'b0), .local_retry_valid(1'b0), .duplicate_event(a_dup)
  );

  ucie_adapter_sva sva_b (
    .clk(clk), .rst_n(rst_n), .link_active(b_link_active),
    .fdi_tx_ready(1'b0),
    .rdi_tx_valid(unused_b_tx_valid), .rdi_tx_ready(1'b1),
    .rdi_tx_data(unused_b_tx_data), .rdi_tx_seq(unused_b_tx_seq), .rdi_tx_crc(unused_b_tx_crc),
    .crc_error(b_crc_err), .sequence_error(b_seq_err),
    .local_ack_valid(b_ack_v), .local_retry_valid(b_retry_v), .duplicate_event(b_dup)
  );

  assign dst_if.ready = 1'b1;
  assign src_if.rst_n = rst_n;
  assign dst_if.rst_n = rst_n;

  initial begin
    rst_n = 0;
    enable = 0;
    err_if.inject_data_error = 0;
    err_if.inject_crc_error = 0;
    err_if.bit_index = 0;
    repeat (4) @(posedge clk);
    rst_n = 1;
    enable = 1;
  end

  initial begin
    uvm_config_db#(virtual fdi_if)::set(null,"uvm_test_top.env.src.*","vif",src_if);
    uvm_config_db#(virtual error_inject_if)::set(null,"uvm_test_top.env.src.drv","err_vif",err_if);
    uvm_config_db#(virtual fdi_if)::set(null,"uvm_test_top.env.dst_mon","vif",dst_if);
    run_test("ucie_reliability_test");
  end
endmodule
