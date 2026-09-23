`timescale 1ns/1ps
module tb_crc_engine;
  import ucie_adapter_pkg::*;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  logic rst_n = 1'b0;
  logic flush = 1'b0;
  logic valid_i = 1'b0;
  logic [FLIT_W-1:0] data_i = '0;
  logic [SEQ_W-1:0] seq_i = '0;
  logic ready_i = 1'b1;

  logic comb_ready;
  logic comb_valid;
  logic [CRC_W-1:0] comb_crc;
  logic pipe_ready;
  logic pipe_valid;
  logic [CRC_W-1:0] pipe_crc;

  logic [CRC_W-1:0] expected_crc;
  logic [CRC_W-1:0] held_crc;
  integer i;

  ucie_crc32_engine #(.PIPELINED(1'b0)) u_comb (
    .clk(clk), .rst_n(rst_n), .flush_i(flush),
    .valid_i(valid_i), .ready_o(comb_ready),
    .data_i(data_i), .seq_i(seq_i),
    .valid_o(comb_valid), .ready_i(ready_i), .crc_o(comb_crc)
  );

  ucie_crc32_engine #(.PIPELINED(1'b1)) u_pipe (
    .clk(clk), .rst_n(rst_n), .flush_i(flush),
    .valid_i(valid_i), .ready_o(pipe_ready),
    .data_i(data_i), .seq_i(seq_i),
    .valid_o(pipe_valid), .ready_i(ready_i), .crc_o(pipe_crc)
  );

  initial begin
    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    for (i = 0; i < 32; i++) begin
      @(negedge clk);
      valid_i = 1'b1;
      seq_i   = i;
      data_i  = {8{32'h1020_3040 ^ i}};
      expected_crc = crc32_bitwise(data_i, seq_i);
      #1;

      if (!comb_ready || !pipe_ready)
        $fatal(1, "CRC engine unexpectedly backpressured at item %0d", i);
      if (!comb_valid || comb_crc !== expected_crc)
        $fatal(1, "combinational CRC mismatch at item %0d", i);

      @(posedge clk);
      #1;
      if (!pipe_valid || pipe_crc !== expected_crc)
        $fatal(1, "pipelined CRC mismatch at item %0d", i);
    end

    @(negedge clk);
    valid_i = 1'b0;
    @(posedge clk);
    #1;
    if (pipe_valid)
      $fatal(1, "pipelined valid did not drain");

    @(negedge clk);
    ready_i = 1'b0;
    valid_i = 1'b1;
    seq_i   = 8'hA5;
    data_i  = 256'h0123456789ABCDEF_FEDCBA9876543210_1111222233334444_5555666677778888;
    expected_crc = crc32_bitwise(data_i, seq_i);
    if (!pipe_ready)
      $fatal(1, "empty pipeline refused first stalled item");

    @(posedge clk);
    #1;
    if (!pipe_valid || pipe_crc !== expected_crc)
      $fatal(1, "pipeline failed to capture stalled item");
    held_crc = pipe_crc;

    valid_i = 1'b0;
    repeat (3) begin
      @(posedge clk);
      #1;
      if (pipe_ready)
        $fatal(1, "full pipeline asserted ready under output backpressure");
      if (!pipe_valid || pipe_crc !== held_crc)
        $fatal(1, "pipeline output changed while stalled");
    end

    @(negedge clk);
    ready_i = 1'b1;
    @(posedge clk);
    #1;
    if (pipe_valid)
      $fatal(1, "pipeline did not retire after ready");

    @(negedge clk);
    ready_i = 1'b0;
    valid_i = 1'b1;
    seq_i   = 8'h5A;
    data_i  = 256'hDEADBEEF;
    @(posedge clk);
    #1;
    if (!pipe_valid)
      $fatal(1, "flush setup item was not captured");

    @(negedge clk);
    valid_i = 1'b0;
    flush = 1'b1;
    @(posedge clk);
    #1;
    flush = 1'b0;
    if (pipe_valid)
      $fatal(1, "flush did not clear pipelined valid");

    $display("CRC ENGINE PASS combinational/pipelined equivalence + stall/flush");
    #20 $finish;
  end

  initial begin
    #10000 $fatal(1, "timeout");
  end
endmodule
