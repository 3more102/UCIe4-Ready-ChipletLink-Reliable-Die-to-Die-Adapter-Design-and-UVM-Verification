`timescale 1ns/1ps
module tb_smoke;
  import ucie_adapter_pkg::*;
  logic clk = 0;
  always #5 clk = ~clk;
  logic rst_n = 0, enable = 0;

  logic a_fv, a_fr;
  logic [FLIT_W-1:0] a_fd;
  logic b_ov;
  logic [FLIT_W-1:0] b_od;

  logic av, ar;
  logic [FLIT_W-1:0] ad;
  logic [SEQ_W-1:0] as;
  logic [CRC_W-1:0] ac;
  logic bv, br;
  logic [FLIT_W-1:0] bd;
  logic [SEQ_W-1:0] bs;
  logic [CRC_W-1:0] bc;
  logic ackv, retryv;
  logic [SEQ_W-1:0] acks, retrys;
  logic a_active, b_active;
  link_state_e ast, bst;
  logic inject_once;
  logic [3:0] attempts;

  ucie_adapter_top a (
    .clk(clk), .rst_n(rst_n), .link_enable_i(enable),
    .fdi_tx_valid_i(a_fv), .fdi_tx_ready_o(a_fr), .fdi_tx_data_i(a_fd),
    .fdi_rx_valid_o(), .fdi_rx_ready_i(1'b1), .fdi_rx_data_o(),
    .rdi_tx_valid_o(av), .rdi_tx_ready_i(ar), .rdi_tx_data_o(ad), .rdi_tx_seq_o(as), .rdi_tx_crc_o(ac),
    .rdi_rx_valid_i(1'b0), .rdi_rx_ready_o(), .rdi_rx_data_i('0), .rdi_rx_seq_i('0), .rdi_rx_crc_i('0),
    .peer_ack_valid_i(ackv), .peer_ack_seq_i(acks), .peer_retry_valid_i(retryv), .peer_retry_seq_i(retrys),
    .local_ack_valid_o(), .local_ack_seq_o(), .local_retry_valid_o(), .local_retry_seq_o(),
    .link_active_o(a_active), .link_state_o(ast), .crc_error_o(), .replay_miss_o(),
    .duplicate_o(), .sequence_error_o(), .seq_wrap_block_o()
  );

  assign ar = br;
  assign bv = av;
  assign bd = inject_once ? (ad ^ {{(FLIT_W-1){1'b0}},1'b1}) : ad;
  assign bs = as;
  assign bc = ac;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      inject_once <= 1'b1;
      attempts <= '0;
    end else if (av && ar) begin
      attempts <= attempts + 1'b1;
      if (inject_once) inject_once <= 1'b0;
    end
  end

  ucie_adapter_top b (
    .clk(clk), .rst_n(rst_n), .link_enable_i(enable),
    .fdi_tx_valid_i(1'b0), .fdi_tx_ready_o(), .fdi_tx_data_i('0),
    .fdi_rx_valid_o(b_ov), .fdi_rx_ready_i(1'b1), .fdi_rx_data_o(b_od),
    .rdi_tx_valid_o(), .rdi_tx_ready_i(1'b1), .rdi_tx_data_o(), .rdi_tx_seq_o(), .rdi_tx_crc_o(),
    .rdi_rx_valid_i(bv), .rdi_rx_ready_o(br), .rdi_rx_data_i(bd), .rdi_rx_seq_i(bs), .rdi_rx_crc_i(bc),
    .peer_ack_valid_i(1'b0), .peer_ack_seq_i('0), .peer_retry_valid_i(1'b0), .peer_retry_seq_i('0),
    .local_ack_valid_o(ackv), .local_ack_seq_o(acks), .local_retry_valid_o(retryv), .local_retry_seq_o(retrys),
    .link_active_o(b_active), .link_state_o(bst), .crc_error_o(), .replay_miss_o(),
    .duplicate_o(), .sequence_error_o(), .seq_wrap_block_o()
  );

  initial begin
    a_fv = 0;
    a_fd = '0;
    repeat (4) @(posedge clk);
    rst_n = 1;
    enable = 1;
    wait(a_active && b_active);
    @(posedge clk);
    a_fd = 256'h0123456789abcdef_0011223344556677_8899aabbccddeeff_deadbeefcafef00d;
    a_fv = 1;
    do @(posedge clk); while(!a_fr);
    a_fv = 0;
    wait(b_ov);
    if (b_od !== a_fd) $fatal(1,"payload mismatch");
    if (attempts < 2) $fatal(1,"expected retry/replay path");
    $display("SMOKE PASS attempts=%0d data=%h", attempts, b_od);
    #20 $finish;
  end

  initial begin
    #5000 $fatal(1,"timeout");
  end
endmodule
