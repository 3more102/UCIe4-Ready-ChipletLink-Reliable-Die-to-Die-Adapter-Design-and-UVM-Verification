interface error_inject_if #(parameter int FLIT_W = 256) (input logic clk);
  logic inject_data_error;
  logic inject_crc_error;
  logic [$clog2(FLIT_W)-1:0] bit_index;
endinterface
