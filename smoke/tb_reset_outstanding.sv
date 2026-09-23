`timescale 1ns/1ps
module tb_reset_outstanding;
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
  logic retry_exhausted;
  logic replay_miss;

  integer tx_count = 0;
  logic [SEQ_W-1:0] first_seq;
  logic [SEQ_W-1:0] second_seq;

  ucie_adapter_top #(
    .REPLAY_DEPTH(4),
    .ACK_TIMEOUT_CYCLES(32),
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
    .retry_exhausted_seq_o(),
    .duplicate_o(),
    .sequence_error_o(),
    .seq_wrap_block_o()
  );

  always @(posedge clk) begin
    if (rst_n && rdi_valid) begin
      if (tx_count == 0)
        first_seq <= rdi_seq;
      else if (tx_count == 1)
        second_seq <= rdi_seq;
      tx_count <= tx_count + 1;
    end
  end

  task automatic send_payload(input logic [FLIT_W-1:0] data);
    begin
      fdi_data = data;
      fdi_valid = 1'b1;
      do @(posedge clk); while (!fdi_ready);
      #1;
      fdi_valid = 1'b0;
    end
  endtask

  initial begin
    fdi_valid = 0;
    fdi_data = '0;

    repeat (3) @(posedge clk);
    rst_n = 1;
    enable = 1;
    wait (link_active);

    send_payload(256'hA5A5);
    wait (tx_count == 1);
    #1;
    if (first_seq != 8'd0)
      $fatal(1, "first reliability epoch did not start at seq0");

    // Leave the first flit unacknowledged, then reset the adapter.
    @(negedge clk);
    rst_n = 0;
    repeat (2) @(posedge clk);
    if (link_active)
      $fatal(1, "link stayed active during reset");

    @(negedge clk);
    rst_n = 1;
    wait (link_active);

    // The outstanding replay entry must have been destroyed by reset.
    repeat (10) @(posedge clk);
    if (tx_count != 1)
      $fatal(1, "stale pre-reset flit replayed after reset");
    if (link_fault || replay_miss || retry_exhausted)
      $fatal(1, "reset/restart created a reliability fault");

    send_payload(256'h5A5A);
    wait (tx_count == 2);
    #1;
    if (second_seq != 8'd0)
      $fatal(1, "post-reset reliability epoch did not restart at seq0");

    $display("RESET/OUTSTANDING SMOKE PASS seqs=%0d,%0d", first_seq, second_seq);
    #20 $finish;
  end

  initial begin
    #5000 $fatal(1, "timeout");
  end
endmodule
