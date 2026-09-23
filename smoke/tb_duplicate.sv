`timescale 1ns/1ps
module tb_duplicate;
  import ucie_adapter_pkg::*;

  logic clk = 0;
  always #5 clk = ~clk;
  logic rst_n = 0;
  logic rdi_valid;
  logic rdi_ready;
  logic [FLIT_W-1:0] rdi_data;
  logic [SEQ_W-1:0] rdi_seq;
  logic [CRC_W-1:0] rdi_crc;
  logic fdi_valid;
  logic [FLIT_W-1:0] fdi_data;
  logic ack_valid;
  logic [SEQ_W-1:0] ack_seq;
  logic retry_valid;
  logic [SEQ_W-1:0] retry_seq;
  logic crc_error;
  logic duplicate;
  logic sequence_error;
  integer deliveries = 0;
  integer duplicate_pulses = 0;

  ucie_adapter_rx #(.DUP_WINDOW(16)) dut (
    .clk(clk), .rst_n(rst_n), .link_active_i(1'b1),
    .rdi_valid_i(rdi_valid), .rdi_ready_o(rdi_ready),
    .rdi_data_i(rdi_data), .rdi_seq_i(rdi_seq), .rdi_crc_i(rdi_crc),
    .fdi_valid_o(fdi_valid), .fdi_ready_i(1'b1), .fdi_data_o(fdi_data),
    .ack_valid_o(ack_valid), .ack_seq_o(ack_seq),
    .retry_valid_o(retry_valid), .retry_seq_o(retry_seq),
    .crc_error_o(crc_error), .duplicate_o(duplicate), .sequence_error_o(sequence_error)
  );

  always @(posedge clk) begin
    if (rst_n && fdi_valid)
      deliveries <= deliveries + 1;
    if (rst_n && duplicate)
      duplicate_pulses <= duplicate_pulses + 1;
  end

  task automatic send_flit(input logic [SEQ_W-1:0] seq, input logic [FLIT_W-1:0] data);
    begin
      rdi_seq = seq;
      rdi_data = data;
      rdi_crc = crc32_bitwise(data, seq);
      rdi_valid = 1'b1;
      do @(posedge clk); while (!rdi_ready);
      #1;
      rdi_valid = 1'b0;
    end
  endtask

  initial begin
    rdi_valid = 0;
    rdi_data = '0;
    rdi_seq = '0;
    rdi_crc = '0;
    repeat (2) @(posedge clk);
    rst_n = 1;

    send_flit(8'd0, 256'hABC);
    repeat (2) @(posedge clk);
    if (deliveries != 1) $fatal(1, "first flit must be delivered once");

    send_flit(8'd0, 256'hABC);
    repeat (2) @(posedge clk);
    if (deliveries != 1) $fatal(1, "duplicate replay was delivered twice");
    if (duplicate_pulses != 1) $fatal(1, "duplicate event not observed");
    if (retry_valid || crc_error || sequence_error) $fatal(1, "duplicate incorrectly treated as error");

    rdi_seq = 8'd2;
    rdi_data = 256'h222;
    rdi_crc = crc32_bitwise(rdi_data, rdi_seq);
    rdi_valid = 1'b1;
    do @(posedge clk); while (!rdi_ready);
    #1;
    if (!retry_valid || retry_seq != 8'd1 || !sequence_error)
      $fatal(1, "sequence gap did not request expected seq1");
    rdi_valid = 1'b0;

    $display("DUPLICATE/ORDER SMOKE PASS");
    $finish;
  end

  initial begin
    #2000 $fatal(1, "timeout");
  end
endmodule
