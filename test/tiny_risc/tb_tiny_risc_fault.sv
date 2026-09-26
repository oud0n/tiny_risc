`default_nettype none
module tb_tiny_risc_fault;
    logic clk = 1'b0, rst_n = 1'b1;
    logic [0:0] hart_fault;
    integer dmem_accepts = 0;
    tiny_risc_soc #(
        .N_HARTS(1), .IMEM_WORDS(16), .DMEM_WORDS(16)
    ) soc (
        .clk(clk), .rst_n(rst_n),
        .hart_enable(1'b1), .hart_fault(hart_fault)
    );
    always #5 clk = ~clk;
    always @(posedge clk)
        if (soc.d_req_valid[0] && soc.d_req_ready[0]) dmem_accepts++;
    initial begin
        #1 rst_n = 1'b0;
        #1;
        soc.i_imem.words[0] = 32'h00100093; // addi x1, x0, 1
        soc.i_imem.words[1] = 32'h001011a3; // sh x1, 3(x0): misaligned
        #1 rst_n = 1'b1;
        wait (hart_fault[0]);
        #1;
        if (dmem_accepts != 0) $fatal(1, "misaligned store was issued");
        if (soc.i_dmem.words[0] !== 32'b0)
            $fatal(1, "misaligned store changed memory");
        if (soc.g_hart[0].i_core.program_counter !== 32'd4)
            $fatal(1, "faulting PC was not retained");
        rst_n = 1'b0;
        #1;
        soc.i_imem.words[0] = 32'h002000ef; // jal x1, +2: bad RV32I target
        #1 rst_n = 1'b1;
        wait (hart_fault[0]);
        #1;
        if (soc.g_hart[0].i_core.program_counter !== 32'd0)
            $fatal(1, "misaligned JAL advanced PC");
        if (soc.g_hart[0].i_core.i_regfile.register_array[1] !== 32'd0)
            $fatal(1, "misaligned JAL wrote link register");
        $display("Pass: misaligned SH and JAL fault before side effects");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "fault timeout");
    end
endmodule
`default_nettype wire
