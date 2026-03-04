`default_nettype none
`include "riscv32.svh"

module tb;

    // Declare signals to connect to the Device Under Test (DUT)
    logic [`DATA_WIDTH-1:0] a_in;
    logic [`DATA_WIDTH-1:0] b_in;
    logic [3:0] alu_control_code_in;
    wire [`DATA_WIDTH-1:0] out_wire;
    wire is_zero_wire;

    // Instantiate the ALU module
    alu dut (
        .a(a_in),
        .b(b_in),
        .alu_control_code(alu_control_code_in),
        .out(out_wire),
        .is_zero(is_zero_wire)
    );

    initial begin
        // Set up for waveform dumping
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb);
        $display("---------------------------------");
        $display("Starting ALU Testbench");
        $display("---------------------------------");

        // Run all test cases using a helper task
        test_case(`ALU_ADD, 32'd10, 32'd5, 32'd15, 0);  // Add
        test_case(`ALU_SUB, 32'd20, 32'd8, 32'd12, 0);  // Subtract
        test_case(`ALU_SUB, 32'd10, 32'd10, 32'd0, 1);  // Subtract to check zero flag

        test_case(`ALU_AND, 32'hFFFF_0000, 32'hFFFF_FFFF, 32'hFFFF_0000, 0);  // AND
        test_case(`ALU_OR, 32'hFFFF_0000, 32'h0000_FFFF, 32'hFFFF_FFFF, 0);  // OR
        test_case(`ALU_XOR, 32'hFFFF_FFFF, 32'hF0F0_F0F0, 32'h0F0F_0F0F, 0);  // XOR

        test_case(`ALU_SLL, 32'h1, 32'd4, 32'h10, 0);  // Shift Left Logical
        test_case(`ALU_SRL, 32'h8000_0000, 32'd1, 32'h4000_0000, 0);  // Shift Right Logical
        test_case(`ALU_SRA, 32'h8000_0000, 32'd1, 32'hC000_0000, 0);  // Shift Right Arithmetic (Signed)

        test_case(`ALU_SLT, 32'hFFFFFFFF, 32'd1, 32'h1, 0);  // Set Less Than (Signed)
        test_case(`ALU_SLT, 32'd1, 32'd1, 32'h0, 1);  // Set Less Than (Signed)
        test_case(`ALU_SLTU, 32'hFFFF_FFFF, 32'h0000_0000, 32'h0,
                  1);  // Set Less Than Unsigned (FFFF_FFFF is not less than 0)

        // --- Additional Test Cases ---

        // Zero Flag and Zero Inputs
        test_case(`ALU_ADD, 32'h0, 32'h0, 32'h0, 1);
        test_case(`ALU_SUB, 32'h0, 32'h0, 32'h0, 1);
        test_case(`ALU_AND, 32'h0, 32'hFFFF_FFFF, 32'h0, 1);
        test_case(`ALU_OR, 32'h0, 32'h0, 32'h0, 1);

        // Negative Numbers and Edge Cases
        test_case(`ALU_ADD, 32'hFFFFFFF6, 32'd5, 32'hFFFFFFFB, 0);
        test_case(`ALU_SUB, 32'hFFFFFFFB, 32'd5, 32'hFFFFFFF6, 0);
        test_case(`ALU_ADD, 32'h7FFF_FFFF, 32'h1, 32'h8000_0000, 0);  // Overflow test
        test_case(`ALU_SUB, 32'h8000_0000, 32'h1, 32'h7FFF_FFFF, 0);  // Underflow test

        // Shift Operations
        test_case(`ALU_SLL, 32'hF, 32'd31, 32'h8000_0000, 0);
        test_case(`ALU_SRL, 32'hF0000000, 32'd4, 32'h0F000000, 0);
        test_case(`ALU_SRA, 32'hF0000000, 32'd4, 32'hFF000000, 0);
        test_case(`ALU_SLL, 32'h1, 32'd0, 32'h1, 0);  // Shift by 0
        test_case(`ALU_SLL, 32'h1, 32'd32, 32'h1,
                  0);  // Shift by 32 (should be same as 0 on some archs, but here it's full width)

        // SLT/SLTU with negative numbers
        test_case(`ALU_SLT, 32'hFFFFFFF6, 32'hFFFFFFFB, 32'h1, 0);
        test_case(`ALU_SLTU, 32'hFFFFFFFF, 32'd1, 32'h0, 1);  // -1 (0xFFFFFFFF) is a large unsigned number

        $display("---------------------------------");
        $display("All tests completed.");
        $finish;
    end

    // A helper task to simplify the testbench
    task automatic test_case;
        input [3:0] alu_ctrl;
        input [`DATA_WIDTH-1:0] a_val;
        input [`DATA_WIDTH-1:0] b_val;
        input [`DATA_WIDTH-1:0] expected_out;
        input logic expected_zero;

        begin
            // Apply inputs
            a_in = a_val;
            b_in = b_val;
            alu_control_code_in = alu_ctrl;

            // Wait for combinational logic to settle
            #10;

            // Display results and check for pass/fail
            $display("Running Test: CTRL=%b, A=%h, B=%h", alu_ctrl, a_val, b_val);
            if (out_wire === expected_out && is_zero_wire === expected_zero) begin
                $display("PASS: out=%h, zero=%b", out_wire, is_zero_wire);
            end else begin
                $error("FAIL: out=%h (Exp: %h), zero=%b (Exp: %b)", out_wire, expected_out, is_zero_wire,
                       expected_zero);
            end
        end
    endtask
endmodule

`default_nettype wire
