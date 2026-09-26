`default_nettype none

// N independent RV32I harts sharing an instruction ROM and data SRAM.
module tiny_risc_soc #(
    parameter integer N_HARTS = 4,
    parameter integer HART_STRIDE_BYTES = 64,
    parameter integer IMEM_WORDS = 1024,
    parameter integer DMEM_WORDS = 1024,
    parameter integer MEMORY_LATENCY = 1,
    parameter IMEM_INIT_FILE = ""
) (
    input  logic clk, rst_n,
    input  logic [N_HARTS-1:0] hart_enable,
    output logic [N_HARTS-1:0] hart_fault
);
    logic [N_HARTS-1:0] i_req_valid, i_req_ready, i_rsp_valid, i_rsp_error;
    logic [N_HARTS-1:0][31:0] i_req_addr, i_rsp_inst;
    logic [N_HARTS-1:0] d_req_valid, d_req_ready, d_req_write;
    logic [N_HARTS-1:0] d_rsp_valid, d_rsp_error;
    logic [N_HARTS-1:0][31:0] d_req_addr, d_req_wdata, d_rsp_rdata;
    logic [N_HARTS-1:0][3:0] d_req_wstrb;

    logic im_req_valid, im_req_ready, im_rsp_valid, im_rsp_error;
    logic [31:0] im_req_addr, im_req_wdata, im_rsp_data;
    logic [3:0] im_req_wstrb;
    logic im_req_write;
    logic dm_req_valid, dm_req_ready, dm_req_write;
    logic dm_rsp_valid, dm_rsp_error;
    logic [31:0] dm_req_addr, dm_req_wdata, dm_rsp_data;
    logic [3:0] dm_req_wstrb;

    for (genvar h = 0; h < N_HARTS; h++) begin : g_hart
        localparam logic [31:0] HART_RESET_VECTOR = h * HART_STRIDE_BYTES;
        tiny_risc #(.RESET_VECTOR(HART_RESET_VECTOR)) i_core (
            .clk(clk), .rst_n(rst_n), .hart_enable(hart_enable[h]),
            .fault(hart_fault[h]),
            .imem_req_valid(i_req_valid[h]),
            .imem_req_ready(i_req_ready[h]),
            .imem_req_addr(i_req_addr[h]),
            .imem_rsp_valid(i_rsp_valid[h]),
            .imem_rsp_inst(i_rsp_inst[h]),
            .imem_rsp_error(i_rsp_error[h]),
            .dmem_req_valid(d_req_valid[h]),
            .dmem_req_ready(d_req_ready[h]),
            .dmem_req_addr(d_req_addr[h]),
            .dmem_req_write(d_req_write[h]),
            .dmem_req_wdata(d_req_wdata[h]),
            .dmem_req_wstrb(d_req_wstrb[h]),
            .dmem_rsp_valid(d_rsp_valid[h]),
            .dmem_rsp_rdata(d_rsp_rdata[h]),
            .dmem_rsp_error(d_rsp_error[h])
        );
    end

    rv32_mem_arbiter #(.N_HARTS(N_HARTS)) i_imem_arbiter (
        .clk(clk), .rst_n(rst_n),
        .in_req_valid(i_req_valid), .in_req_ready(i_req_ready),
        .in_req_addr(i_req_addr), .in_req_write('0),
        .in_req_wdata('0), .in_req_wstrb('0),
        .in_rsp_valid(i_rsp_valid), .in_rsp_rdata(i_rsp_inst),
        .in_rsp_error(i_rsp_error),
        .out_req_valid(im_req_valid), .out_req_ready(im_req_ready),
        .out_req_addr(im_req_addr), .out_req_write(im_req_write),
        .out_req_wdata(im_req_wdata), .out_req_wstrb(im_req_wstrb),
        .out_rsp_valid(im_rsp_valid), .out_rsp_rdata(im_rsp_data),
        .out_rsp_error(im_rsp_error)
    );
    rv32_shared_memory #(
        .WORDS(IMEM_WORDS), .LATENCY(MEMORY_LATENCY),
        .READ_ONLY(1'b1), .INIT_FILE(IMEM_INIT_FILE)
    ) i_imem (
        .clk(clk), .rst_n(rst_n),
        .req_valid(im_req_valid), .req_ready(im_req_ready),
        .req_addr(im_req_addr), .req_write(im_req_write),
        .req_wdata(im_req_wdata), .req_wstrb(im_req_wstrb),
        .rsp_valid(im_rsp_valid), .rsp_rdata(im_rsp_data),
        .rsp_error(im_rsp_error)
    );

    rv32_mem_arbiter #(.N_HARTS(N_HARTS)) i_dmem_arbiter (
        .clk(clk), .rst_n(rst_n),
        .in_req_valid(d_req_valid), .in_req_ready(d_req_ready),
        .in_req_addr(d_req_addr), .in_req_write(d_req_write),
        .in_req_wdata(d_req_wdata), .in_req_wstrb(d_req_wstrb),
        .in_rsp_valid(d_rsp_valid), .in_rsp_rdata(d_rsp_rdata),
        .in_rsp_error(d_rsp_error),
        .out_req_valid(dm_req_valid), .out_req_ready(dm_req_ready),
        .out_req_addr(dm_req_addr), .out_req_write(dm_req_write),
        .out_req_wdata(dm_req_wdata), .out_req_wstrb(dm_req_wstrb),
        .out_rsp_valid(dm_rsp_valid), .out_rsp_rdata(dm_rsp_data),
        .out_rsp_error(dm_rsp_error)
    );
    rv32_shared_memory #(
        .WORDS(DMEM_WORDS), .LATENCY(MEMORY_LATENCY)
    ) i_dmem (
        .clk(clk), .rst_n(rst_n),
        .req_valid(dm_req_valid), .req_ready(dm_req_ready),
        .req_addr(dm_req_addr), .req_write(dm_req_write),
        .req_wdata(dm_req_wdata), .req_wstrb(dm_req_wstrb),
        .rsp_valid(dm_rsp_valid), .rsp_rdata(dm_rsp_data),
        .rsp_error(dm_rsp_error)
    );
endmodule

`default_nettype wire
