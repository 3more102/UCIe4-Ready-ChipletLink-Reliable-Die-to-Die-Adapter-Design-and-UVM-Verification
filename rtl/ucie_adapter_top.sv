module ucie_adapter_top #(
  parameter int REPLAY_DEPTH       = 16,
  parameter int DUP_WINDOW         = 16,
  parameter int ACK_TIMEOUT_CYCLES = 64,
  parameter int MAX_RETRIES        = 3,
  parameter int PERF_COUNTER_W     = 32
) (
  input  logic clk,
  input  logic rst_n,
  input  logic link_enable_i,

  input  logic fdi_tx_valid_i,
  output logic fdi_tx_ready_o,
  input  logic [ucie_adapter_pkg::FLIT_W-1:0] fdi_tx_data_i,

  output logic fdi_rx_valid_o,
  input  logic fdi_rx_ready_i,
  output logic [ucie_adapter_pkg::FLIT_W-1:0] fdi_rx_data_o,

  output logic rdi_tx_valid_o,
  input  logic rdi_tx_ready_i,
  output logic [ucie_adapter_pkg::FLIT_W-1:0] rdi_tx_data_o,
  output logic [ucie_adapter_pkg::SEQ_W-1:0]  rdi_tx_seq_o,
  output logic [ucie_adapter_pkg::CRC_W-1:0]  rdi_tx_crc_o,

  input  logic rdi_rx_valid_i,
  output logic rdi_rx_ready_o,
  input  logic [ucie_adapter_pkg::FLIT_W-1:0] rdi_rx_data_i,
  input  logic [ucie_adapter_pkg::SEQ_W-1:0]  rdi_rx_seq_i,
  input  logic [ucie_adapter_pkg::CRC_W-1:0]  rdi_rx_crc_i,

  input  logic peer_ack_valid_i,
  input  logic [ucie_adapter_pkg::SEQ_W-1:0] peer_ack_seq_i,
  input  logic peer_retry_valid_i,
  input  logic [ucie_adapter_pkg::SEQ_W-1:0] peer_retry_seq_i,

  output logic local_ack_valid_o,
  output logic [ucie_adapter_pkg::SEQ_W-1:0] local_ack_seq_o,
  output logic local_retry_valid_o,
  output logic [ucie_adapter_pkg::SEQ_W-1:0] local_retry_seq_o,

  output logic link_active_o,
  output logic link_fault_o,
  output ucie_adapter_pkg::link_state_e link_state_o,
  output logic crc_error_o,
  output logic replay_miss_o,
  output logic retry_exhausted_o,
  output logic [ucie_adapter_pkg::SEQ_W-1:0] retry_exhausted_seq_o,
  output logic duplicate_o,
  output logic sequence_error_o,
  output logic seq_wrap_block_o,

  output logic [PERF_COUNTER_W-1:0] perf_active_cycles_o,
  output logic [PERF_COUNTER_W-1:0] perf_fdi_tx_accepts_o,
  output logic [PERF_COUNTER_W-1:0] perf_rdi_tx_transfers_o,
  output logic [PERF_COUNTER_W-1:0] perf_fdi_rx_deliveries_o,
  output logic [PERF_COUNTER_W-1:0] perf_retry_requests_o,
  output logic [PERF_COUNTER_W-1:0] perf_error_events_o,
  output logic [PERF_COUNTER_W-1:0] perf_tx_stall_cycles_o
);
  import ucie_adapter_pkg::*;

  logic rx_crc_error;
  logic rx_duplicate;
  logic rx_sequence_error;
  logic tx_replay_miss;
  logic tx_retry_exhausted;
  logic [SEQ_W-1:0] tx_retry_exhausted_seq;
  logic flush_link;

  logic perf_fdi_tx_accept;
  logic perf_rdi_tx_transfer;
  logic perf_fdi_rx_deliver;
  logic perf_retry_request;
  logic perf_error_event;
  logic perf_tx_stall;

  assign flush_link = !link_enable_i;

  assign perf_fdi_tx_accept  = fdi_tx_valid_i && fdi_tx_ready_o;
  assign perf_rdi_tx_transfer = rdi_tx_valid_o && rdi_tx_ready_i;
  assign perf_fdi_rx_deliver = fdi_rx_valid_o && fdi_rx_ready_i;
  assign perf_retry_request  = peer_retry_valid_i || local_retry_valid_o;
  assign perf_error_event    = rx_crc_error || rx_sequence_error ||
                               tx_replay_miss || tx_retry_exhausted;
  assign perf_tx_stall       = rdi_tx_valid_o && !rdi_tx_ready_i;

  ucie_link_manager u_link (
    .clk(clk),
    .rst_n(rst_n),
    .enable_i(link_enable_i),
    .error_event_i(rx_crc_error | rx_sequence_error),
    .fatal_error_i(tx_replay_miss | tx_retry_exhausted),
    .link_active_o(link_active_o),
    .fault_latched_o(link_fault_o),
    .state_o(link_state_o)
  );

  ucie_adapter_tx #(
    .REPLAY_DEPTH(REPLAY_DEPTH),
    .ACK_TIMEOUT_CYCLES(ACK_TIMEOUT_CYCLES),
    .MAX_RETRIES(MAX_RETRIES)
  ) u_tx (
    .clk(clk),
    .rst_n(rst_n),
    .flush_i(flush_link),
    .link_active_i(link_active_o),
    .fdi_valid_i(fdi_tx_valid_i),
    .fdi_ready_o(fdi_tx_ready_o),
    .fdi_data_i(fdi_tx_data_i),
    .rdi_valid_o(rdi_tx_valid_o),
    .rdi_ready_i(rdi_tx_ready_i),
    .rdi_data_o(rdi_tx_data_o),
    .rdi_seq_o(rdi_tx_seq_o),
    .rdi_crc_o(rdi_tx_crc_o),
    .ack_valid_i(peer_ack_valid_i),
    .ack_seq_i(peer_ack_seq_i),
    .retry_valid_i(peer_retry_valid_i),
    .retry_seq_i(peer_retry_seq_i),
    .replay_miss_o(tx_replay_miss),
    .retry_exhausted_o(tx_retry_exhausted),
    .retry_exhausted_seq_o(tx_retry_exhausted_seq),
    .seq_wrap_block_o(seq_wrap_block_o)
  );

  ucie_adapter_rx #(.DUP_WINDOW(DUP_WINDOW)) u_rx (
    .clk(clk),
    .rst_n(rst_n),
    .flush_i(flush_link),
    .link_active_i(link_active_o),
    .rdi_valid_i(rdi_rx_valid_i),
    .rdi_ready_o(rdi_rx_ready_o),
    .rdi_data_i(rdi_rx_data_i),
    .rdi_seq_i(rdi_rx_seq_i),
    .rdi_crc_i(rdi_rx_crc_i),
    .fdi_valid_o(fdi_rx_valid_o),
    .fdi_ready_i(fdi_rx_ready_i),
    .fdi_data_o(fdi_rx_data_o),
    .ack_valid_o(local_ack_valid_o),
    .ack_seq_o(local_ack_seq_o),
    .retry_valid_o(local_retry_valid_o),
    .retry_seq_o(local_retry_seq_o),
    .crc_error_o(rx_crc_error),
    .duplicate_o(rx_duplicate),
    .sequence_error_o(rx_sequence_error)
  );

  ucie_perf_counters #(
    .COUNTER_W(PERF_COUNTER_W)
  ) u_perf (
    .clk(clk),
    .rst_n(rst_n),
    .link_active_i(link_active_o),
    .fdi_tx_accept_i(perf_fdi_tx_accept),
    .rdi_tx_transfer_i(perf_rdi_tx_transfer),
    .fdi_rx_deliver_i(perf_fdi_rx_deliver),
    .retry_request_i(perf_retry_request),
    .error_event_i(perf_error_event),
    .tx_stall_i(perf_tx_stall),
    .active_cycles_o(perf_active_cycles_o),
    .fdi_tx_accepts_o(perf_fdi_tx_accepts_o),
    .rdi_tx_transfers_o(perf_rdi_tx_transfers_o),
    .fdi_rx_deliveries_o(perf_fdi_rx_deliveries_o),
    .retry_requests_o(perf_retry_requests_o),
    .error_events_o(perf_error_events_o),
    .tx_stall_cycles_o(perf_tx_stall_cycles_o)
  );

  assign crc_error_o            = rx_crc_error;
  assign duplicate_o            = rx_duplicate;
  assign sequence_error_o       = rx_sequence_error;
  assign replay_miss_o          = tx_replay_miss;
  assign retry_exhausted_o      = tx_retry_exhausted;
  assign retry_exhausted_seq_o  = tx_retry_exhausted_seq;
endmodule
