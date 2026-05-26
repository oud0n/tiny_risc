// control_unit.sv: decodes instructions and generates control signals for the datapath
`default_nettype none
`include "riscv32.svh"

module control_unit (
    input  wire [`OPCODE_WIDTH-1:0]      opcode,
    input  wire [`FUNCT3_WIDTH-1:0]      funct3,
    input  wire [`FUNCT7_WIDTH-1:0]      funct7,
    output wire                         reg_write,
    output wire                         alu_src_a,    // 0: rd1, 1: pc
    output wire                         alu_src_b,    // 0: rd2, 1: imm
    output wire                         mem_write,
    output wire [`RESULT_SRC_WIDTH-1:0] result_src,   // 00: alu, 01: mem, 10: pc+4
    output wire                         branch,
    output wire                         jump,         // jal / jalr
    output wire [`ALU_CONTROL_WIDTH-1:0] alu_control
);

    // alu operation types
    localparam [1:0] P_ALU_OP_ADD      = 2'b00;
    localparam [1:0] P_ALU_OP_SUB      = 2'b01;
    localparam [1:0] P_ALU_OP_R_I_TYPE = 2'b10;
    localparam [1:0] P_ALU_OP_LUI      = 2'b11;
    
    // internal signals for combinational logic
    logic                         reg_write_int;
    logic                         alu_src_a_int;
    logic                         alu_src_b_int;
    logic                         mem_write_int;
    logic [`RESULT_SRC_WIDTH-1:0] result_src_int;
    logic                         branch_int;
    logic                         jump_int;
    logic [`ALU_CONTROL_WIDTH-1:0] alu_control_int;
    logic [1:0]                   alu_op;

    // main decoder: decodes opcode into basic control signals
    always_comb begin
        // default values to avoid latches
        reg_write_int  = '0;
        alu_src_a_int  = '0;
        alu_src_b_int  = '0;
        mem_write_int  = '0;
        result_src_int = `RESULT_SRC_ALU;
        branch_int     = '0;
        jump_int       = '0;
        alu_op         = P_ALU_OP_ADD;

        case (opcode)
            `OPCODE_R_TYPE: begin 
                reg_write_int = '1; 
                alu_op        = P_ALU_OP_R_I_TYPE; 
            end
            `OPCODE_I_TYPE: begin 
                reg_write_int = '1; 
                alu_src_b_int = '1; 
                alu_op        = P_ALU_OP_R_I_TYPE; 
            end
            `OPCODE_LOAD: begin 
                reg_write_int  = '1; 
                alu_src_b_int  = '1; 
                result_src_int = `RESULT_SRC_MEM; 
            end
            `OPCODE_STORE: begin 
                alu_src_b_int = '1; 
                mem_write_int = '1; 
            end
            `OPCODE_BRANCH: begin 
                branch_int = '1; 
                alu_op     = P_ALU_OP_SUB; 
            end
            `OPCODE_JAL: begin 
                reg_write_int  = '1; 
                jump_int       = '1; 
                result_src_int = `RESULT_SRC_PC4; 
            end
            `OPCODE_JALR: begin 
                reg_write_int  = '1; 
                alu_src_b_int  = '1; 
                jump_int       = '1; 
                result_src_int = `RESULT_SRC_PC4; 
            end
            `OPCODE_LUI: begin 
                reg_write_int = '1; 
                alu_src_b_int = '1; 
                alu_op        = P_ALU_OP_LUI; 
            end
            `OPCODE_AUIPC: begin 
                reg_write_int = '1; 
                alu_src_a_int = '1; 
                alu_src_b_int = '1; 
                alu_op        = P_ALU_OP_ADD;
            end
            default: ; 
        endcase
    end

    // alu decoder: determines specific alu operation
    always_comb begin
        case (alu_op)
            P_ALU_OP_ADD: alu_control_int = `ALU_ADD;
            P_ALU_OP_SUB: alu_control_int = `ALU_SUB;
            P_ALU_OP_R_I_TYPE: begin
                case (funct3)
                    `FUNCT3_ADD_SUB: alu_control_int = (funct7[5] && opcode[5]) ? `ALU_SUB : `ALU_ADD;
                    `FUNCT3_AND:     alu_control_int = `ALU_AND;
                    `FUNCT3_OR:      alu_control_int = `ALU_OR;
                    `FUNCT3_XOR:     alu_control_int = `ALU_XOR;
                    `FUNCT3_SLL:     alu_control_int = `ALU_SLL;
                    `FUNCT3_SHIFT:   alu_control_int = funct7[5] ? `ALU_SRA : `ALU_SRL;
                    default:         alu_control_int = `ALU_ADD;
                endcase
            end
            P_ALU_OP_LUI: alu_control_int = `ALU_LUI;
            default:      alu_control_int = `ALU_ADD;
        endcase
    end

    // continuous assignments to output wires
    assign reg_write   = reg_write_int;
    assign alu_src_a   = alu_src_a_int;
    assign alu_src_b   = alu_src_b_int;
    assign mem_write   = mem_write_int;
    assign result_src  = result_src_int;
    assign branch      = branch_int;
    assign jump        = jump_int;
    assign alu_control = alu_control_int;

endmodule

`default_nettype wire