module ucie_adapter_top #(
  parameter int REPLAY_DEPTH = 16,
  parameter int DUP_WINDOW   = 16
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
  output ucie_adapter_pkg::link_state_e link_state_o,
  output logic crc_error_o,
  output logic replay_miss_o,
  output logic duplicate_o,
  output logic sequence_error_o,
  output logic seq_wrap_block_o
);
  import ucie_adapter_pkg::*;

  logic rx_crc_error;
  logic rx_duplicate;
  logic rx_sequence_error;

  ucie_link_manager u_link (
    .clk(clk),
    .rst_n(rst_n),
    .enable_i(link_enable_i),
    .error_event_i(rx_crc_error | rx_sequence_error),
    .link_active_o(link_active_o),
    .state_o(link_state_o)
  );

  ucie_adapter_tx #(.REPLAY_DEPTH(REPLAY_DEPTH)) u_tx (
    .clk(clk), .rst_n(rst_n), .link_active_i(link_active_o),
    .fdi_valid_i(fdi_tx_valid_i), .fdi_ready_o(fdi_tx_ready_o), .fdi_data_i(fdi_tx_data_i),
    .rdi_valid_o(rdi_tx_valid_o), .rdi_ready_i(rdi_tx_ready_i),
    .rdi_data_o(rdi_tx_data_o), .rdi_seq_o(rdi_tx_seq_o), .rdi_crc_o(rdi_tx_crc_o),
    .ack_valid_i(peer_ack_valid_i), .ack_seq_i(peer_ack_seq_i),
    .retry_valid_i(peer_retry_valid_i), .retry_seq_i(peer_retry_seq_i),
    .replay_miss_o(replay_miss_o), .seq_wrap_block_o(seq_wrap_block_o)
  );

  ucie_adapter_rx #(.DUP_WINDOW(DUP_WINDOW)) u_rx (
    .clk(clk), .rst_n(rst_n), .link_active_i(link_active_o),
    .rdi_valid_i(rdi_rx_valid_i), .rdi_ready_o(rdi_rx_ready_o),
    .rdi_data_i(rdi_rx_data_i), .rdi_seq_i(rdi_rx_seq_i), .rdi_crc_i(rdi_rx_crc_i),
    .fdi_valid_o(fdi_rx_valid_o), .fdi_ready_i(fdi_rx_ready_i), .fdi_data_o(fdi_rx_data_o),
    .ack_valid_o(local_ack_valid_o), .ack_seq_o(local_ack_seq_o),
    .retry_valid_o(local_retry_valid_o), .retry_seq_o(local_retry_seq_o),
    .crc_error_o(rx_crc_error), .duplicate_o(rx_duplicate), .sequence_error_o(rx_sequence_error)
  );

  assign crc_error_o      = rx_crc_error;
  assign duplicate_o      = rx_duplicate;
  assign sequence_error_o = rx_sequence_error;
endmodule
