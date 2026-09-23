module ucie_adapter_sva #(
  parameter int FLIT_W = 256,
  parameter int SEQ_W  = 8,
  parameter int CRC_W  = 32
) (
  input logic clk,
  input logic rst_n,
  input logic link_active,
  input logic link_fault,
  input logic fdi_tx_ready,
  input logic rdi_tx_valid,
  input logic rdi_tx_ready,
  input logic [FLIT_W-1:0] rdi_tx_data,
  input logic [SEQ_W-1:0]  rdi_tx_seq,
  input logic [CRC_W-1:0]  rdi_tx_crc,
  input logic crc_error,
  input logic sequence_error,
  input logic replay_miss,
  input logic retry_exhausted,
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

  ap_retry_exhaust_latches_fault: assert property (retry_exhausted |=> link_fault);
  ap_replay_miss_latches_fault: assert property (replay_miss |=> link_fault);
  ap_fault_blocks_source: assert property (link_fault |-> !fdi_tx_ready);

  cp_backpressure: cover property (rdi_tx_valid && !rdi_tx_ready ##1 rdi_tx_ready);
  cp_error_retry:  cover property ((crc_error || sequence_error) && local_retry_valid);
  cp_duplicate:    cover property (duplicate_event && local_ack_valid);
  cp_fatal_fault:  cover property ((retry_exhausted || replay_miss) ##1 link_fault);
endmodule
