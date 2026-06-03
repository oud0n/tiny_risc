
// "The multi-ported 32x32 Register File. Keeps x0 locked to zero, providing dual reads and single synchronized write ports.",
// ====================================================================
// Module: regfile
// Description: Multi-ported 32x32 general register file.
//              Contains x0 hardwired to constant 0x0 at all times.
// ====================================================================

module regfile #(
    parameter XLEN = 32
) (
    input logic clock,
    input logic resetn,
    input logic we,     // Write enable

    input logic [4:0] addr_rs1,  // Read address index 1
    input logic [4:0] addr_rs2,  // Read address index 2
    input logic [4:0] addr_rd,   // Write address index 

    input logic [XLEN-1:0] write_data,

    output logic [XLEN-1:0] data_rs1,
    output logic [XLEN-1:0] data_rs2
);

    // Declare 32 active general registers using low_case signal
    logic [XLEN-1:0] register_array[31:0];

    // Port reading combinations (Register x0 hardwired to zero)
    assign data_rs1 = (addr_rs1 == 5'b0) ? 32'b0 : register_array[addr_rs1];
    assign data_rs2 = (addr_rs2 == 5'b0) ? 32'b0 : register_array[addr_rs2];

    // Regfile synchronized writes
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            // Reset registers to simple default state
            integer index;
            for (index = 0; index < 32; index = index + 1) begin
                register_array[index] <= 32'b0;
            end
        end else if (we && (addr_rd != 5'b0)) begin
            // Write incoming data only if not register zero
            register_array[addr_rd] <= write_data;
        end
    end
endmodule
