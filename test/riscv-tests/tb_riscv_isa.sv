`default_nettype none

module tb_riscv_isa;
    parameter string HEX_FILE = "";
    parameter integer MEM_WORDS = 8192; // 32KB
    parameter integer MAX_CYCLES = 100000;

    logic clk = 1'b0, rst_n = 1'b1;
    logic fault;

    // Core ports
    logic i_req_valid, i_req_ready, i_rsp_valid, i_rsp_error;
    logic [31:0] i_req_addr, i_rsp_inst;
    logic d_req_valid, d_req_ready, d_req_write;
    logic d_rsp_valid, d_rsp_error;
    logic [31:0] d_req_addr, d_req_wdata, d_rsp_rdata;
    logic [3:0] d_req_wstrb;

    // Arbiter inputs (Port 0: Instruction, Port 1: Data)
    logic [1:0] arb_req_valid, arb_req_ready;
    logic [1:0][31:0] arb_req_addr, arb_req_wdata;
    logic [1:0] arb_req_write;
    logic [1:0][3:0] arb_req_wstrb;
    logic [1:0] arb_rsp_valid, arb_rsp_error;
    logic [1:0][31:0] arb_rsp_rdata;

    // Unified memory ports
    logic mem_req_valid, mem_req_ready, mem_req_write;
    logic mem_rsp_valid, mem_rsp_error;
    logic [31:0] mem_req_addr, mem_req_wdata, mem_rsp_data;
    logic [3:0] mem_req_wstrb;

    assign arb_req_valid[0] = i_req_valid;
    assign arb_req_addr[0]  = i_req_addr;
    assign arb_req_write[0] = 1'b0;
    assign arb_req_wdata[0] = '0;
    assign arb_req_wstrb[0] = '0;
    assign i_req_ready      = arb_req_ready[0];
    assign i_rsp_valid      = arb_rsp_valid[0];
    assign i_rsp_inst       = arb_rsp_rdata[0];
    assign i_rsp_error      = arb_rsp_error[0];

    assign arb_req_valid[1] = d_req_valid;
    assign arb_req_addr[1]  = d_req_addr;
    assign arb_req_write[1] = d_req_write;
    assign arb_req_wdata[1] = d_req_wdata;
    assign arb_req_wstrb[1] = d_req_wstrb;
    assign d_req_ready      = arb_req_ready[1];
    assign d_rsp_valid      = arb_rsp_valid[1];
    assign d_rsp_rdata      = arb_rsp_rdata[1];
    assign d_rsp_error      = arb_rsp_error[1];

    always #5 clk = ~clk;

    tiny_risc #(.RESET_VECTOR(32'h00000000)) u_core (
        .clk(clk), .rst_n(rst_n), .hart_enable(1'b1),
        .fault(fault),
        .imem_req_valid(i_req_valid), .imem_req_ready(i_req_ready),
        .imem_req_addr(i_req_addr), .imem_rsp_valid(i_rsp_valid),
        .imem_rsp_inst(i_rsp_inst), .imem_rsp_error(i_rsp_error),
        .dmem_req_valid(d_req_valid), .dmem_req_ready(d_req_ready),
        .dmem_req_addr(d_req_addr), .dmem_req_write(d_req_write),
        .dmem_req_wdata(d_req_wdata), .dmem_req_wstrb(d_req_wstrb),
        .dmem_rsp_valid(d_rsp_valid), .dmem_rsp_rdata(d_rsp_rdata),
        .dmem_rsp_error(d_rsp_error)
    );

    rv32_mem_arbiter #(.N_HARTS(2)) u_arbiter (
        .clk(clk), .rst_n(rst_n),
        .in_req_valid(arb_req_valid), .in_req_ready(arb_req_ready),
        .in_req_addr(arb_req_addr), .in_req_write(arb_req_write),
        .in_req_wdata(arb_req_wdata), .in_req_wstrb(arb_req_wstrb),
        .in_rsp_valid(arb_rsp_valid), .in_rsp_rdata(arb_rsp_rdata),
        .in_rsp_error(arb_rsp_error),
        .out_req_valid(mem_req_valid), .out_req_ready(mem_req_ready),
        .out_req_addr(mem_req_addr), .out_req_write(mem_req_write),
        .out_req_wdata(mem_req_wdata), .out_req_wstrb(mem_req_wstrb),
        .out_rsp_valid(mem_rsp_valid), .out_rsp_rdata(mem_rsp_data),
        .out_rsp_error(mem_rsp_error)
    );

    rv32_shared_memory #(
        .WORDS(MEM_WORDS), .LATENCY(1),
        .READ_ONLY(1'b0), .INIT_FILE("")
    ) u_mem (
        .clk(clk), .rst_n(rst_n),
        .req_valid(mem_req_valid), .req_ready(mem_req_ready),
        .req_addr(mem_req_addr), .req_write(mem_req_write),
        .req_wdata(mem_req_wdata), .req_wstrb(mem_req_wstrb),
        .rsp_valid(mem_rsp_valid), .rsp_rdata(mem_rsp_data),
        .rsp_error(mem_rsp_error)
    );

    integer cycle = 0;
    logic [31:0] gp_val;
    logic [31:0] last_pc;
    integer same_pc_cnt = 0;
    string hex_file;

    initial begin
        if (!$value$plusargs("HEX_FILE=%s", hex_file)) begin
            hex_file = HEX_FILE;
        end
        if (hex_file != "") begin
            $readmemh(hex_file, u_mem.words);
        end
        #1 rst_n = 1'b0;
        #2 rst_n = 1'b1;
    end

    always @(posedge clk) begin
        if (rst_n) begin
            cycle <= cycle + 1;

            if (fault) begin
                $display("ERROR: Core faulted at PC 0x%08x! State=%d", u_core.program_counter, u_core.state);
                $fatal(1);
            end

            // Detect self-loop (j .) signifying end of test
            if (u_core.state == 3'd2 && !(u_core.mem_read || u_core.mem_write)) begin
                if (u_core.next_pc == u_core.program_counter) begin
                    same_pc_cnt <= same_pc_cnt + 1;
                end
            end

            if (same_pc_cnt >= 2) begin
                gp_val = u_core.i_regfile.register_array[3]; // x3 is gp
                if (gp_val == 32'd1) begin
                    $display("PASS: ISA test passed in %0d cycles (gp=1)", cycle);
                    $finish;
                end else begin
                    $display("FAIL: ISA test failed at subtest #%0d (gp=0x%08x) at PC 0x%08x", (gp_val >> 1), gp_val, u_core.program_counter);
                    $fatal(1);
                end
            end

            if (cycle >= MAX_CYCLES) begin
                $display("TIMEOUT: Simulation exceeded %0d cycles at PC 0x%08x", MAX_CYCLES, u_core.program_counter);
                $fatal(1);
            end
        end
    end
endmodule

`default_nettype wire
