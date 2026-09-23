`timescale 1ns/1ps
module tb_timeout;
  import ucie_adapter_pkg::*;

  logic clk = 0;
  always #5 clk = ~clk;

  logic rst_n = 0;
  logic enable = 0;
  logic fdi_valid;
  logic fdi_ready;
  logic [FLIT_W-1:0] fdi_data;

  logic rdi_valid;
  logic [FLIT_W-1:0] rdi_data;
  logic [SEQ_W-1:0] rdi_seq;
  logic [CRC_W-1:0] rdi_crc;

  logic link_active;
  logic link_fault;
  link_state_e link_state;
  logic replay_miss;
  logic retry_exhausted;
  logic [SEQ_W-1:0] retry_exhausted_seq;
  integer tx_count = 0;

  ucie_adapter_top #(
    .REPLAY_DEPTH(4),
    .ACK_TIMEOUT_CYCLES(4),
    .MAX_RETRIES(2)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .link_enable_i(enable),

    .fdi_tx_valid_i(fdi_valid),
    .fdi_tx_ready_o(fdi_ready),
    .fdi_tx_data_i(fdi_data),

    .fdi_rx_valid_o(),
    .fdi_rx_ready_i(1'b1),
    .fdi_rx_data_o(),

    .rdi_tx_valid_o(rdi_valid),
    .rdi_tx_ready_i(1'b1),
    .rdi_tx_data_o(rdi_data),
    .rdi_tx_seq_o(rdi_seq),
    .rdi_tx_crc_o(rdi_crc),

    .rdi_rx_valid_i(1'b0),
    .rdi_rx_ready_o(),
    .rdi_rx_data_i('0),
    .rdi_rx_seq_i('0),
    .rdi_rx_crc_i('0),

    .peer_ack_valid_i(1'b0),
    .peer_ack_seq_i('0),
    .peer_retry_valid_i(1'b0),
    .peer_retry_seq_i('0),

    .local_ack_valid_o(),
    .local_ack_seq_o(),
    .local_retry_valid_o(),
    .local_retry_seq_o(),

    .link_active_o(link_active),
    .link_fault_o(link_fault),
    .link_state_o(link_state),
    .crc_error_o(),
    .replay_miss_o(replay_miss),
    .retry_exhausted_o(retry_exhausted),
    .retry_exhausted_seq_o(retry_exhausted_seq),
    .duplicate_o(),
    .sequence_error_o(),
    .seq_wrap_block_o()
  );

  always @(posedge clk) begin
    if (rst_n && rdi_valid)
      tx_count <= tx_count + 1;
  end

  initial begin
    fdi_valid = 0;
    fdi_data = 256'hC0FFEE;

    repeat (3) @(posedge clk);
    rst_n = 1;
    enable = 1;

    wait (link_active);
    @(posedge clk);
    fdi_valid = 1;
    do @(posedge clk); while (!fdi_ready);
    #1 fdi_valid = 0;

    wait (retry_exhausted);
    #1;
    if (retry_exhausted_seq != 8'd0)
      $fatal(1, "retry exhaustion reported wrong sequence");
    if (tx_count != 3)
      $fatal(1, "expected original + 2 retries, observed %0d transfers", tx_count);
    if (replay_miss)
      $fatal(1, "timeout exhaustion must not be reported as replay miss");

    wait (link_fault);
    @(posedge clk);
    if (link_active)
      $fatal(1, "fatal retry exhaustion must disable the link");
    if (fdi_ready)
      $fatal(1, "source must remain backpressured while fault is latched");

    enable = 0;
    repeat (2) @(posedge clk);
    if (link_fault)
      $fatal(1, "administrative disable must clear the latched link fault");

    enable = 1;
    wait (link_active);
    if (link_fault)
      $fatal(1, "link fault unexpectedly persisted after disable/re-enable");

    $display("TIMEOUT/RETRY EXHAUSTION SMOKE PASS transfers=%0d", tx_count);
    #20 $finish;
  end

  initial begin
    #5000 $fatal(1, "timeout");
  end
endmodule
