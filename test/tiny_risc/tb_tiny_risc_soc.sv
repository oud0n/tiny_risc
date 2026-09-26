`default_nettype none
module tb_tiny_risc_soc;
    logic clk = 1'b0, rst_n = 1'b1;
    logic [1:0] hart_fault;
    integer im_count0 = 0, im_count1 = 0;
    integer dm_count0 = 0, dm_count1 = 0;
    integer imem_contention = 0;

    tiny_risc_soc #(
        .N_HARTS(2), .HART_STRIDE_BYTES(64),
        .IMEM_WORDS(64), .DMEM_WORDS(64), .MEMORY_LATENCY(3)
    ) soc (
        .clk(clk), .rst_n(rst_n),
        .hart_enable(2'b11), .hart_fault(hart_fault)
    );
    always #5 clk = ~clk;
    always @(posedge clk) begin
        if (soc.i_req_valid == 2'b11 && soc.i_req_ready != 2'b11)
            imem_contention++;
        if (soc.i_req_valid[0] && soc.i_req_ready[0]) im_count0++;
        if (soc.i_req_valid[1] && soc.i_req_ready[1]) im_count1++;
        if (soc.d_req_valid[0] && soc.d_req_ready[0]) dm_count0++;
        if (soc.d_req_valid[1] && soc.d_req_ready[1]) dm_count1++;
    end

    initial begin
        #1 rst_n = 1'b0;
        #1;
        soc.i_imem.words[0] = 32'h01100093;  // hart 0: addi x1, x0, 0x11
        soc.i_imem.words[1] = 32'h00100023;  // sb x1, 0(x0)
        soc.i_imem.words[2] = 32'h00004103;  // lbu x2, 0(x0)
        soc.i_imem.words[3] = 32'h0000006f;  // jal x0, 0
        soc.i_imem.words[16] = 32'h02200093; // hart 1: addi x1, x0, 0x22
        soc.i_imem.words[17] = 32'h001000a3; // sb x1, 1(x0)
        soc.i_imem.words[18] = 32'h00104103; // lbu x2, 1(x0)
        soc.i_imem.words[19] = 32'h0000006f; // jal x0, 0
        #1 rst_n = 1'b1;
        wait (soc.g_hart[0].i_core.program_counter == 32'd12 &&
              soc.g_hart[1].i_core.program_counter == 32'd76);
        #1;
        if (hart_fault !== 2'b00) $fatal(1, "hart fault");
        if (soc.i_dmem.words[0] !== 32'h00002211)
            $fatal(1, "shared byte writes lost");
        if (soc.g_hart[0].i_core.i_regfile.register_array[2] !== 32'h11)
            $fatal(1, "hart 0 response misrouted");
        if (soc.g_hart[1].i_core.i_regfile.register_array[2] !== 32'h22)
            $fatal(1, "hart 1 response misrouted");
        if (dm_count0 !== 2 || dm_count1 !== 2)
            $fatal(1, "data request duplicated or missing");
        if (im_count0 < 3 || im_count1 < 3)
            $fatal(1, "instruction arbitration starved a hart");
        if (imem_contention == 0)
            $fatal(1, "test never exercised instruction contention");
        $display("Pass: two harts, shared byte lanes, response routing");
        $finish;
    end
    initial begin
        #3000;
        $fatal(1, "two-hart timeout");
    end
endmodule
`default_nettype wire
