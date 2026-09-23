`timescale 1ns/1ps
module tb_backpressure;
  import ucie_adapter_pkg::*;

  logic clk = 0;
  always #5 clk = ~clk;

  logic rst_n = 0;
  logic enable = 0;

  logic src_valid = 0;
  logic src_ready;
  logic [FLIT_W-1:0] src_data = '0;

  logic a_rdi_valid, a_rdi_ready;
  logic [FLIT_W-1:0] a_rdi_data;
  logic [SEQ_W-1:0] a_rdi_seq;
  logic [CRC_W-1:0] a_rdi_crc;

  logic b_rdi_ready;
  logic dst_valid;
  logic dst_ready = 1;
  logic [FLIT_W-1:0] dst_data;

  logic ack_valid, retry_valid;
  logic [SEQ_W-1:0] ack_seq, retry_seq;

  logic a_active, b_active;
  logic [31:0] a_stall_cycles;

  logic [FLIT_W-1:0] expected [0:3];
  integer delivered = 0;
  integer stall_start_count = 0;

  ucie_adapter_top a (
    .clk(clk), .rst_n(rst_n), .link_enable_i(enable),
    .fdi_tx_valid_i(src_valid), .fdi_tx_ready_o(src_ready), .fdi_tx_data_i(src_data),
    .fdi_rx_valid_o(), .fdi_rx_ready_i(1'b1), .fdi_rx_data_o(),
    .rdi_tx_valid_o(a_rdi_valid), .rdi_tx_ready_i(a_rdi_ready),
    .rdi_tx_data_o(a_rdi_data), .rdi_tx_seq_o(a_rdi_seq), .rdi_tx_crc_o(a_rdi_crc),
    .rdi_rx_valid_i(1'b0), .rdi_rx_ready_o(),
    .rdi_rx_data_i('0), .rdi_rx_seq_i('0), .rdi_rx_crc_i('0),
    .peer_ack_valid_i(ack_valid), .peer_ack_seq_i(ack_seq),
    .peer_retry_valid_i(retry_valid), .peer_retry_seq_i(retry_seq),
    .local_ack_valid_o(), .local_ack_seq_o(), .local_retry_valid_o(), .local_retry_seq_o(),
    .link_active_o(a_active), .link_fault_o(), .link_state_o(),
    .crc_error_o(), .replay_miss_o(), .retry_exhausted_o(), .retry_exhausted_seq_o(),
    .duplicate_o(), .sequence_error_o(), .seq_wrap_block_o(),
    .perf_active_cycles_o(), .perf_fdi_tx_accepts_o(), .perf_rdi_tx_transfers_o(),
    .perf_fdi_rx_deliveries_o(), .perf_retry_requests_o(), .perf_error_events_o(),
    .perf_tx_stall_cycles_o(a_stall_cycles)
  );

  assign a_rdi_ready = b_rdi_ready;

  ucie_adapter_top b (
    .clk(clk), .rst_n(rst_n), .link_enable_i(enable),
    .fdi_tx_valid_i(1'b0), .fdi_tx_ready_o(), .fdi_tx_data_i('0),
    .fdi_rx_valid_o(dst_valid), .fdi_rx_ready_i(dst_ready), .fdi_rx_data_o(dst_data),
    .rdi_tx_valid_o(), .rdi_tx_ready_i(1'b1), .rdi_tx_data_o(), .rdi_tx_seq_o(), .rdi_tx_crc_o(),
    .rdi_rx_valid_i(a_rdi_valid), .rdi_rx_ready_o(b_rdi_ready),
    .rdi_rx_data_i(a_rdi_data), .rdi_rx_seq_i(a_rdi_seq), .rdi_rx_crc_i(a_rdi_crc),
    .peer_ack_valid_i(1'b0), .peer_ack_seq_i('0),
    .peer_retry_valid_i(1'b0), .peer_retry_seq_i('0),
    .local_ack_valid_o(ack_valid), .local_ack_seq_o(ack_seq),
    .local_retry_valid_o(retry_valid), .local_retry_seq_o(retry_seq),
    .link_active_o(b_active), .link_fault_o(), .link_state_o(),
    .crc_error_o(), .replay_miss_o(), .retry_exhausted_o(), .retry_exhausted_seq_o(),
    .duplicate_o(), .sequence_error_o(), .seq_wrap_block_o(),
    .perf_active_cycles_o(), .perf_fdi_tx_accepts_o(), .perf_rdi_tx_transfers_o(),
    .perf_fdi_rx_deliveries_o(), .perf_retry_requests_o(), .perf_error_events_o(),
    .perf_tx_stall_cycles_o()
  );

  task automatic send_payload(input logic [FLIT_W-1:0] data);
    begin
      src_data = data;
      src_valid = 1'b1;
      do @(posedge clk); while (!src_ready);
      #1;
      src_valid = 1'b0;
    end
  endtask

  always @(posedge clk) begin
    if (rst_n && dst_valid && dst_ready) begin
      if (delivered >= 4)
        $fatal(1, "unexpected extra delivery");
      if (dst_data !== expected[delivered])
        $fatal(1, "delivery mismatch idx=%0d exp=%h got=%h",
               delivered, expected[delivered], dst_data);
      delivered <= delivered + 1;
    end
  end

  initial begin
    expected[0] = 256'h11;
    expected[1] = 256'h22;
    expected[2] = 256'h33;
    expected[3] = 256'h44;

    repeat (3) @(posedge clk);
    rst_n = 1;
    enable = 1;
    wait (a_active && b_active);

    // Force the receiver output to hold the first accepted flit. The second
    // source flit must then propagate backpressure all the way to adapter A.
    dst_ready = 0;
    fork
      begin
        send_payload(expected[0]);
        send_payload(expected[1]);
        send_payload(expected[2]);
        send_payload(expected[3]);
      end
      begin
        repeat (6) @(posedge clk);
        stall_start_count = a_stall_cycles;
        if (stall_start_count == 0)
          $fatal(1, "RDI backpressure never reached the source adapter");
        // Change ready away from the sampling edge to avoid a testbench race
        // between the receiver and the delivery monitor.
        @(negedge clk);
        dst_ready = 1;
      end
    join

    wait (delivered == 4);
    repeat (3) @(posedge clk);

    if (retry_valid)
      $fatal(1, "clean backpressure unexpectedly requested a retry");
    if (a_stall_cycles == 0)
      $fatal(1, "TX stall counter did not record end-to-end backpressure");

    $display("BACKPRESSURE SMOKE PASS delivered=%0d stall_cycles=%0d",
             delivered, a_stall_cycles);
    #20 $finish;
  end

  initial begin
    #5000 $fatal(1, "timeout");
  end
endmodule
