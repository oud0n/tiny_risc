`default_nettype none
`include "riscv32.svh"

module alu (
    input logic [`DATA_WIDTH-1:0] a,
    input logic [`DATA_WIDTH-1:0] b,
    input logic [3:0] alu_control_code,
    output logic [`DATA_WIDTH-1:0] out,
    output logic is_zero
);

    always @(*) begin : alu
        out = 'x;
        case (alu_control_code)
            `ALU_AND:  out = a & b;
            `ALU_OR:   out = a | b;
            `ALU_ADD:  out = a + b;
            `ALU_SUB:  out = a - b;
            `ALU_SLL:  out = a << b[`REG_WIDTH-1:0];
            `ALU_SRL:  out = a >> b[`REG_WIDTH-1:0];
            `ALU_SRA:  out = $signed(a) >>> b[`REG_WIDTH-1:0];
            `ALU_XOR:  out = a ^ b;
            `ALU_SLT:  out = ($signed(a) < $signed(b)) ? `DATA_WIDTH'h1 : `DATA_WIDTH'h0;
            `ALU_SLTU: out = (a < b) ? `DATA_WIDTH'h1 : `DATA_WIDTH'h0;
            default:   out = `DATA_WIDTH'h0;
        endcase
    end

    assign is_zero = (out == `DATA_WIDTH'h0);

endmodule

`default_nettype wire
