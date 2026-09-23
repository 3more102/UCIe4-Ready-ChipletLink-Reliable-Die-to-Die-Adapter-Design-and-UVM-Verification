module ucie_adapter_tx #(
  parameter int REPLAY_DEPTH = 16
) (
  input  logic clk,
  input  logic rst_n,
  input  logic link_active_i,

  input  logic                         fdi_valid_i,
  output logic                         fdi_ready_o,
  input  logic [ucie_adapter_pkg::FLIT_W-1:0] fdi_data_i,

  output logic                         rdi_valid_o,
  input  logic                         rdi_ready_i,
  output logic [ucie_adapter_pkg::FLIT_W-1:0] rdi_data_o,
  output logic [ucie_adapter_pkg::SEQ_W-1:0]  rdi_seq_o,
  output logic [ucie_adapter_pkg::CRC_W-1:0]  rdi_crc_o,

  input  logic                         ack_valid_i,
  input  logic [ucie_adapter_pkg::SEQ_W-1:0]  ack_seq_i,
  input  logic                         retry_valid_i,
  input  logic [ucie_adapter_pkg::SEQ_W-1:0]  retry_seq_i,

  output logic replay_miss_o,
  output logic seq_wrap_block_o
);
  import ucie_adapter_pkg::*;

  logic [SEQ_W-1:0] next_seq_q;
  logic replay_pending_q;
  logic [SEQ_W-1:0] replay_seq_q;
  logic replay_found;
  logic [FLIT_W-1:0] replay_data;
  logic [CRC_W-1:0] replay_crc;
  logic replay_full;
  logic next_seq_in_use;
  logic push_new;
  logic [CRC_W-1:0] new_crc;

  assign new_crc = crc32_bitwise(fdi_data_i, next_seq_q);
  assign seq_wrap_block_o = next_seq_in_use;

  ucie_replay_buffer #(.DEPTH(REPLAY_DEPTH)) u_replay (
    .clk(clk), .rst_n(rst_n),
    .push_i(push_new),
    .push_seq_i(next_seq_q),
    .push_data_i(fdi_data_i),
    .push_crc_i(new_crc),
    .full_o(replay_full),
    .push_seq_in_use_o(next_seq_in_use),
    .ack_i(ack_valid_i),
    .ack_seq_i(ack_seq_i),
    .lookup_seq_i(replay_seq_q),
    .lookup_found_o(replay_found),
    .lookup_data_o(replay_data),
    .lookup_crc_o(replay_crc)
  );

  always_comb begin
    rdi_valid_o = 1'b0;
    rdi_data_o  = '0;
    rdi_seq_o   = '0;
    rdi_crc_o   = '0;
    fdi_ready_o = 1'b0;

    if (link_active_i) begin
      if (replay_pending_q) begin
        rdi_valid_o = replay_found;
        rdi_data_o  = replay_data;
        rdi_seq_o   = replay_seq_q;
        rdi_crc_o   = replay_crc;
      end else if (!replay_full && !next_seq_in_use) begin
        rdi_valid_o = fdi_valid_i;
        rdi_data_o  = fdi_data_i;
        rdi_seq_o   = next_seq_q;
        rdi_crc_o   = new_crc;
        fdi_ready_o = rdi_ready_i;
      end
    end
  end

  assign push_new = fdi_valid_i && fdi_ready_o;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      next_seq_q       <= '0;
      replay_pending_q <= 1'b0;
      replay_seq_q     <= '0;
      replay_miss_o    <= 1'b0;
    end else begin
      replay_miss_o <= 1'b0;

      if (push_new)
        next_seq_q <= next_seq_q + 1'b1;

      if (retry_valid_i && !replay_pending_q) begin
        replay_pending_q <= 1'b1;
        replay_seq_q     <= retry_seq_i;
      end

      if (replay_pending_q && !replay_found) begin
        replay_miss_o    <= 1'b1;
        replay_pending_q <= 1'b0;
      end else if (replay_pending_q && replay_found && rdi_ready_i) begin
        replay_pending_q <= 1'b0;
      end
    end
  end
endmodule
