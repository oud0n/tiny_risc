`default_nettype none
`include "tiny_risc.svh"

module alu #(
    parameter XLEN = 32
) (
    input  logic [XLEN-1:0] operand_a,
    input  logic [XLEN-1:0] operand_b,
    input  logic [3:0]      alu_control,
    output logic [XLEN-1:0] result,
    output logic            zero,
    output logic            less_than
);
    always_comb begin
        case (alu_control)
            `ALU_ADD:  result = operand_a + operand_b;
            `ALU_SUB:  result = operand_a - operand_b;
            `ALU_AND:  result = operand_a & operand_b;
            `ALU_OR:   result = operand_a | operand_b;
            `ALU_XOR:  result = operand_a ^ operand_b;
            `ALU_SLL:  result = operand_a << operand_b[4:0];
            `ALU_SRL:  result = operand_a >> operand_b[4:0];
            `ALU_SRA:  result = $signed(operand_a) >>> operand_b[4:0];
            `ALU_SLT:  result = {{(XLEN-1){1'b0}}, ($signed(operand_a) < $signed(operand_b))};
            `ALU_SLTU: result = {{(XLEN-1){1'b0}}, (operand_a < operand_b)};
            `ALU_LUI:  result = operand_b;
            default:   result = '0;
        endcase
    end

    assign zero = (operand_a == operand_b);
    assign less_than = (alu_control == `ALU_SLTU) ?
        (operand_a < operand_b) : ($signed(operand_a) < $signed(operand_b));
endmodule

`default_nettype wire
