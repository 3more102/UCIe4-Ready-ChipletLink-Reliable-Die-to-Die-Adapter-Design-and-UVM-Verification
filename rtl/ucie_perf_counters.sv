module ucie_perf_counters #(
  parameter int COUNTER_W = 32
) (
  input  logic clk,
  input  logic rst_n,
  input  logic link_active_i,
  input  logic fdi_tx_accept_i,
  input  logic rdi_tx_transfer_i,
  input  logic fdi_rx_deliver_i,
  input  logic retry_request_i,
  input  logic error_event_i,
  input  logic tx_stall_i,

  output logic [COUNTER_W-1:0] active_cycles_o,
  output logic [COUNTER_W-1:0] fdi_tx_accepts_o,
  output logic [COUNTER_W-1:0] rdi_tx_transfers_o,
  output logic [COUNTER_W-1:0] fdi_rx_deliveries_o,
  output logic [COUNTER_W-1:0] retry_requests_o,
  output logic [COUNTER_W-1:0] error_events_o,
  output logic [COUNTER_W-1:0] tx_stall_cycles_o
);

  initial begin
    if (COUNTER_W < 1)
      $error("COUNTER_W must be >= 1");
  end

  function automatic logic [COUNTER_W-1:0] sat_inc(
    input logic [COUNTER_W-1:0] value
  );
    if (&value)
      sat_inc = value;
    else
      sat_inc = value + 1'b1;
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      active_cycles_o     <= '0;
      fdi_tx_accepts_o    <= '0;
      rdi_tx_transfers_o  <= '0;
      fdi_rx_deliveries_o <= '0;
      retry_requests_o    <= '0;
      error_events_o      <= '0;
      tx_stall_cycles_o   <= '0;
    end else begin
      if (link_active_i)
        active_cycles_o <= sat_inc(active_cycles_o);
      if (fdi_tx_accept_i)
        fdi_tx_accepts_o <= sat_inc(fdi_tx_accepts_o);
      if (rdi_tx_transfer_i)
        rdi_tx_transfers_o <= sat_inc(rdi_tx_transfers_o);
      if (fdi_rx_deliver_i)
        fdi_rx_deliveries_o <= sat_inc(fdi_rx_deliveries_o);
      if (retry_request_i)
        retry_requests_o <= sat_inc(retry_requests_o);
      if (error_event_i)
        error_events_o <= sat_inc(error_events_o);
      if (tx_stall_i)
        tx_stall_cycles_o <= sat_inc(tx_stall_cycles_o);
    end
  end
endmodule
