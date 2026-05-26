/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

export interface SvModule {
  filename: string;
  description: string;
  code: string;
}

export const SV_MODULES: { [key: string]: SvModule } = {
  cpu_top: {
    filename: "rv32i_cpu.sv",
    description: "The top-level single-cycle CPU core mapping instructions, program counter, and executing datapaths.",
    code: `// ====================================================================
// Module: rv32i_cpu
// Description: RV31I / RV32I single-cycle processor core.
//              Combines controllers, ALU, Register File, and ImmGen.
// NOTE: Uppercase is EXCLUSIVELY used for parameters and localparams.
// ====================================================================

module rv32i_cpu #(
  parameter XLEN = 32
)(
  input  logic            clk,
  input  logic            rst_n,
  
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
  logic [6:0]      opcode;
  logic [4:0]      rd;
  logic [4:0]      rs1;
  logic [4:0]      rs2;
  logic [2:0]      funct3;
  logic [6:0]      funct7;
  
  // Control unit signals
  logic            reg_write;
  logic            alu_src;
  logic [1:0]      mem_to_reg;
  logic            mem_write;
  logic            mem_read;
  logic            branch;
  logic            jump;
  logic [3:0]      alu_control;
  
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
  assign opcode  = imem_inst[6:0];
  assign rd      = imem_inst[11:7];
  assign funct3  = imem_inst[14:12];
  assign rs1     = imem_inst[19:15];
  assign rs2     = imem_inst[24:20];
  assign funct7  = imem_inst[31:25];

  // Map Instruction Memory address to current PC
  assign imem_addr = program_counter;

  // Program Counter update logic
  assign pc_plus_4 = program_counter + 32'd4;
  assign branch_target = program_counter + immediate;
  
  always_comb begin
    // Branch conditioning
    case (funct3)
      3'b000:  branch_taken = branch & alu_zero;          // BEQ
      3'b001:  branch_taken = branch & ~alu_zero;         // BNE
      3'b100:  branch_taken = branch & alu_less_than;     // BLT
      3'b101:  branch_taken = branch & ~alu_less_than;    // BGE
      3'b110:  branch_taken = branch & alu_less_than;     // BLTU (unsigned)
      3'b111:  branch_taken = branch & ~alu_less_than;    // BGEU (unsigned)
      default: branch_taken = 1'b0;
    endcase
  end

  always_comb begin
    // PC source selection logic
    if (jump) begin
      if (opcode == 7'b1100117) // JALR
        next_pc = (read_data_1 + immediate) & ~32'h1;
      else // JAL
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
  rv32i_regfile #(
    .XLEN(XLEN)
  ) regs_inst (
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
  rv32i_imm_gen #(
    .XLEN(XLEN)
  ) imm_inst (
    .instruction(imem_inst),
    .immediate(immediate)
  );

  // Select ALU Operand B
  assign alu_operand_b = alu_src ? immediate : read_data_2;

  // Instantiate ALU Core
  rv32i_alu #(
    .XLEN(XLEN)
  ) alu_inst (
    .operand_a(read_data_1),
    .operand_b(alu_operand_b),
    .alu_control(alu_control),
    .result(alu_result),
    .zero(alu_zero),
    .less_than(alu_less_than)
  );

  // Instantiate Control Unit decoder
  rv32i_control control_inst (
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
  assign dmem_addr   = alu_result;
  assign dmem_wdata  = read_data_2;
  assign dmem_write  = mem_write;
  assign dmem_read   = mem_read;

endmodule
`
  },
  control_unit: {
    filename: "rv32i_control.sv",
    description: "The decoder subsystem compiling instruction opcodes, funct3, and funct7 fields to generate active control signals.",
    code: `// ====================================================================
// Module: rv32i_control
// Description: Decodes instruction opcodes, funct3, and funct7 elements.
//              Generates datapath selection flags and ALU operations.
// ====================================================================

module rv32i_control (
  input  logic [6:0] opcode,
  input  logic [2:0] funct3,
  input  logic [6:0] funct7,
  
  output logic       reg_write,
  output logic       alu_src,
  output logic [1:0] mem_to_reg, // 00: ALU, 01: Mem, 10: PC+4
  output logic       mem_write,
  output logic       mem_read,
  output logic       branch,
  output logic       jump,
  output logic [3:0] alu_control
);

  // Define local constants for ALU operations using UPPERCASE
  localparam ALU_ADD  = 4'b0000;
  localparam ALU_SUB  = 4'b0001;
  localparam ALU_SLL  = 4'b0010;
  localparam ALU_SLT  = 4'b0011;
  localparam ALU_SLTU = 4'b0100;
  localparam ALU_XOR  = 4'b0101;
  localparam ALU_SRL  = 4'b0110;
  localparam ALU_SRA  = 4'b0111;
  localparam ALU_OR   = 4'b1000;
  localparam ALU_AND  = 4'b1001;

  // Single-cycle main control decoder logic
  always_comb begin
    // Setup sensible defaults in lower_case
    reg_write   = 1'b0;
    alu_src     = 1'b0;
    mem_to_reg  = 2'b00;
    mem_write   = 1'b0;
    mem_read    = 1'b0;
    branch      = 1'b0;
    jump        = 1'b0;
    alu_control = ALU_ADD;

    case (opcode)
      // R-Type operations (ADD, SUB, AND, OR, XOR, shifts etc.)
      7'b0110011: begin
        reg_write  = 1'b1;
        alu_src    = 1'b0;
        mem_to_reg = 2'b00;
        
        // Select custom operation depending on funct3 & funct7
        case (funct3)
          3'b000:  alu_control = (funct7[5]) ? ALU_SUB : ALU_ADD;
          3'b001:  alu_control = ALU_SLL;
          3'b010:  alu_control = ALU_SLT;
          3'b011:  alu_control = ALU_SLTU;
          3'b100:  alu_control = ALU_XOR;
          3'b101:  alu_control = (funct7[5]) ? ALU_SRA : ALU_SRL;
          3'b110:  alu_control = ALU_OR;
          3'b111:  alu_control = ALU_AND;
          default: alu_control = ALU_ADD;
        endcase
      end

      // I-Type ALU operations (ADDI, ANDI, ORI, XORI etc.)
      7'b0010011: begin
        reg_write  = 1'b1;
        alu_src    = 1'b1;
        mem_to_reg = 2'b00;
        
        case (funct3)
          3'b000:  alu_control = ALU_ADD;
          3'b001:  alu_control = ALU_SLL; // SLLI
          3'b010:  alu_control = ALU_SLT; // SLTI
          3'b011:  alu_control = ALU_SLTU;// SLTIU
          3'b100:  alu_control = ALU_XOR; // XORI
          3'b101:  alu_control = (funct7[5]) ? ALU_SRA : ALU_SRL; // SRAI / SRLI
          3'b110:  alu_control = ALU_OR;  // ORI
          3'b111:  alu_control = ALU_AND; // ANDI
          default: alu_control = ALU_ADD;
        endcase
      end

      // I-Type Load operations (LW, LB, LH, LBU, LHU)
      7'b0000011: begin
        reg_write  = 1'b1;
        alu_src    = 1'b1;
        mem_to_reg = 2'b01; // Write-back memory contents
        mem_read   = 1'b1;
        alu_control = ALU_ADD; // Node offset addition
      end

      // S-Type Store operations (SW, SB, SH)
      7'b0100011: begin
        reg_write  = 1'b0;
        alu_src    = 1'b1;
        mem_write  = 1'b1;
        alu_control = ALU_ADD; // Address addition
      end

      // B-Type Branch instructions (BEQ, BNE, BLT, BGE)
      7'b1100011: begin
        reg_write  = 1'b0;
        alu_src    = 1'b0;
        branch     = 1'b1;
        
        case (funct3)
          3'b000:  alu_control = ALU_SUB; // BEQ (uses sub zero check)
          3'b001:  alu_control = ALU_SUB; // BNE (uses sub zero check)
          3'b100:  alu_control = ALU_SLT; // BLT (uses signed comparison)
          3'b101:  alu_control = ALU_SLT; // BGE (uses signed comparison)
          3'b110:  alu_control = ALU_SLTU;// BLTU (uses unsigned comparison)
          3'b111:  alu_control = ALU_SLTU;// BGEU (uses unsigned comparison)
          default: alu_control = ALU_SUB;
        endcase
      end

      // J-Type JAL jump
      7'b1101111: begin
        reg_write  = 1'b1;
        mem_to_reg = 2'b10; // PC + 4 written to link register standard x1 (ra)
        jump       = 1'b1;
      end

      // I-Type JALR jump
      7'b1100117: begin
        reg_write  = 1'b1;
        alu_src    = 1'b1;
        mem_to_reg = 2'b10; // PC + 4 written to link register
        jump       = 1'b1;
        alu_control = ALU_ADD;
      end

      // U-Type LUI loading
      7'b0110117: begin
        reg_write  = 1'b1;
        alu_src    = 1'b1;
        mem_to_reg = 2'b00;
        // Immediate value shifted left will be routed straight through ALU
        alu_control = 4'b1010; // Passthrough logic or customized add
      end

      default: begin
        // Secure unknown operations
        reg_write   = 1'b0;
        alu_control = ALU_ADD;
      end
    endcase
  end

endmodule
`
  },
  alu: {
    filename: "rv32i_alu.sv",
    description: "Arithmetic Logic Unit responsible for addition, subtraction, bitwise logic, and barrel shifting.",
    code: `// ====================================================================
// Module: rv32i_alu
// Description: Implements baseline single-cycle logical and arithmetic
//              operations including division offsets and shifts.
// ====================================================================

module rv32i_alu #(
  parameter XLEN = 32
)(
  input  logic [XLEN-1:0] operand_a,
  input  logic [XLEN-1:0] operand_b,
  input  logic [3:0]      alu_control,
  
  output logic [XLEN-1:0] result,
  output logic            zero,
  output logic            less_than
);

  // Define local operation codes within localparam using UPPERCASE
  localparam ALU_ADD  = 4'b0000;
  localparam ALU_SUB  = 4'b0001;
  localparam ALU_SLL  = 4'b0010;
  localparam ALU_SLT  = 4'b0011;
  localparam ALU_SLTU = 4'b0100;
  localparam ALU_XOR  = 4'b0101;
  localparam ALU_SRL  = 4'b0110;
  localparam ALU_SRA  = 4'b0111;
  localparam ALU_OR   = 4'b1000;
  localparam ALU_AND  = 4'b1001;
  localparam ALU_LUI  = 4'b1010; // Passthrough of imm (operand_b)

  // Internal wire for signed operands
  logic signed [XLEN-1:0] signed_a;
  logic signed [XLEN-1:0] signed_b;
  
  assign signed_a = operand_a;
  assign signed_b = operand_b;

  // Compute ALU Result based on current control selection
  always_comb begin
    case (alu_control)
      ALU_ADD:  result = operand_a + operand_b;
      ALU_SUB:  result = operand_a - operand_b;
      ALU_SLL:  result = operand_a << operand_b[4:0];
      ALU_SLT:  result = (signed_a < signed_b) ? 32'b1 : 32'b0;
      ALU_SLTU: result = (operand_a < operand_b) ? 32'b1 : 32'b0;
      ALU_XOR:  result = operand_a ^ operand_b;
      ALU_SRL:  result = operand_a >> operand_b[4:0];
      ALU_SRA:  result = signed_a >>> operand_b[4:0];
      ALU_OR:   result = operand_a | operand_b;
      ALU_AND:  result = operand_a & operand_b;
      ALU_LUI:  result = operand_b; // Directly forward immediate
      default:  result = 32'b0;
    endcase
  end

  // Zero & comparator status evaluation outputs
  assign zero = (result == 32'b0);
  
  always_comb begin
    if (alu_control == ALU_SLTU)
      less_than = (operand_a < operand_b);
    else
      less_than = (signed_a < signed_b);
  end

endmodule
`
  },
  regfile: {
    filename: "rv32i_regfile.sv",
    description: "The multi-ported 32x32 Register File. Keeps x0 locked to zero, providing dual reads and single synchronized write ports.",
    code: `// ====================================================================
// Module: rv32i_regfile
// Description: Multi-ported 32x32 general register file.
//              Contains x0 hardwired to constant 0x0 at all times.
// ====================================================================

module rv32i_regfile #(
  parameter XLEN = 32
)(
  input  logic            clk,
  input  logic            rst_n,
  input  logic            we,          // Write enable
  
  input  logic [4:0]      addr_rs1,    // Read address index 1
  input  logic [4:0]      addr_rs2,    // Read address index 2
  input  logic [4:0]      addr_rd,     // Write address index 
  
  input  logic [XLEN-1:0] write_data,
  
  output logic [XLEN-1:0] read_data_1,
  output logic [XLEN-1:0] read_data_2
);

  // Declare 32 active general registers using low_case signal
  logic [XLEN-1:0] register_array [31:1];

  // Port reading combinations (Register x0 hardwired to zero)
  assign read_data_1 = (addr_rs1 == 5'b0) ? 32'b0 : register_array[addr_rs1];
  assign read_data_2 = (addr_rs2 == 5'b0) ? 32'b0 : register_array[addr_rs2];

  // Regfile synchronized writes
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset registers to simple default state
      integer index;
      for (index = 1; index < 32; index = index + 1) begin
        register_array[index] <= 32'b0;
      end
    end else if (we && (addr_rd != 5'b0)) begin
      // Write incoming data only if not register zero
      register_array[addr_rd] <= write_data;
    end
  end

endmodule
`
  },
  imm_gen: {
    filename: "rv32i_imm_gen.sv",
    description: "Generates the appropriate formatted immediate signs and bit distributions from decoded instruction fields.",
    code: `// ====================================================================
// Module: rv32i_imm_gen
// Description: Decoded offset assembler based on custom RV32I structures.
//              Generates sign-extended 32-bit immediate offsets.
// ====================================================================

module rv32i_imm_gen #(
  parameter XLEN = 32
)(
  input  logic [XLEN-1:0] instruction,
  output logic [XLEN-1:0] immediate
);

  // Extract instruction opcode for fast immediate identification
  logic [6:0] opcode;
  assign opcode = instruction[6:0];

  always_comb begin
    case (opcode)
      // I-Type Instructions (Arithmetic ADDI, Shifts, Loads, JALR)
      7'b0010011, 7'b0000011, 7'b1100117: begin
        immediate = {{20{instruction[31]}}, instruction[31:20]};
      end

      // S-Type Instructions (Stores SW, SB, SH)
      7'b0100011: begin
        immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
      end

      // B-Type Instructions (Branches BEQ, BNE, BLT etc.)
      7'b1100011: begin
        immediate = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
      end

      // U-Type Instructions (LUI, AUIPC)
      7'b0110117, 7'b0010117: begin
        immediate = {instruction[31:12], 12'b0};
      end

      // J-Type Instructions (JAL jump)
      7'b1101111: begin
        immediate = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
      end

      default: begin
        // Secure clear default
        immediate = 32'b0;
      end
    endcase
  end

endmodule
`
  }
};
