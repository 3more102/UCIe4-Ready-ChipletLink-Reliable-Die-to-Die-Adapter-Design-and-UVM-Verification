module ucie_replay_buffer #(
  parameter int DEPTH              = 16,
  parameter int ACK_TIMEOUT_CYCLES = 64,
  parameter int MAX_RETRIES        = 3
) (
  input  logic clk,
  input  logic rst_n,
  input  logic flush_i,
  input  logic timer_enable_i,

  input  logic push_i,
  input  logic [ucie_adapter_pkg::SEQ_W-1:0]  push_seq_i,
  input  logic [ucie_adapter_pkg::FLIT_W-1:0] push_data_i,
  input  logic [ucie_adapter_pkg::CRC_W-1:0]  push_crc_i,
  output logic full_o,
  output logic push_seq_in_use_o,

  input  logic ack_i,
  input  logic [ucie_adapter_pkg::SEQ_W-1:0] ack_seq_i,

  input  logic replay_sent_i,
  input  logic [ucie_adapter_pkg::SEQ_W-1:0] replay_sent_seq_i,

  input  logic [ucie_adapter_pkg::SEQ_W-1:0] lookup_seq_i,
  output logic lookup_found_o,
  output logic [ucie_adapter_pkg::FLIT_W-1:0] lookup_data_o,
  output logic [ucie_adapter_pkg::CRC_W-1:0]  lookup_crc_o,
  output logic [$clog2(MAX_RETRIES+2)-1:0]    lookup_retry_count_o,

  output logic timeout_valid_o,
  output logic [ucie_adapter_pkg::SEQ_W-1:0] timeout_seq_o
);
  import ucie_adapter_pkg::*;

  localparam int TIMER_W = (ACK_TIMEOUT_CYCLES < 2) ? 1 : $clog2(ACK_TIMEOUT_CYCLES + 1);
  localparam int RETRY_W = $clog2(MAX_RETRIES + 2);
  localparam int TIMEOUT_THRESHOLD = (ACK_TIMEOUT_CYCLES > 0) ? (ACK_TIMEOUT_CYCLES - 1) : 0;

  logic valid_q [DEPTH];
  logic [SEQ_W-1:0] seq_q [DEPTH];
  logic [FLIT_W-1:0] data_q [DEPTH];
  logic [CRC_W-1:0] crc_q [DEPTH];
  logic [TIMER_W-1:0] age_q [DEPTH];
  logic [RETRY_W-1:0] retry_count_q [DEPTH];

  logic free_found;
  integer free_idx;
  integer i;

`ifndef SYNTHESIS
  initial begin
    if (DEPTH < 1)
      $error("REPLAY DEPTH must be >= 1");
    if (ACK_TIMEOUT_CYCLES < 1)
      $error("ACK_TIMEOUT_CYCLES must be >= 1");
    if (MAX_RETRIES < 0)
      $error("MAX_RETRIES must be >= 0");
  end
`endif

  always_comb begin
    full_o                = 1'b1;
    free_found            = 1'b0;
    free_idx              = 0;
    push_seq_in_use_o     = 1'b0;
    lookup_found_o        = 1'b0;
    lookup_data_o         = '0;
    lookup_crc_o          = '0;
    lookup_retry_count_o  = '0;
    timeout_valid_o       = 1'b0;
    timeout_seq_o         = '0;

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
        lookup_found_o       = 1'b1;
        lookup_data_o        = data_q[k];
        lookup_crc_o         = crc_q[k];
        lookup_retry_count_o = retry_count_q[k];
      end

      if (!timeout_valid_o && timer_enable_i && valid_q[k] &&
          (age_q[k] >= TIMEOUT_THRESHOLD)) begin
        timeout_valid_o = 1'b1;
        timeout_seq_o   = seq_q[k];
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < DEPTH; i++) begin
        valid_q[i]       <= 1'b0;
        seq_q[i]         <= '0;
        data_q[i]        <= '0;
        crc_q[i]         <= '0;
        age_q[i]         <= '0;
        retry_count_q[i] <= '0;
      end
    end else if (flush_i) begin
      for (i = 0; i < DEPTH; i++) begin
        valid_q[i]       <= 1'b0;
        seq_q[i]         <= '0;
        data_q[i]        <= '0;
        crc_q[i]         <= '0;
        age_q[i]         <= '0;
        retry_count_q[i] <= '0;
      end
    end else begin
      for (i = 0; i < DEPTH; i++) begin
        if (valid_q[i] && timer_enable_i && age_q[i] < ACK_TIMEOUT_CYCLES)
          age_q[i] <= age_q[i] + 1'b1;
      end

      if (ack_i) begin
        for (i = 0; i < DEPTH; i++) begin
          if (valid_q[i] && seq_q[i] == ack_seq_i) begin
            valid_q[i]       <= 1'b0;
            age_q[i]         <= '0;
            retry_count_q[i] <= '0;
          end
        end
      end

      if (replay_sent_i) begin
        for (i = 0; i < DEPTH; i++) begin
          if (valid_q[i] && seq_q[i] == replay_sent_seq_i) begin
            age_q[i] <= '0;
            if (retry_count_q[i] < MAX_RETRIES)
              retry_count_q[i] <= retry_count_q[i] + 1'b1;
          end
        end
      end

      if (push_i && !full_o && !push_seq_in_use_o) begin
        valid_q[free_idx]       <= 1'b1;
        seq_q[free_idx]         <= push_seq_i;
        data_q[free_idx]        <= push_data_i;
        crc_q[free_idx]         <= push_crc_i;
        age_q[free_idx]         <= '0;
        retry_count_q[free_idx] <= '0;
      end
    end
  end
endmodule
