module ucie_adapter_tx #(
  parameter int REPLAY_DEPTH       = 16,
  parameter int ACK_TIMEOUT_CYCLES = 64,
  parameter int MAX_RETRIES        = 3
) (
  input  logic clk,
  input  logic rst_n,
  input  logic flush_i,
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
  output logic retry_exhausted_o,
  output logic [ucie_adapter_pkg::SEQ_W-1:0] retry_exhausted_seq_o,
  output logic seq_wrap_block_o
);
  import ucie_adapter_pkg::*;

  localparam int RETRY_W = $clog2(MAX_RETRIES + 2);

  logic [SEQ_W-1:0] next_seq_q;
  logic replay_pending_q;
  logic [SEQ_W-1:0] replay_seq_q;
  logic faulted_q;

  logic replay_found;
  logic [FLIT_W-1:0] replay_data;
  logic [CRC_W-1:0] replay_crc;
  logic [RETRY_W-1:0] replay_retry_count;
  logic replay_full;
  logic next_seq_in_use;
  logic timeout_valid;
  logic [SEQ_W-1:0] timeout_seq;

  logic push_new;
  logic [CRC_W-1:0] new_crc;
  logic replay_handshake;
  logic pending_ack_cancel;
  logic pending_missing;
  logic pending_exhausted;
  logic pending_done;
  logic peer_request_valid;
  logic auto_request_valid;

  assign new_crc          = crc32_bitwise(fdi_data_i, next_seq_q);
  assign seq_wrap_block_o = next_seq_in_use;

  ucie_replay_buffer #(
    .DEPTH(REPLAY_DEPTH),
    .ACK_TIMEOUT_CYCLES(ACK_TIMEOUT_CYCLES),
    .MAX_RETRIES(MAX_RETRIES)
  ) u_replay (
    .clk(clk),
    .rst_n(rst_n),
    .flush_i(flush_i),
    .timer_enable_i(link_active_i && !faulted_q),
    .push_i(push_new),
    .push_seq_i(next_seq_q),
    .push_data_i(fdi_data_i),
    .push_crc_i(new_crc),
    .full_o(replay_full),
    .push_seq_in_use_o(next_seq_in_use),
    .ack_i(ack_valid_i),
    .ack_seq_i(ack_seq_i),
    .replay_sent_i(replay_handshake),
    .replay_sent_seq_i(replay_seq_q),
    .lookup_seq_i(replay_seq_q),
    .lookup_found_o(replay_found),
    .lookup_data_o(replay_data),
    .lookup_crc_o(replay_crc),
    .lookup_retry_count_o(replay_retry_count),
    .timeout_valid_o(timeout_valid),
    .timeout_seq_o(timeout_seq)
  );

  assign pending_ack_cancel =
      replay_pending_q && ack_valid_i && (ack_seq_i == replay_seq_q);

  assign pending_missing =
      replay_pending_q && !pending_ack_cancel && !replay_found;

  assign pending_exhausted =
      replay_pending_q && !pending_ack_cancel && replay_found &&
      (replay_retry_count >= MAX_RETRIES);

  always_comb begin
    rdi_valid_o = 1'b0;
    rdi_data_o  = '0;
    rdi_seq_o   = '0;
    rdi_crc_o   = '0;
    fdi_ready_o = 1'b0;

    if (link_active_i && !faulted_q) begin
      if (replay_pending_q) begin
        if (!pending_ack_cancel && replay_found &&
            (replay_retry_count < MAX_RETRIES)) begin
          rdi_valid_o = 1'b1;
          rdi_data_o  = replay_data;
          rdi_seq_o   = replay_seq_q;
          rdi_crc_o   = replay_crc;
        end
      end else if (!replay_full && !next_seq_in_use) begin
        rdi_valid_o = fdi_valid_i;
        rdi_data_o  = fdi_data_i;
        rdi_seq_o   = next_seq_q;
        rdi_crc_o   = new_crc;
        fdi_ready_o = rdi_ready_i;
      end
    end
  end

  assign push_new         = fdi_valid_i && fdi_ready_o;
  assign replay_handshake = replay_pending_q && rdi_valid_o && rdi_ready_i;

  assign pending_done =
      pending_ack_cancel || pending_missing || pending_exhausted || replay_handshake;

  assign peer_request_valid =
      retry_valid_i &&
      !(ack_valid_i && (ack_seq_i == retry_seq_i)) &&
      !(replay_handshake && (retry_seq_i == replay_seq_q));

  assign auto_request_valid =
      timeout_valid &&
      !(ack_valid_i && (ack_seq_i == timeout_seq)) &&
      !(replay_handshake && (timeout_seq == replay_seq_q));

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      next_seq_q             <= '0;
      replay_pending_q       <= 1'b0;
      replay_seq_q           <= '0;
      faulted_q              <= 1'b0;
      replay_miss_o          <= 1'b0;
      retry_exhausted_o      <= 1'b0;
      retry_exhausted_seq_o  <= '0;
    end else if (flush_i) begin
      next_seq_q             <= '0;
      replay_pending_q       <= 1'b0;
      replay_seq_q           <= '0;
      faulted_q              <= 1'b0;
      replay_miss_o          <= 1'b0;
      retry_exhausted_o      <= 1'b0;
      retry_exhausted_seq_o  <= '0;
    end else begin
      replay_miss_o     <= 1'b0;
      retry_exhausted_o <= 1'b0;

      if (push_new)
        next_seq_q <= next_seq_q + 1'b1;

      if (!link_active_i)
        replay_pending_q <= 1'b0;

      if (replay_pending_q && link_active_i && !faulted_q) begin
        if (pending_ack_cancel) begin
          replay_pending_q <= 1'b0;
        end else if (pending_missing) begin
          replay_pending_q <= 1'b0;
          replay_miss_o    <= 1'b1;
          faulted_q        <= 1'b1;
        end else if (pending_exhausted) begin
          replay_pending_q      <= 1'b0;
          retry_exhausted_o     <= 1'b1;
          retry_exhausted_seq_o <= replay_seq_q;
          faulted_q             <= 1'b1;
        end else if (replay_handshake) begin
          replay_pending_q <= 1'b0;
        end
      end

      if (link_active_i && !faulted_q &&
          (!replay_pending_q || pending_done) &&
          !pending_missing && !pending_exhausted) begin
        if (peer_request_valid) begin
          replay_pending_q <= 1'b1;
          replay_seq_q     <= retry_seq_i;
        end else if (auto_request_valid) begin
          replay_pending_q <= 1'b1;
          replay_seq_q     <= timeout_seq;
        end
      end
    end
  end
endmodule
