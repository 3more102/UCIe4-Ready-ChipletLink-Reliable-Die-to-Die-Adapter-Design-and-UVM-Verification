`timescale 1ns/1ps
module tb_perf_counters;
  import ucie_adapter_pkg::*;

  logic clk = 0;
  always #5 clk = ~clk;

  logic rst_n = 0;
  logic enable = 0;
  logic fdi_valid = 0;
  logic fdi_ready;
  logic [FLIT_W-1:0] fdi_data = '0;

  logic rdi_valid;
  logic rdi_ready = 1;
  logic [FLIT_W-1:0] rdi_data;
  logic [SEQ_W-1:0] rdi_seq;
  logic [CRC_W-1:0] rdi_crc;

  logic peer_retry_valid = 0;
  logic [SEQ_W-1:0] peer_retry_seq = '0;

  logic link_active;
  logic link_fault;

  logic [31:0] perf_active_cycles;
  logic [31:0] perf_fdi_tx_accepts;
  logic [31:0] perf_rdi_tx_transfers;
  logic [31:0] perf_fdi_rx_deliveries;
  logic [31:0] perf_retry_requests;
  logic [31:0] perf_error_events;
  logic [31:0] perf_tx_stall_cycles;

  ucie_adapter_top #(
    .REPLAY_DEPTH(8),
    .ACK_TIMEOUT_CYCLES(200),
    .MAX_RETRIES(3),
    .PERF_COUNTER_W(32)
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
    .rdi_tx_ready_i(rdi_ready),
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
    .peer_retry_valid_i(peer_retry_valid),
    .peer_retry_seq_i(peer_retry_seq),
    .local_ack_valid_o(),
    .local_ack_seq_o(),
    .local_retry_valid_o(),
    .local_retry_seq_o(),
    .link_active_o(link_active),
    .link_fault_o(link_fault),
    .link_state_o(),
    .crc_error_o(),
    .replay_miss_o(),
    .retry_exhausted_o(),
    .retry_exhausted_seq_o(),
    .duplicate_o(),
    .sequence_error_o(),
    .seq_wrap_block_o(),
    .perf_active_cycles_o(perf_active_cycles),
    .perf_fdi_tx_accepts_o(perf_fdi_tx_accepts),
    .perf_rdi_tx_transfers_o(perf_rdi_tx_transfers),
    .perf_fdi_rx_deliveries_o(perf_fdi_rx_deliveries),
    .perf_retry_requests_o(perf_retry_requests),
    .perf_error_events_o(perf_error_events),
    .perf_tx_stall_cycles_o(perf_tx_stall_cycles)
  );

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
    repeat (3) @(posedge clk);
    rst_n = 1;
    enable = 1;
    wait (link_active);

    send_payload(256'h1001);
    send_payload(256'h1002);
    wait (perf_fdi_tx_accepts == 2 && perf_rdi_tx_transfers == 2);

    // Hold a third flit while the RDI side is backpressured.
    rdi_ready = 0;
    fdi_data = 256'h1003;
    fdi_valid = 1;
    repeat (3) @(posedge clk);
    if (perf_tx_stall_cycles < 2)
      $fatal(1, "stall counter did not observe backpressure");

    rdi_ready = 1;
    do @(posedge clk); while (!fdi_ready);
    #1;
    fdi_valid = 0;

    wait (perf_fdi_tx_accepts == 3 && perf_rdi_tx_transfers == 3);

    // Request a replay of sequence zero; this transfer is overhead beyond
    // the three protocol-side accepts.
    peer_retry_seq = 8'd0;
    peer_retry_valid = 1;
    @(posedge clk);
    #1;
    peer_retry_valid = 0;

    wait (perf_retry_requests == 1);
    wait (perf_rdi_tx_transfers == 4);
    repeat (2) @(posedge clk);

    if (perf_fdi_tx_accepts != 3)
      $fatal(1, "unexpected protocol accept count: %0d", perf_fdi_tx_accepts);
    if (perf_rdi_tx_transfers != 4)
      $fatal(1, "unexpected RDI transfer count: %0d", perf_rdi_tx_transfers);
    if (perf_rdi_tx_transfers - perf_fdi_tx_accepts != 1)
      $fatal(1, "replay overhead was not reflected in transfer counters");
    if (perf_retry_requests != 1)
      $fatal(1, "retry request counter mismatch: %0d", perf_retry_requests);
    if (perf_fdi_rx_deliveries != 0)
      $fatal(1, "unexpected RX delivery count");
    if (perf_error_events != 0 || link_fault)
      $fatal(1, "clean replay test unexpectedly recorded a fatal/error event");
    if (perf_active_cycles == 0)
      $fatal(1, "active cycle counter never advanced");

    $display(
      "PERF COUNTERS PASS accepts=%0d rdi=%0d retry=%0d stalls=%0d active=%0d",
      perf_fdi_tx_accepts,
      perf_rdi_tx_transfers,
      perf_retry_requests,
      perf_tx_stall_cycles,
      perf_active_cycles
    );
    #20 $finish;
  end

  initial begin
    #5000 $fatal(1, "timeout");
  end
endmodule
