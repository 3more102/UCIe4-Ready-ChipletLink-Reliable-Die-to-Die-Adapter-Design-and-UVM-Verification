module ucie_replay_buffer #(
  parameter int DEPTH = 16
) (
  input  logic clk,
  input  logic rst_n,

  input  logic push_i,
  input  logic [ucie_adapter_pkg::SEQ_W-1:0]  push_seq_i,
  input  logic [ucie_adapter_pkg::FLIT_W-1:0] push_data_i,
  input  logic [ucie_adapter_pkg::CRC_W-1:0]  push_crc_i,
  output logic full_o,
  output logic push_seq_in_use_o,

  input  logic ack_i,
  input  logic [ucie_adapter_pkg::SEQ_W-1:0] ack_seq_i,

  input  logic [ucie_adapter_pkg::SEQ_W-1:0] lookup_seq_i,
  output logic lookup_found_o,
  output logic [ucie_adapter_pkg::FLIT_W-1:0] lookup_data_o,
  output logic [ucie_adapter_pkg::CRC_W-1:0]  lookup_crc_o
);
  import ucie_adapter_pkg::*;

  logic valid_q [DEPTH];
  logic [SEQ_W-1:0] seq_q [DEPTH];
  logic [FLIT_W-1:0] data_q [DEPTH];
  logic [CRC_W-1:0] crc_q [DEPTH];
  logic free_found;
  integer free_idx;
  integer i;

  always_comb begin
    full_o             = 1'b1;
    free_found         = 1'b0;
    free_idx           = 0;
    push_seq_in_use_o  = 1'b0;
    lookup_found_o     = 1'b0;
    lookup_data_o      = '0;
    lookup_crc_o       = '0;

    for (int k = 0; k < DEPTH; k++) begin
      if (!valid_q[k]) begin
        full_o = 1'b0;
        if (!free_found) begin
          free_found = 1'b1;
          free_idx   = k;
        end
      end

      if (valid_q[k] && seq_q[k] == push_seq_i)
        push_seq_in_use_o = 1'b1;

      if (!lookup_found_o && valid_q[k] && seq_q[k] == lookup_seq_i) begin
        lookup_found_o = 1'b1;
        lookup_data_o  = data_q[k];
        lookup_crc_o   = crc_q[k];
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < DEPTH; i++) begin
        valid_q[i] <= 1'b0;
        seq_q[i]   <= '0;
        data_q[i]  <= '0;
        crc_q[i]   <= '0;
      end
    end else begin
      if (ack_i) begin
        for (i = 0; i < DEPTH; i++) begin
          if (valid_q[i] && seq_q[i] == ack_seq_i)
            valid_q[i] <= 1'b0;
        end
      end

      if (push_i && !full_o && !push_seq_in_use_o) begin
        valid_q[free_idx] <= 1'b1;
        seq_q[free_idx]   <= push_seq_i;
        data_q[free_idx]  <= push_data_i;
        crc_q[free_idx]   <= push_crc_i;
      end
    end
  end
endmodule
