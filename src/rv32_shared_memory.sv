`default_nettype none

// Simple 32-bit word SRAM/ROM model with a registered response.
// The address is byte-addressed and must point to an aligned word.
module rv32_shared_memory #(
    parameter integer WORDS = 256,
    parameter integer LATENCY = 1,
    parameter bit READ_ONLY = 1'b0,
    parameter INIT_FILE = ""
) (
    input  logic clk, rst_n,
    input  logic req_valid,
    output logic req_ready,
    input  logic [31:0] req_addr,
    input  logic req_write,
    input  logic [31:0] req_wdata,
    input  logic [3:0] req_wstrb,
    output logic rsp_valid,
    output logic [31:0] rsp_rdata,
    output logic rsp_error
);
    logic [31:0] words [0:WORDS-1];
    logic busy;
    integer remaining;
    integer word_index;
    localparam integer EFFECTIVE_LATENCY = (LATENCY > 0) ? LATENCY : 1;

    assign req_ready = !busy && !rsp_valid;
    assign word_index = integer'(req_addr >> 2);

    initial begin
        for (integer i = 0; i < WORDS; i++) words[i] = '0;
        if (INIT_FILE != "") $readmemh(INIT_FILE, words);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            remaining <= 0;
            rsp_valid <= 1'b0;
            rsp_rdata <= '0;
            rsp_error <= 1'b0;
        end else begin
            rsp_valid <= 1'b0;
            if (req_valid && req_ready) begin
                busy <= 1'b1;
                remaining <= EFFECTIVE_LATENCY-1;
                rsp_error <= (req_addr[1:0] != 2'b00) ||
                             (word_index < 0) || (word_index >= WORDS) ||
                             (READ_ONLY && req_write);
                if ((word_index >= 0) && (word_index < WORDS)) begin
                    rsp_rdata <= words[word_index];
                    if (req_write && !READ_ONLY && req_addr[1:0] == 2'b00)
                        for (integer lane = 0; lane < 4; lane++)
                            if (req_wstrb[lane])
                                words[word_index][8*lane +: 8] <=
                                    req_wdata[8*lane +: 8];
                end else rsp_rdata <= '0;
            end else if (busy) begin
                if (remaining == 0) begin
                    rsp_valid <= 1'b1;
                    busy <= 1'b0;
                end else remaining <= remaining-1;
            end
        end
    end
endmodule

`default_nettype wire
