`default_nettype none
`include "tiny_risc.svh"

module imm_gen #(
    parameter XLEN = 32
) (
    input  logic [31:0]     instruction,
    output logic [XLEN-1:0] immediate
);
    always_comb begin
        case (instruction[6:0])
            `OPCODE_LOAD, `OPCODE_I_TYPE, `OPCODE_JALR:
                immediate = {{(XLEN-12){instruction[31]}}, instruction[31:20]};
            `OPCODE_STORE:
                immediate = {{(XLEN-12){instruction[31]}}, instruction[31:25], instruction[11:7]};
            `OPCODE_BRANCH:
                immediate = {{(XLEN-13){instruction[31]}}, instruction[31], instruction[7],
                             instruction[30:25], instruction[11:8], 1'b0};
            `OPCODE_LUI, `OPCODE_AUIPC:
                immediate = {instruction[31:12], 12'b0};
            `OPCODE_JAL:
                immediate = {{(XLEN-21){instruction[31]}}, instruction[31], instruction[19:12],
                             instruction[20], instruction[30:21], 1'b0};
            default: immediate = '0;
        endcase
    end
endmodule

`default_nettype wire
