`timescale 1ns/1ps
module tb_replay_buffer;
  import ucie_adapter_pkg::*;

  logic clk = 0;
  always #5 clk = ~clk;
  logic rst_n = 0;
  logic push;
  logic [SEQ_W-1:0] push_seq;
  logic [FLIT_W-1:0] push_data;
  logic [CRC_W-1:0] push_crc;
  logic full;
  logic push_seq_in_use;
  logic ack;
  logic [SEQ_W-1:0] ack_seq;
  logic [SEQ_W-1:0] lookup_seq;
  logic lookup_found;
  logic [FLIT_W-1:0] lookup_data;
  logic [CRC_W-1:0] lookup_crc;

  ucie_replay_buffer #(.DEPTH(4)) dut (
    .clk(clk), .rst_n(rst_n),
    .push_i(push), .push_seq_i(push_seq), .push_data_i(push_data), .push_crc_i(push_crc),
    .full_o(full), .push_seq_in_use_o(push_seq_in_use),
    .ack_i(ack), .ack_seq_i(ack_seq),
    .lookup_seq_i(lookup_seq), .lookup_found_o(lookup_found),
    .lookup_data_o(lookup_data), .lookup_crc_o(lookup_crc)
  );

  task automatic do_push(input logic [SEQ_W-1:0] seq, input logic [FLIT_W-1:0] data);
    begin
      push_seq = seq;
      push_data = data;
      push_crc = crc32_bitwise(data, seq);
      push = 1'b1;
      @(posedge clk);
      #1;
      push = 1'b0;
    end
  endtask

  task automatic do_ack(input logic [SEQ_W-1:0] seq);
    begin
      ack_seq = seq;
      ack = 1'b1;
      @(posedge clk);
      #1;
      ack = 1'b0;
    end
  endtask

  task automatic expect_lookup(input logic [SEQ_W-1:0] seq, input logic [FLIT_W-1:0] data);
    begin
      lookup_seq = seq;
      #1;
      if (!lookup_found) $fatal(1, "expected seq %0d to remain in replay", seq);
      if (lookup_data !== data) $fatal(1, "lookup mismatch seq=%0d", seq);
      if (lookup_crc !== crc32_bitwise(data, seq)) $fatal(1, "CRC mismatch seq=%0d", seq);
    end
  endtask

  initial begin
    push = 0;
    ack = 0;
    push_seq = '0;
    push_data = '0;
    push_crc = '0;
    ack_seq = '0;
    lookup_seq = '0;
    repeat (2) @(posedge clk);
    rst_n = 1;

    do_push(8'd0, 256'h10);
    do_push(8'd1, 256'h11);
    do_push(8'd2, 256'h12);
    do_push(8'd3, 256'h13);
    if (!full) $fatal(1, "replay buffer should be full");

    do_ack(8'd1);
    if (full) $fatal(1, "selective ACK should free capacity");

    do_push(8'd4, 256'h44);
    expect_lookup(8'd0, 256'h10);
    expect_lookup(8'd2, 256'h12);
    expect_lookup(8'd3, 256'h13);
    expect_lookup(8'd4, 256'h44);

    push_seq = 8'd0;
    #1;
    if (!push_seq_in_use) $fatal(1, "live sequence collision was not detected");

    $display("REPLAY BUFFER SMOKE PASS");
    $finish;
  end

  initial begin
    #2000 $fatal(1, "timeout");
  end
endmodule
