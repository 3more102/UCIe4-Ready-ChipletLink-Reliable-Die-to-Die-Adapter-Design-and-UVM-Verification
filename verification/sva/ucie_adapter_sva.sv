module ucie_adapter_sva #(
  parameter int FLIT_W = 256,
  parameter int SEQ_W  = 8,
  parameter int CRC_W  = 32
) (
  input logic clk,
  input logic rst_n,
  input logic link_active,
  input logic fdi_tx_ready,
  input logic rdi_tx_valid,
  input logic rdi_tx_ready,
  input logic [FLIT_W-1:0] rdi_tx_data,
  input logic [SEQ_W-1:0]  rdi_tx_seq,
  input logic [CRC_W-1:0]  rdi_tx_crc,
  input logic crc_error,
  input logic sequence_error,
  input logic local_ack_valid,
  input logic local_retry_valid,
  input logic duplicate_event
);
  default clocking cb @(posedge clk); endclocking
  default disable iff (!rst_n);

  ap_no_tx_when_link_down: assert property (!link_active |-> !fdi_tx_ready);

  ap_rdi_stable_under_stall: assert property (
    rdi_tx_valid && !rdi_tx_ready |=>
      rdi_tx_valid && $stable({rdi_tx_data, rdi_tx_seq, rdi_tx_crc})
  );

  ap_crc_error_requests_retry: assert property (crc_error |-> local_retry_valid);
  ap_seq_error_requests_retry: assert property (sequence_error |-> local_retry_valid);
  ap_ack_retry_mutually_exclusive: assert property (!(local_ack_valid && local_retry_valid));
  ap_duplicate_reacked: assert property (duplicate_event |-> local_ack_valid);

  cp_backpressure: cover property (rdi_tx_valid && !rdi_tx_ready ##1 rdi_tx_ready);
  cp_error_retry:  cover property ((crc_error || sequence_error) && local_retry_valid);
  cp_duplicate:    cover property (duplicate_event && local_ack_valid);
endmodule
