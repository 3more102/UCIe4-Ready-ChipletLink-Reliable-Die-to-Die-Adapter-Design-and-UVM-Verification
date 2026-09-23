module ucie_crc32_engine #(
  parameter bit PIPELINED = 1'b0,
  parameter int DATA_W    = 256,
  parameter int SEQ_W     = 8
) (
  input  logic clk,
  input  logic rst_n,
  input  logic flush_i,

  input  logic valid_i,
  output logic ready_o,
  input  logic [DATA_W-1:0] data_i,
  input  logic [SEQ_W-1:0]  seq_i,

  output logic valid_o,
  input  logic ready_i,
  output logic [31:0] crc_o
);

  function automatic logic [31:0] crc32_local(
    input logic [DATA_W-1:0] data,
    input logic [SEQ_W-1:0]  seq
  );
    logic [31:0] crc;
    logic feedback;
    integer i;
    begin
      crc = 32'hFFFF_FFFF;
      for (i = SEQ_W-1; i >= 0; i = i - 1) begin
        feedback = crc[31] ^ seq[i];
        crc = {crc[30:0], 1'b0};
        if (feedback)
          crc = crc ^ 32'h04C11DB7;
      end
      for (i = DATA_W-1; i >= 0; i = i - 1) begin
        feedback = crc[31] ^ data[i];
        crc = {crc[30:0], 1'b0};
        if (feedback)
          crc = crc ^ 32'h04C11DB7;
      end
      crc32_local = ~crc;
    end
  endfunction

  generate
    if (!PIPELINED) begin : g_comb
      assign ready_o = ready_i;
      assign valid_o = valid_i;
      assign crc_o   = crc32_local(data_i, seq_i);
    end else begin : g_pipe
      logic valid_q;
      logic [31:0] crc_q;

      assign ready_o = !valid_q || ready_i;
      assign valid_o = valid_q;
      assign crc_o   = crc_q;

      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          valid_q <= 1'b0;
          crc_q   <= '0;
        end else if (flush_i) begin
          valid_q <= 1'b0;
          crc_q   <= '0;
        end else if (ready_o) begin
          valid_q <= valid_i;
          if (valid_i)
            crc_q <= crc32_local(data_i, seq_i);
        end
      end
    end
  endgenerate
endmodule
