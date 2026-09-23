package ucie_adapter_pkg;
  parameter int FLIT_W = 256;
  parameter int SEQ_W  = 8;
  parameter int CRC_W  = 32;

  typedef enum logic [2:0] {
    LINK_RESET,
    LINK_INIT,
    LINK_ACTIVE,
    LINK_RECOVERY,
    LINK_DISABLED
  } link_state_e;

  function automatic logic [31:0] crc32_bitwise(
    input logic [FLIT_W-1:0] data,
    input logic [SEQ_W-1:0]  seq
  );
    logic [31:0] crc;
    logic feedback;
    int i;
    begin
      crc = 32'hFFFF_FFFF;
      for (i = SEQ_W-1; i >= 0; i--) begin
        feedback = crc[31] ^ seq[i];
        crc = {crc[30:0], 1'b0};
        if (feedback) crc ^= 32'h04C11DB7;
      end
      for (i = FLIT_W-1; i >= 0; i--) begin
        feedback = crc[31] ^ data[i];
        crc = {crc[30:0], 1'b0};
        if (feedback) crc ^= 32'h04C11DB7;
      end
      crc32_bitwise = ~crc;
    end
  endfunction
endpackage
