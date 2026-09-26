`default_nettype none
`include "tiny_risc.svh"

module tb_control;

    // DUT inputs
    logic [6:0] tb_opcode;
    logic [2:0] tb_funct3;
    logic [6:0] tb_funct7;

    // DUT outputs
    logic       tb_reg_write;
    logic       tb_alu_src;
    logic [1:0] tb_mem_to_reg;
    logic       tb_mem_write;
    logic       tb_mem_read;
    logic       tb_branch;
    logic       tb_jump;
    logic [3:0] tb_alu_control;
    logic       tb_illegal_op;

    integer     fail_cnt = 0;
    integer     compare_cnt = 0;

    // Instantiate DUT
    control i_control (
        .opcode(tb_opcode),
        .funct3(tb_funct3),
        .funct7(tb_funct7),
        .reg_write(tb_reg_write),
        .alu_src(tb_alu_src),
        .mem_to_reg(tb_mem_to_reg),
        .mem_write(tb_mem_write),
        .mem_read(tb_mem_read),
        .branch(tb_branch),
        .jump(tb_jump),
        .alu_control(tb_alu_control),
        .illegal_op(tb_illegal_op)
    );

    // Setup waveform dump
    initial begin
        $dumpfile("tb_control.vcd");
        $dumpvars(0, tb_control);
    end

    // Helper task to check outputs
    task check_ctrl(
        input logic [6:0] op,
        input logic [2:0] f3,
        input logic [6:0] f7,
        input logic       exp_reg_write,
        input logic       exp_alu_src,
        input logic [1:0] exp_mem_to_reg,
        input logic       exp_mem_write,
        input logic       exp_mem_read,
        input logic       exp_branch,
        input logic       exp_jump,
        input logic [3:0] exp_alu_control,
        input string      test_name
    );
        tb_opcode = op;
        tb_funct3 = f3;
        tb_funct7 = f7;
        #1; // Wait for logic propagation

        compare_cnt = compare_cnt + 1;
        if (tb_reg_write !== exp_reg_write ||
            tb_alu_src !== exp_alu_src ||
            tb_mem_to_reg !== exp_mem_to_reg ||
            tb_mem_write !== exp_mem_write ||
            tb_mem_read !== exp_mem_read ||
            tb_branch !== exp_branch ||
            tb_jump !== exp_jump ||
            tb_alu_control !== exp_alu_control) begin
            
            fail_cnt = fail_cnt + 1;
            $display("FAIL: %s", test_name);
            $display("  Inputs  : opcode=%b(7'h%h), funct3=%b, funct7=%b", op, op, f3, f7);
            $display("  Expected: reg_write=%b, alu_src=%b, mem_to_reg=%b, mem_write=%b, mem_read=%b, branch=%b, jump=%b, alu_ctrl=4'h%h",
                     exp_reg_write, exp_alu_src, exp_mem_to_reg, exp_mem_write, exp_mem_read, exp_branch, exp_jump, exp_alu_control);
            $display("  Actual  : reg_write=%b, alu_src=%b, mem_to_reg=%b, mem_write=%b, mem_read=%b, branch=%b, jump=%b, alu_ctrl=4'h%h",
                     tb_reg_write, tb_alu_src, tb_mem_to_reg, tb_mem_write, tb_mem_read, tb_branch, tb_jump, tb_alu_control);
        end else begin
            // $display("PASS: %s", test_name);
        end
    endtask

    function void display_result();
        if (fail_cnt == 0) begin
            $display("Pass: 0 errors, %d checks", compare_cnt);
        end else begin
            $display("Error: %d errors, %d checks", fail_cnt, compare_cnt);
        end
    endfunction

    initial begin
        $display("-------------------------------------------");
        $display("Starting CONTROL Testbench");
        $display("-------------------------------------------");

        // Sensible defaults
        tb_opcode = 7'b0;
        tb_funct3 = 3'b0;
        tb_funct7 = 7'b0;
        #10;

        // ==========================================
        // 1. R-Type operations (Opcode: 7'b0110011)
        // ==========================================
        $display("-- 1. R-Type checks");
        // ADD
        check_ctrl(`OPCODE_R_TYPE, 3'b000, 7'h00, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_ADD, "R-Type ADD");
        // SUB
        check_ctrl(`OPCODE_R_TYPE, 3'b000, 7'h20, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_SUB, "R-Type SUB");
        // SLL
        check_ctrl(`OPCODE_R_TYPE, 3'b001, 7'h00, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_SLL, "R-Type SLL");
        // SLT
        check_ctrl(`OPCODE_R_TYPE, 3'b010, 7'h00, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_SLT, "R-Type SLT");
        // SLTU
        check_ctrl(`OPCODE_R_TYPE, 3'b011, 7'h00, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_SLTU, "R-Type SLTU");
        // XOR
        check_ctrl(`OPCODE_R_TYPE, 3'b100, 7'h00, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_XOR, "R-Type XOR");
        // SRL
        check_ctrl(`OPCODE_R_TYPE, 3'b101, 7'h00, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_SRL, "R-Type SRL");
        // SRA
        check_ctrl(`OPCODE_R_TYPE, 3'b101, 7'h20, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_SRA, "R-Type SRA");
        // OR
        check_ctrl(`OPCODE_R_TYPE, 3'b110, 7'h00, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_OR, "R-Type OR");
        // AND
        check_ctrl(`OPCODE_R_TYPE, 3'b111, 7'h00, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_AND, "R-Type AND");

        // ==========================================
        // 2. I-Type ALU operations (Opcode: 7'b0010011)
        // ==========================================
        $display("-- 2. I-Type ALU checks");
        // ADDI
        check_ctrl(`OPCODE_I_TYPE, 3'b000, 7'h00, 1'b1, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_ADD, "I-Type ADDI");
        // SLLI
        check_ctrl(`OPCODE_I_TYPE, 3'b001, 7'h00, 1'b1, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_SLL, "I-Type SLLI");
        // SLTI
        check_ctrl(`OPCODE_I_TYPE, 3'b010, 7'h00, 1'b1, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_SLT, "I-Type SLTI");
        // SLTIU
        check_ctrl(`OPCODE_I_TYPE, 3'b011, 7'h00, 1'b1, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_SLTU, "I-Type SLTIU");
        // XORI
        check_ctrl(`OPCODE_I_TYPE, 3'b100, 7'h00, 1'b1, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_XOR, "I-Type XORI");
        // SRLI
        check_ctrl(`OPCODE_I_TYPE, 3'b101, 7'h00, 1'b1, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_SRL, "I-Type SRLI");
        // SRAI
        check_ctrl(`OPCODE_I_TYPE, 3'b101, 7'h20, 1'b1, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_SRA, "I-Type SRAI");
        // ORI
        check_ctrl(`OPCODE_I_TYPE, 3'b110, 7'h00, 1'b1, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_OR, "I-Type ORI");
        // ANDI
        check_ctrl(`OPCODE_I_TYPE, 3'b111, 7'h00, 1'b1, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_AND, "I-Type ANDI");

        // ==========================================
        // 3. I-Type Load operations (Opcode: 7'b0000011)
        // ==========================================
        $display("-- 3. Load checks");
        check_ctrl(`OPCODE_LOAD, 3'b010, 7'h00, 1'b1, 1'b1, 2'b01, 1'b0, 1'b1, 1'b0, 1'b0, `ALU_ADD, "I-Type LW");

        // ==========================================
        // 4. S-Type Store operations (Opcode: 7'b0100011)
        // ==========================================
        $display("-- 4. Store checks");
        check_ctrl(`OPCODE_STORE, 3'b010, 7'h00, 1'b0, 1'b1, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0, `ALU_ADD, "S-Type SW");

        // ==========================================
        // 5. B-Type Branch instructions (Opcode: 7'b1100011)
        // ==========================================
        $display("-- 5. Branch checks");
        // BEQ
        check_ctrl(`OPCODE_BRANCH, 3'b000, 7'h00, 1'b0, 1'b0, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, `ALU_SUB, "B-Type BEQ");
        // BNE
        check_ctrl(`OPCODE_BRANCH, 3'b001, 7'h00, 1'b0, 1'b0, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, `ALU_SUB, "B-Type BNE");
        // BLT
        check_ctrl(`OPCODE_BRANCH, 3'b100, 7'h00, 1'b0, 1'b0, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, `ALU_SLT, "B-Type BLT");
        // BGE
        check_ctrl(`OPCODE_BRANCH, 3'b101, 7'h00, 1'b0, 1'b0, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, `ALU_SLT, "B-Type BGE");
        // BLTU
        check_ctrl(`OPCODE_BRANCH, 3'b110, 7'h00, 1'b0, 1'b0, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, `ALU_SLTU, "B-Type BLTU");
        // BGEU
        check_ctrl(`OPCODE_BRANCH, 3'b111, 7'h00, 1'b0, 1'b0, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, `ALU_SLTU, "B-Type BGEU");

        // ==========================================
        // 6. J-Type JAL jump (Opcode: 7'b1101111)
        // ==========================================
        $display("-- 6. JAL checks");
        check_ctrl(`OPCODE_JAL, 3'b000, 7'h00, 1'b1, 1'b0, 2'b10, 1'b0, 1'b0, 1'b0, 1'b1, `ALU_ADD, "J-Type JAL");

        // ==========================================
        // 7. I-Type JALR jump (Opcode: 7'b1100111)
        // ==========================================
        $display("-- 7. JALR checks");
        check_ctrl(`OPCODE_JALR, 3'b000, 7'h00, 1'b1, 1'b1, 2'b10, 1'b0, 1'b0, 1'b0, 1'b1, `ALU_ADD, "I-Type JALR");

        // ==========================================
        // 8. U-Type LUI loading (Opcode: 7'b0110111)
        // ==========================================
        $display("-- 8. LUI checks");
        check_ctrl(`OPCODE_LUI, 3'b000, 7'h00, 1'b1, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_LUI, "U-Type LUI");

        check_ctrl(`OPCODE_AUIPC, 3'b000, 7'h00, 1'b1, 1'b0, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_ADD, "U-Type AUIPC");

        // ==========================================
        // 9. Sync & System checks
        // ==========================================
        $display("-- 9. FENCE and SYSTEM checks");
        check_ctrl(`OPCODE_MISC_MEM, 3'b000, 7'h00, 1'b0, 1'b0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_ADD, "I-Type FENCE (NOP)");
        if (tb_illegal_op !== 1'b0) begin
            fail_cnt = fail_cnt + 1;
            $display("FAIL: FENCE should not be illegal_op");
        end

        check_ctrl(`OPCODE_SYSTEM, 3'b000, 7'h00, 1'b0, 1'b0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_ADD, "I-Type SYSTEM");
        if (tb_illegal_op !== 1'b1) begin
            fail_cnt = fail_cnt + 1;
            $display("FAIL: SYSTEM should be illegal_op");
        end

        // ==========================================
        // 10. Invalid/Undefined Opcode (Opcode: 7'b1111111)
        // ==========================================
        $display("-- 10. Invalid opcode checks");
        check_ctrl(7'b1111111, 3'b000, 7'h00, 1'b0, 1'b0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, `ALU_ADD, "Invalid Opcode 7'b1111111");
        if (tb_illegal_op !== 1'b1) begin
            fail_cnt = fail_cnt + 1;
            $display("FAIL: Invalid opcode should be illegal_op");
        end

        $display("-------------------------------------------");
        display_result();
        $display("-------------------------------------------");

        $finish;
    end

endmodule
`default_nettype wire
