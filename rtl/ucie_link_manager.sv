module ucie_link_manager (
  input  logic clk,
  input  logic rst_n,
  input  logic enable_i,
  input  logic error_event_i,
  output logic link_active_o,
  output ucie_adapter_pkg::link_state_e state_o
);
  import ucie_adapter_pkg::*;

  link_state_e state_q, state_d;
  logic [2:0] settle_q;

  always_comb begin
    state_d = state_q;
    unique case (state_q)
      LINK_RESET: begin
        if (enable_i) state_d = LINK_INIT;
        else          state_d = LINK_DISABLED;
      end

      LINK_DISABLED: begin
        if (enable_i) state_d = LINK_INIT;
        else          state_d = LINK_DISABLED;
      end

      LINK_INIT: begin
        if (!enable_i)             state_d = LINK_DISABLED;
        else if (settle_q == 3'd4) state_d = LINK_ACTIVE;
        else                       state_d = LINK_INIT;
      end

      LINK_ACTIVE: begin
        if (!enable_i)        state_d = LINK_DISABLED;
        else if (error_event_i) state_d = LINK_RECOVERY;
        else                  state_d = LINK_ACTIVE;
      end

      LINK_RECOVERY: begin
        if (!enable_i)             state_d = LINK_DISABLED;
        else if (settle_q == 3'd2) state_d = LINK_ACTIVE;
        else                       state_d = LINK_RECOVERY;
      end

      default: state_d = LINK_RESET;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q  <= LINK_RESET;
      settle_q <= '0;
    end else begin
      state_q <= state_d;
      if (state_d != state_q)
        settle_q <= '0;
      else if ((state_q == LINK_INIT || state_q == LINK_RECOVERY) && settle_q != 3'd7)
        settle_q <= settle_q + 3'd1;
    end
  end

  assign link_active_o = (state_q == LINK_ACTIVE);
  assign state_o       = state_q;
endmodule
