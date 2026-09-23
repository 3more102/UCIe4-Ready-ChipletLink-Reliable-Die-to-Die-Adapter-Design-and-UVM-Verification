interface reliability_if (input logic clk);
  logic rst_n;
  logic [2:0] link_state;
  logic link_active;
  logic link_fault;
  logic rdi_valid;
  logic rdi_ready;
  logic crc_error;
  logic sequence_error;
  logic duplicate;
  logic replay_miss;
  logic retry_exhausted;
endinterface
