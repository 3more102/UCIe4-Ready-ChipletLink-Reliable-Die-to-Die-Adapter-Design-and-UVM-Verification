module ucie_channel_model (
  input  logic clk,
  input  logic rst_n,

  input  logic tx_valid_i,
  output logic tx_ready_o,
  input  logic [ucie_adapter_pkg::FLIT_W-1:0] tx_data_i,
  input  logic [ucie_adapter_pkg::SEQ_W-1:0]  tx_seq_i,
  input  logic [ucie_adapter_pkg::CRC_W-1:0]  tx_crc_i,

  output logic rx_valid_o,
  input  logic rx_ready_i,
  output logic [ucie_adapter_pkg::FLIT_W-1:0] rx_data_o,
  output logic [ucie_adapter_pkg::SEQ_W-1:0]  rx_seq_o,
  output logic [ucie_adapter_pkg::CRC_W-1:0]  rx_crc_o,

  input  logic inject_data_error_i,
  input  logic inject_crc_error_i,
  input  logic [$clog2(ucie_adapter_pkg::FLIT_W)-1:0] bit_index_i
);
  import ucie_adapter_pkg::*;

  logic [FLIT_W-1:0] altered_data;
  logic [CRC_W-1:0]  altered_crc;

  always_comb begin
    altered_data = tx_data_i;
    altered_crc  = tx_crc_i;
    if (inject_data_error_i)
      altered_data[bit_index_i] = ~altered_data[bit_index_i];
    if (inject_crc_error_i)
      altered_crc[0] = ~altered_crc[0];
  end

  assign tx_ready_o = rx_ready_i;
  assign rx_valid_o = tx_valid_i;
  assign rx_data_o  = altered_data;
  assign rx_seq_o   = tx_seq_i;
  assign rx_crc_o   = altered_crc;
endmodule
