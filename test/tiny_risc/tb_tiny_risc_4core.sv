`default_nettype none

module tb_tiny_risc_4core;
    logic clk = 1'b0, rst_n = 1'b1;
    logic [3:0] hart_fault;
    integer im_count0 = 0, im_count1 = 0, im_count2 = 0, im_count3 = 0;
    integer dm_count0 = 0, dm_count1 = 0, dm_count2 = 0, dm_count3 = 0;
    integer imem_contention = 0, dmem_contention = 0;

    tiny_risc_soc #(
        .N_HARTS(4),
        .HART_STRIDE_BYTES(128),
        .IMEM_WORDS(1024),
        .DMEM_WORDS(1024),
        .MEMORY_LATENCY(2)
    ) soc (
        .clk(clk),
        .rst_n(rst_n),
        .hart_enable(4'b1111),
        .hart_fault(hart_fault)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        // Track instruction contention (more than 1 request active)
        if ((soc.i_req_valid[0] + soc.i_req_valid[1] + soc.i_req_valid[2] + soc.i_req_valid[3]) > 1)
            imem_contention++;

        // Track data contention
        if ((soc.d_req_valid[0] + soc.d_req_valid[1] + soc.d_req_valid[2] + soc.d_req_valid[3]) > 1)
            dmem_contention++;

        if (soc.i_req_valid[0] && soc.i_req_ready[0]) im_count0++;
        if (soc.i_req_valid[1] && soc.i_req_ready[1]) im_count1++;
        if (soc.i_req_valid[2] && soc.i_req_ready[2]) im_count2++;
        if (soc.i_req_valid[3] && soc.i_req_ready[3]) im_count3++;

        if (soc.d_req_valid[0] && soc.d_req_ready[0]) dm_count0++;
        if (soc.d_req_valid[1] && soc.d_req_ready[1]) dm_count1++;
        if (soc.d_req_valid[2] && soc.d_req_ready[2]) dm_count2++;
        if (soc.d_req_valid[3] && soc.d_req_ready[3]) dm_count3++;
    end

    initial begin
        #1 rst_n = 1'b0;
        #1;

        // ========================================================
        // Hart 0 (PC = 0, words 0..): R-type operations + Store
        // ========================================================
        // 0: addi x1, x0, 10
        soc.i_imem.words[0]  = 32'h00a00093;
        // 4: addi x2, x0, 3
        soc.i_imem.words[1]  = 32'h00300113;
        // 8: add  x3, x1, x2  (13 = 0x0D)
        soc.i_imem.words[2]  = 32'h002081b3;
        // 12: sub x4, x1, x2  (7)
        soc.i_imem.words[3]  = 32'h40208233;
        // 16: sll x5, x1, x2  (80)
        soc.i_imem.words[4]  = 32'h002092b3;
        // 20: slt x6, x2, x1  (1)
        soc.i_imem.words[5]  = 32'h00112333;
        // 24: xor x7, x1, x2  (9)
        soc.i_imem.words[6]  = 32'h0020c3b3;
        // 28: or  x8, x1, x2  (11)
        soc.i_imem.words[7]  = 32'h0020e433;
        // 32: and x9, x1, x2  (2)
        soc.i_imem.words[8]  = 32'h0020f4b3;
        // 36: sb  x3, 0(x0)   (store 0x0D to byte 0)
        soc.i_imem.words[9]  = 32'h00300023;
        // 40: lbu x10, 0(x0)
        soc.i_imem.words[10] = 32'h00004503;
        // 44: jal x0, 0       (loop)
        soc.i_imem.words[11] = 32'h0000006f;

        // ========================================================
        // Hart 1 (PC = 128 / word 32..): I-type ALU + Store
        // ========================================================
        // 128 (word 32): addi  x1, x0, 20
        soc.i_imem.words[32] = 32'h01400093;
        // 132 (word 33): slli  x2, x1, 2   (80)
        soc.i_imem.words[33] = 32'h00209113;
        // 136 (word 34): srai  x3, x2, 1   (40)
        soc.i_imem.words[34] = 32'h40115193;
        // 140 (word 35): xori  x4, x1, 15  (20 ^ 15 = 27 = 0x1B)
        soc.i_imem.words[35] = 32'h00f0c213;
        // 144 (word 36): ori   x5, x1, 7   (23)
        soc.i_imem.words[36] = 32'h0070e293;
        // 148 (word 37): andi  x6, x1, 12  (4)
        soc.i_imem.words[37] = 32'h00c0f313;
        // 152 (word 38): sltiu x7, x1, 25  (1)
        soc.i_imem.words[38] = 32'h0190b393;
        // 156 (word 39): sb    x4, 1(x0)   (store 0x1B to byte 1)
        soc.i_imem.words[39] = 32'h004000a3;
        // 160 (word 40): lbu   x10, 1(x0)
        soc.i_imem.words[40] = 32'h00104503;
        // 164: jal   x0, 0     (loop)
        soc.i_imem.words[41] = 32'h0000006f;

        // ========================================================
        // Hart 2 (PC = 256 / word 64..): Branch operations + Store
        // ========================================================
        // 256 (word 64): addi x1, x0, 5
        soc.i_imem.words[64] = 32'h00500093;
        // 260 (word 65): addi x2, x0, 5
        soc.i_imem.words[65] = 32'h00500113;
        // 264 (word 66): addi x3, x0, 9
        soc.i_imem.words[66] = 32'h00900193;
        // 268 (word 67): beq  x1, x2, +8 (to 276, skip word 68)
        soc.i_imem.words[67] = 32'h00208463;
        // 272 (word 68): addi x4, x0, 99 (skipped)
        soc.i_imem.words[68] = 32'h06300213;
        // 276 (word 69): addi x4, x0, 33  (0x21)
        soc.i_imem.words[69] = 32'h02100213;
        // 280 (word 70): bne  x1, x3, +8 (to 288, skip word 71)
        soc.i_imem.words[70] = 32'h00309463;
        // 284 (word 71): addi x4, x0, 99 (skipped)
        soc.i_imem.words[71] = 32'h06300213;
        // 288 (word 72): addi x5, x4, 1   (34 = 0x22)
        soc.i_imem.words[72] = 32'h00120293;
        // 292 (word 73): sb   x5, 2(x0)   (store 0x22 to byte 2)
        soc.i_imem.words[73] = 32'h00500123;
        // 296 (word 74): lbu  x10, 2(x0)
        soc.i_imem.words[74] = 32'h00204503;
        // 300 (word 75): jal  x0, 0       (loop)
        soc.i_imem.words[75] = 32'h0000006f;

        // ========================================================
        // Hart 3 (PC = 384 / word 96..): LUI, AUIPC, FENCE, Sync Poll & Load
        // ========================================================
        // 384 (word 96): lui   x1, 20      (0x00014000)
        soc.i_imem.words[96]  = 32'h000140b7;
        // 388 (word 97): auipc x2, 0       (PC = 388)
        soc.i_imem.words[97]  = 32'h00000117;
        // 392 (word 98): fence             (NOP)
        soc.i_imem.words[98]  = 32'h0000000f;
        // 396 (word 99): addi  x3, x0, 85  (85 = 0x55)
        soc.i_imem.words[99]  = 32'h05500193;
        // 400 (word 100): sb   x3, 3(x0)   (store 0x55 to byte 3)
        soc.i_imem.words[100] = 32'h003001a3;
        // 404 (word 101): lbu  x6, 0(x0)   (poll Hart 0 byte)
        soc.i_imem.words[101] = 32'h00004303;
        // 408 (word 102): beq  x6, x0, -4  (if 0, retry)
        soc.i_imem.words[102] = 32'hfe030ee3;
        // 412 (word 103): lbu  x7, 1(x0)   (poll Hart 1 byte)
        soc.i_imem.words[103] = 32'h00104383;
        // 416 (word 104): beq  x7, x0, -4  (if 0, retry)
        soc.i_imem.words[104] = 32'hfe038ee3;
        // 420 (word 105): lbu  x8, 2(x0)   (poll Hart 2 byte)
        soc.i_imem.words[105] = 32'h00204403;
        // 424 (word 106): beq  x8, x0, -4  (if 0, retry)
        soc.i_imem.words[106] = 32'hfe040ee3;
        // 428 (word 107): lw   x4, 0(x0)   (load composite word: 0x55221B0D)
        soc.i_imem.words[107] = 32'h00002203;
        // 432 (word 108): jal  x0, 0       (loop)
        soc.i_imem.words[108] = 32'h0000006f;

        #1 rst_n = 1'b1;

        // Wait until all 4 harts reach their final loop PC
        wait (soc.g_hart[0].i_core.program_counter == 32'd44 &&
              soc.g_hart[1].i_core.program_counter == 32'd164 &&
              soc.g_hart[2].i_core.program_counter == 32'd300 &&
              soc.g_hart[3].i_core.program_counter == 32'd432);

        #1;

        // Verification checks
        if (hart_fault !== 4'b0000)
            $fatal(1, "Fault detected on harts: %b", hart_fault);

        // Check shared memory word 0:
        // byte 0 = 0x0D (from hart 0)
        // byte 1 = 0x1B (from hart 1)
        // byte 2 = 0x22 (from hart 2)
        // byte 3 = 0x55 (from hart 3)
        // Expected word 0: 32'h55221B0D
        if (soc.i_dmem.words[0] !== 32'h55221b0d)
            $fatal(1, "Shared memory composite write failed: expected 0x55221B0D, got 0x%08x", soc.i_dmem.words[0]);

        // Check Hart 0 registers
        if (soc.g_hart[0].i_core.i_regfile.register_array[3] !== 32'd13 ||
            soc.g_hart[0].i_core.i_regfile.register_array[4] !== 32'd7 ||
            soc.g_hart[0].i_core.i_regfile.register_array[5] !== 32'd80 ||
            soc.g_hart[0].i_core.i_regfile.register_array[10] !== 32'h0d)
            $fatal(1, "Hart 0 register verification failed");

        // Check Hart 1 registers
        if (soc.g_hart[1].i_core.i_regfile.register_array[4] !== 32'd27 ||
            soc.g_hart[1].i_core.i_regfile.register_array[10] !== 32'h1b)
            $fatal(1, "Hart 1 register verification failed");

        // Check Hart 2 registers
        if (soc.g_hart[2].i_core.i_regfile.register_array[4] !== 32'd33 ||
            soc.g_hart[2].i_core.i_regfile.register_array[5] !== 32'd34 ||
            soc.g_hart[2].i_core.i_regfile.register_array[10] !== 32'h22)
            $fatal(1, "Hart 2 register verification failed");

        // Check Hart 3 registers
        if (soc.g_hart[3].i_core.i_regfile.register_array[1] !== 32'h00014000 ||
            soc.g_hart[3].i_core.i_regfile.register_array[2] !== 32'd388 ||
            soc.g_hart[3].i_core.i_regfile.register_array[4] !== 32'h55221b0d)
            $fatal(1, "Hart 3 register verification failed: x4 got 0x%08x", soc.g_hart[3].i_core.i_regfile.register_array[4]);

        // Verify arbitration contention occurred
        if (imem_contention == 0)
            $fatal(1, "No instruction contention observed among 4 harts");
        if (dm_count0 == 0 || dm_count1 == 0 || dm_count2 == 0 || dm_count3 == 0)
            $fatal(1, "Not all harts performed data access");

        $display("=================================================");
        $display("Pass: 4 harts RV32I multicore shared memory execution");
        $display("  Instruction contention cycles: %d", imem_contention);
        $display("  Data contention cycles:        %d", dmem_contention);
        $display("  Shared Word 0 composite:       0x%08x", soc.i_dmem.words[0]);
        $display("  Hart 3 loaded word:            0x%08x", soc.g_hart[3].i_core.i_regfile.register_array[4]);
        $display("=================================================");
        $finish;
    end

    initial begin
        #15000;
        $fatal(1, "4-hart simulation timeout! PC0=%d PC1=%d PC2=%d PC3=%d Faults=%b",
               soc.g_hart[0].i_core.program_counter,
               soc.g_hart[1].i_core.program_counter,
               soc.g_hart[2].i_core.program_counter,
               soc.g_hart[3].i_core.program_counter,
               hart_fault);
    end
endmodule

`default_nettype wire
