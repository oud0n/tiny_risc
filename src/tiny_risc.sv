// ====================================================================
// Module: tiny_risc
// Description: RV31I / RV32I single-cycle processor core.
//              Combines controllers, ALU, Register File, and ImmGen.
// NOTE: Uppercase is EXCLUSIVELY used for parameters and localparams.
// ====================================================================

`default_nettype none

`include "tiny_risc.svh"

module tiny_risc #(
    localparam XLEN = 32
) (
    input logic clk,
    input logic rst_n,

    // Instruction memory interface
    output logic [XLEN-1:0] imem_addr,
    input  logic [XLEN-1:0] imem_inst,

    // Data memory interface
    output logic [XLEN-1:0] dmem_addr,
    output logic [XLEN-1:0] dmem_wdata,
    output logic            dmem_write,
    output logic            dmem_read,
    input  logic [XLEN-1:0] dmem_rdata
);

    // Local declarations of program counter and wires in snake_case
    logic [XLEN-1:0] program_counter;
    logic [XLEN-1:0] next_pc;
    logic [XLEN-1:0] pc_plus_4;
    logic [XLEN-1:0] branch_target;

    // Decoded instruction fields
    logic [     6:0] opcode;
    logic [     4:0] rd;
    logic [     4:0] rs1;
    logic [     4:0] rs2;
    logic [     2:0] funct3;
    logic [     6:0] funct7;

    // Control unit signals
    logic            reg_write;
    logic            alu_src;
    logic [     1:0] mem_to_reg;
    logic            mem_write;
    logic            mem_read;
    logic            branch;
    logic            jump;
    logic [     3:0] alu_control;

    // Register file outputs
    logic [XLEN-1:0] read_data_1;
    logic [XLEN-1:0] read_data_2;
    logic [XLEN-1:0] reg_write_data;

    // Immediate generator output
    logic [XLEN-1:0] immediate;

    // ALU interfaces
    logic [XLEN-1:0] alu_operand_b;
    logic [XLEN-1:0] alu_result;
    logic            alu_zero;
    logic            alu_less_than;

    // Jump & Branch logic
    logic            branch_taken;

    // Split instruction fields
    assign opcode        = imem_inst[6:0];
    assign rd            = imem_inst[11:7];
    assign funct3        = imem_inst[14:12];
    assign rs1           = imem_inst[19:15];
    assign rs2           = imem_inst[24:20];
    assign funct7        = imem_inst[31:25];

    // Map Instruction Memory address to current PC
    assign imem_addr     = program_counter;

    // Program Counter update logic
    assign pc_plus_4     = program_counter + 32'd4;
    assign branch_target = program_counter + immediate;

    always_comb begin
        // Branch conditioning
        case (funct3)
            `FUNCT3_BEQ: branch_taken = branch & alu_zero;  // BEQ
            `FUNCT3_BNE: branch_taken = branch & ~alu_zero;  // BNE
            `FUNCT3_BLT: branch_taken = branch & alu_less_than;  // BLT
            `FUNCT3_BGE: branch_taken = branch & ~alu_less_than;  // BGE
            `FUNCT3_BLTU:
            branch_taken = branch & alu_less_than;  // BLTU (unsigned)
            `FUNCT3_BGEU:
            branch_taken = branch & ~alu_less_than;  // BGEU (unsigned)
            default: branch_taken = 1'b0;
        endcase
    end

    always_comb begin
        // PC source selection logic
        if (jump) begin
            if (`OPCODE_JALR == opcode)  // JALR
                next_pc = (read_data_1 + immediate) & ~32'h1;
            else  // JAL
                next_pc = branch_target;
        end else if (branch_taken) begin
            next_pc = branch_target;
        end else begin
            next_pc = pc_plus_4;
        end
    end

    // Program Counter state storage
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            program_counter <= 32'h0;
        end else begin
            program_counter <= next_pc;
        end
    end

    // Register File source mapping
    always_comb begin
        case (mem_to_reg)
            2'b00:   reg_write_data = alu_result;
            2'b01:   reg_write_data = dmem_rdata;
            2'b10:   reg_write_data = pc_plus_4;
            default: reg_write_data = alu_result;
        endcase
    end

    // Instantiate Register File (32 general registers)
    regfile #(
        .XLEN(XLEN)
    ) i_regfile (
        .clk(clk),
        .rst_n(rst_n),
        .we(reg_write),
        .addr_rs1(rs1),
        .addr_rs2(rs2),
        .addr_rd(rd),
        .write_data(reg_write_data),
        .read_data_1(read_data_1),
        .read_data_2(read_data_2)
    );

    // Instantiate Immediate Generator
    imm_gen #(
        .XLEN(XLEN)
    ) i_imm_gen (
        .instruction(imem_inst),
        .immediate  (immediate)
    );

    // Select ALU Operand B
    assign alu_operand_b = alu_src ? immediate : read_data_2;

    // Instantiate ALU Core
    alu #(
        .XLEN(XLEN)
    ) i_alu (
        .operand_a(read_data_1),
        .operand_b(alu_operand_b),
        .alu_control(alu_control),
        .result(alu_result),
        .zero(alu_zero),
        .less_than(alu_less_than)
    );

    // Instantiate Control Unit decoder
    control i_control (
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .mem_to_reg(mem_to_reg),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .branch(branch),
        .jump(jump),
        .alu_control(alu_control)
    );

    // Map Data Memory outputs
    assign dmem_addr  = alu_result;
    assign dmem_wdata = read_data_2;
    assign dmem_write = mem_write;
    assign dmem_read  = mem_read;

endmodule

`default_nettype wire
