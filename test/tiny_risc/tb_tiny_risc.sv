`default_nettype none
module tb_tiny_risc;
    logic clk = 1'b0, rst_n = 1'b1;
    logic im_req_valid, im_req_ready, im_rsp_valid, im_rsp_error;
    logic [31:0] im_req_addr, im_rsp_inst;
    logic dm_req_valid, dm_req_ready, dm_req_write;
    logic dm_rsp_valid, dm_rsp_error;
    logic [31:0] dm_req_addr, dm_req_wdata, dm_rsp_rdata;
    logic [3:0] dm_req_wstrb;
    logic fault;
    integer store_accepts = 0, load_accepts = 0;
    logic awaiting_data = 1'b0;
    logic [31:0] pending_pc = '0;

    tiny_risc dut (
        .clk(clk), .rst_n(rst_n), .hart_enable(1'b1), .fault(fault),
        .imem_req_valid(im_req_valid), .imem_req_ready(im_req_ready),
        .imem_req_addr(im_req_addr), .imem_rsp_valid(im_rsp_valid),
        .imem_rsp_inst(im_rsp_inst), .imem_rsp_error(im_rsp_error),
        .dmem_req_valid(dm_req_valid), .dmem_req_ready(dm_req_ready),
        .dmem_req_addr(dm_req_addr), .dmem_req_write(dm_req_write),
        .dmem_req_wdata(dm_req_wdata), .dmem_req_wstrb(dm_req_wstrb),
        .dmem_rsp_valid(dm_rsp_valid), .dmem_rsp_rdata(dm_rsp_rdata),
        .dmem_rsp_error(dm_rsp_error)
    );
    rv32_shared_memory #(.WORDS(64), .LATENCY(3), .READ_ONLY(1'b1)) i_imem (
        .clk(clk), .rst_n(rst_n), .req_valid(im_req_valid),
        .req_ready(im_req_ready), .req_addr(im_req_addr),
        .req_write(1'b0), .req_wdata(32'b0), .req_wstrb(4'b0),
        .rsp_valid(im_rsp_valid), .rsp_rdata(im_rsp_inst),
        .rsp_error(im_rsp_error)
    );
    rv32_shared_memory #(.WORDS(64), .LATENCY(4)) i_dmem (
        .clk(clk), .rst_n(rst_n), .req_valid(dm_req_valid),
        .req_ready(dm_req_ready), .req_addr(dm_req_addr),
        .req_write(dm_req_write), .req_wdata(dm_req_wdata),
        .req_wstrb(dm_req_wstrb), .rsp_valid(dm_rsp_valid),
        .rsp_rdata(dm_rsp_rdata), .rsp_error(dm_rsp_error)
    );
    always #5 clk = ~clk;
    always @(posedge clk) if (dm_req_valid && dm_req_ready) begin
        if (dm_req_write) store_accepts = store_accepts + 1;
        else load_accepts = load_accepts + 1;
    end
    always @(posedge clk) if (rst_n) begin
        if (awaiting_data && im_req_addr !== pending_pc)
            $fatal(1, "PC advanced before data response");
        if (dm_req_valid && dm_req_ready) begin
            awaiting_data <= 1'b1;
            pending_pc <= im_req_addr;
        end else if (dm_rsp_valid) awaiting_data <= 1'b0;
    end

    initial begin
        #1 rst_n = 1'b0;
        #1;
        i_imem.words[0] = 32'hfff00093; // addi x1, x0, -1
        i_imem.words[1] = 32'h001000a3; // sb x1, 1(x0)
        i_imem.words[2] = 32'h00104103; // lbu x2, 1(x0)
        i_imem.words[3] = 32'h00000197; // auipc x3, 0
        i_imem.words[4] = 32'h0080006f; // jal x0, +8
        i_imem.words[5] = 32'h00100213; // skipped
        i_imem.words[6] = 32'h00200213; // addi x4, x0, 2
        i_imem.words[7] = 32'h00420463; // beq x4, x4, +8
        i_imem.words[8] = 32'h00100293; // skipped
        i_imem.words[9] = 32'h00000013; // nop
        #1 rst_n = 1'b1;
        wait (im_req_addr == 32'd36);
        #1;
        if (fault) $fatal(1, "hart faulted");
        if (i_dmem.words[0] !== 32'h0000ff00) $fatal(1, "SB byte lane failed");
        if (dut.i_regfile.register_array[2] !== 32'd255) $fatal(1, "LBU failed");
        if (dut.i_regfile.register_array[3] !== 32'd12) $fatal(1, "AUIPC failed");
        if (dut.i_regfile.register_array[4] !== 32'd2) $fatal(1, "JAL failed");
        if (dut.i_regfile.register_array[5] !== 32'd0) $fatal(1, "BEQ failed");
        if (store_accepts !== 1 || load_accepts !== 1)
            $fatal(1, "memory request duplicated");
        $display("Pass: stalled core, one SB and one LBU, AUIPC/JAL/BEQ");
        $finish;
    end
    initial begin
        #3000;
        $fatal(1, "core timeout");
    end
endmodule
`default_nettype wire
