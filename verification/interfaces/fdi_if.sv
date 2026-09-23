interface fdi_if #(parameter int FLIT_W = 256) (input logic clk);
  logic rst_n;
  logic valid;
  logic ready;
  logic [FLIT_W-1:0] data;

  clocking drv_cb @(posedge clk);
    default input #1step output #1step;
    output valid, data;
    input ready, rst_n;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input valid, ready, data, rst_n;
  endclocking
endinterface
