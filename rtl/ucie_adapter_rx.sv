module ucie_adapter_rx #(
  parameter int DUP_WINDOW = 16
) (
  input  logic clk,
  input  logic rst_n,
  input  logic flush_i,
  input  logic link_active_i,

  input  logic                         rdi_valid_i,
  output logic                         rdi_ready_o,
  input  logic [ucie_adapter_pkg::FLIT_W-1:0] rdi_data_i,
  input  logic [ucie_adapter_pkg::SEQ_W-1:0]  rdi_seq_i,
  input  logic [ucie_adapter_pkg::CRC_W-1:0]  rdi_crc_i,

  output logic                         fdi_valid_o,
  input  logic                         fdi_ready_i,
  output logic [ucie_adapter_pkg::FLIT_W-1:0] fdi_data_o,

  output logic                         ack_valid_o,
  output logic [ucie_adapter_pkg::SEQ_W-1:0]  ack_seq_o,
  output logic                         retry_valid_o,
  output logic [ucie_adapter_pkg::SEQ_W-1:0]  retry_seq_o,
  output logic                         crc_error_o,
  output logic                         duplicate_o,
  output logic                         sequence_error_o
);
  import ucie_adapter_pkg::*;

  logic hold_valid_q;
  logic [FLIT_W-1:0] hold_data_q;
  logic [CRC_W-1:0] calc_crc;
  logic accept_rdi;
  logic [SEQ_W-1:0] expected_seq_q;
  logic [SEQ_W-1:0] distance_back;
  logic recent_duplicate;

  assign calc_crc         = crc32_bitwise(rdi_data_i, rdi_seq_i);
  assign rdi_ready_o      = link_active_i && (!hold_valid_q || fdi_ready_i);
  assign accept_rdi       = rdi_valid_i && rdi_ready_o;
  assign fdi_valid_o      = hold_valid_q;
  assign fdi_data_o       = hold_data_q;
  assign distance_back    = expected_seq_q - rdi_seq_i;
  assign recent_duplicate = (distance_back != '0) && (distance_back <= DUP_WINDOW);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hold_valid_q     <= 1'b0;
      hold_data_q      <= '0;
      expected_seq_q   <= '0;
      ack_valid_o      <= 1'b0;
      ack_seq_o        <= '0;
      retry_valid_o    <= 1'b0;
      retry_seq_o      <= '0;
      crc_error_o      <= 1'b0;
      duplicate_o      <= 1'b0;
      sequence_error_o <= 1'b0;
    end else if (flush_i) begin
      hold_valid_q     <= 1'b0;
      hold_data_q      <= '0;
      expected_seq_q   <= '0;
      ack_valid_o      <= 1'b0;
      ack_seq_o        <= '0;
      retry_valid_o    <= 1'b0;
      retry_seq_o      <= '0;
      crc_error_o      <= 1'b0;
      duplicate_o      <= 1'b0;
      sequence_error_o <= 1'b0;
    end else begin
      ack_valid_o      <= 1'b0;
      retry_valid_o    <= 1'b0;
      crc_error_o      <= 1'b0;
      duplicate_o      <= 1'b0;
      sequence_error_o <= 1'b0;

      if (hold_valid_q && fdi_ready_i)
        hold_valid_q <= 1'b0;

      if (accept_rdi) begin
        if (calc_crc != rdi_crc_i) begin
          retry_valid_o <= 1'b1;
          retry_seq_o   <= expected_seq_q;
          crc_error_o   <= 1'b1;
        end else if (rdi_seq_i == expected_seq_q) begin
          hold_valid_q   <= 1'b1;
          hold_data_q    <= rdi_data_i;
          ack_valid_o    <= 1'b1;
          ack_seq_o      <= rdi_seq_i;
          expected_seq_q <= expected_seq_q + 1'b1;
        end else if (recent_duplicate) begin
          ack_valid_o <= 1'b1;
          ack_seq_o   <= rdi_seq_i;
          duplicate_o <= 1'b1;
        end else begin
          retry_valid_o    <= 1'b1;
          retry_seq_o      <= expected_seq_q;
          sequence_error_o <= 1'b1;
        end
      end
    end
  end
endmodule
