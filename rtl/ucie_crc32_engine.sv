module ucie_crc32_engine #(
  parameter bit PIPELINED = 1'b0
) (
  input  logic clk,
  input  logic rst_n,
  input  logic flush_i,

  input  logic valid_i,
  output logic ready_o,
  input  logic [ucie_adapter_pkg::FLIT_W-1:0] data_i,
  input  logic [ucie_adapter_pkg::SEQ_W-1:0]  seq_i,

  output logic valid_o,
  input  logic ready_i,
  output logic [ucie_adapter_pkg::CRC_W-1:0] crc_o
);
  import ucie_adapter_pkg::*;

  generate
    if (!PIPELINED) begin : g_comb
      assign ready_o = ready_i;
      assign valid_o = valid_i;
      assign crc_o   = crc32_bitwise(data_i, seq_i);
    end else begin : g_pipe
      logic valid_q;
      logic [CRC_W-1:0] crc_q;

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
            crc_q <= crc32_bitwise(data_i, seq_i);
        end
      end
    end
  endgenerate
endmodule
