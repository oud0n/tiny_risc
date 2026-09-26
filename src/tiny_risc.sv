`default_nettype none
`include "tiny_risc.svh"

// One in-order RV32I hart; one outstanding request per memory port.
// A response must arrive after, not during, the request acceptance cycle.
module tiny_risc #(
    parameter logic [31:0] RESET_VECTOR = 32'b0
) (
    input  logic clk, rst_n, hart_enable,
    output logic fault,
    output logic imem_req_valid,
    input  logic imem_req_ready,
    output logic [31:0] imem_req_addr,
    input  logic imem_rsp_valid,
    input  logic [31:0] imem_rsp_inst,
    input  logic imem_rsp_error,
    output logic dmem_req_valid,
    input  logic dmem_req_ready,
    output logic [31:0] dmem_req_addr,
    output logic dmem_req_write,
    output logic [31:0] dmem_req_wdata,
    output logic [3:0] dmem_req_wstrb,
    input  logic dmem_rsp_valid,
    input  logic [31:0] dmem_rsp_rdata,
    input  logic dmem_rsp_error
);
    typedef enum logic [2:0] {
        FETCH_REQ, FETCH_WAIT, EXECUTE, MEM_REQ, MEM_WAIT, FAULTED
    } state_t;
    state_t state;
    logic [31:0] program_counter, instruction, immediate;
    logic [31:0] read_data_1, read_data_2, alu_result, alu_operand_b;
    logic [31:0] reg_write_data, load_data, shifted_rdata;
    logic [31:0] pc_plus_4, branch_target, next_pc;
    logic [1:0] byte_offset, mem_to_reg;
    logic [6:0] opcode, funct7;
    logic [4:0] rd, rs1, rs2;
    logic [2:0] funct3;
    logic [3:0] alu_control;
    logic reg_write, alu_src, mem_write, mem_read, branch, jump;
    logic alu_zero, alu_less_than, branch_taken, commit;
    logic memory_fault, control_flow_fault, illegal_op;

    assign opcode = instruction[6:0];
    assign rd = instruction[11:7];
    assign funct3 = instruction[14:12];
    assign rs1 = instruction[19:15];
    assign rs2 = instruction[24:20];
    assign funct7 = instruction[31:25];

    assign imem_req_valid = (state == FETCH_REQ) && hart_enable;
    assign imem_req_addr = program_counter;
    assign dmem_req_valid = (state == MEM_REQ);
    assign dmem_req_addr = {alu_result[31:2], 2'b00};
    assign dmem_req_write = mem_write;
    assign byte_offset = alu_result[1:0];
    assign dmem_req_wdata = read_data_2 << (8 * byte_offset);
    assign fault = (state == FAULTED);
    always_comb begin
        case (funct3)
            3'b000: dmem_req_wstrb = 4'b0001 << byte_offset;
            3'b001: dmem_req_wstrb = 4'b0011 << byte_offset;
            3'b010: dmem_req_wstrb = 4'b1111;
            default: dmem_req_wstrb = 4'b0000;
        endcase
    end

    assign shifted_rdata = dmem_rsp_rdata >> (8 * byte_offset);
    always_comb begin
        case (funct3)
            3'b000: load_data = {{24{shifted_rdata[7]}}, shifted_rdata[7:0]};
            3'b001: load_data = {{16{shifted_rdata[15]}}, shifted_rdata[15:0]};
            3'b010: load_data = dmem_rsp_rdata;
            3'b100: load_data = {24'b0, shifted_rdata[7:0]};
            3'b101: load_data = {16'b0, shifted_rdata[15:0]};
            default: load_data = '0;
        endcase
    end
    always_comb begin
        memory_fault = 1'b0;
        if (mem_read) begin
            case (funct3)
                3'b000, 3'b100: memory_fault = 1'b0;
                3'b001, 3'b101: memory_fault = byte_offset[0];
                3'b010: memory_fault = (byte_offset != 2'b00);
                default: memory_fault = 1'b1;
            endcase
        end else if (mem_write) begin
            case (funct3)
                3'b000: memory_fault = 1'b0;
                3'b001: memory_fault = byte_offset[0];
                3'b010: memory_fault = (byte_offset != 2'b00);
                default: memory_fault = 1'b1;
            endcase
        end
    end
    assign control_flow_fault = (jump || branch_taken) &&
                                (next_pc[1:0] != 2'b00);
    assign commit = ((state == EXECUTE) && !(mem_read || mem_write) &&
                     !control_flow_fault && !illegal_op) ||
                    ((state == MEM_WAIT) && dmem_rsp_valid && !dmem_rsp_error);
    always_comb begin
        case (mem_to_reg)
            2'b00: reg_write_data = alu_result;
            2'b01: reg_write_data = load_data;
            2'b10: reg_write_data = pc_plus_4;
            2'b11: reg_write_data = program_counter + immediate;
        endcase
    end
    regfile i_regfile (
        .clock(clk), .resetn(rst_n), .we(reg_write && commit),
        .addr_rs1(rs1), .addr_rs2(rs2), .addr_rd(rd),
        .write_data(reg_write_data), .data_rs1(read_data_1),
        .data_rs2(read_data_2)
    );
    imm_gen i_imm_gen (.instruction(instruction), .immediate(immediate));
    assign alu_operand_b = alu_src ? immediate : read_data_2;
    alu i_alu (
        .operand_a(read_data_1), .operand_b(alu_operand_b),
        .alu_control(alu_control), .result(alu_result),
        .zero(alu_zero), .less_than(alu_less_than)
    );
    control i_control (
        .opcode(opcode), .funct3(funct3), .funct7(funct7),
        .reg_write(reg_write), .alu_src(alu_src),
        .mem_to_reg(mem_to_reg), .mem_write(mem_write),
        .mem_read(mem_read), .branch(branch), .jump(jump),
        .alu_control(alu_control), .illegal_op(illegal_op)
    );

    assign pc_plus_4 = program_counter + 32'd4;
    assign branch_target = program_counter + immediate;
    always_comb begin
        case (funct3)
            `FUNCT3_BEQ: branch_taken = branch && alu_zero;
            `FUNCT3_BNE: branch_taken = branch && !alu_zero;
            `FUNCT3_BLT, `FUNCT3_BLTU: branch_taken = branch && alu_less_than;
            `FUNCT3_BGE, `FUNCT3_BGEU: branch_taken = branch && !alu_less_than;
            default: branch_taken = 1'b0;
        endcase
    end
    always_comb begin
        if (jump) begin
            next_pc = (opcode == `OPCODE_JALR) ?
                ((read_data_1 + immediate) & 32'hffff_fffe) : branch_target;
        end else if (branch_taken) next_pc = branch_target;
        else next_pc = pc_plus_4;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= FETCH_REQ;
            program_counter <= RESET_VECTOR;
            instruction <= 32'h00000013;
        end else begin
            case (state)
                FETCH_REQ: if (hart_enable && imem_req_ready) state <= FETCH_WAIT;
                FETCH_WAIT: if (imem_rsp_valid) begin
                    if (imem_rsp_error) state <= FAULTED;
                    else begin
                        instruction <= imem_rsp_inst;
                        state <= EXECUTE;
                    end
                end
                EXECUTE: begin
                    if (memory_fault || control_flow_fault || illegal_op) state <= FAULTED;
                    else if (mem_read || mem_write) state <= MEM_REQ;
                    else begin
                        program_counter <= next_pc;
                        state <= FETCH_REQ;
                    end
                end
                MEM_REQ: if (dmem_req_ready) state <= MEM_WAIT;
                MEM_WAIT: if (dmem_rsp_valid) begin
                    if (dmem_rsp_error) state <= FAULTED;
                    else begin
                        program_counter <= next_pc;
                        state <= FETCH_REQ;
                    end
                end
                FAULTED: state <= FAULTED;
                default: state <= FAULTED;
            endcase
        end
    end
endmodule

`default_nettype wire
