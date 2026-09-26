`default_nettype none

// Round-robin arbiter. One shared-memory transaction is outstanding at a time.
module rv32_mem_arbiter #(
    parameter integer N_HARTS = 2,
    localparam integer ID_WIDTH = (N_HARTS > 1) ? $clog2(N_HARTS) : 1
) (
    input  logic clk, rst_n,
    input  logic [N_HARTS-1:0] in_req_valid,
    output logic [N_HARTS-1:0] in_req_ready,
    input  logic [N_HARTS-1:0][31:0] in_req_addr,
    input  logic [N_HARTS-1:0] in_req_write,
    input  logic [N_HARTS-1:0][31:0] in_req_wdata,
    input  logic [N_HARTS-1:0][3:0] in_req_wstrb,
    output logic [N_HARTS-1:0] in_rsp_valid,
    output logic [N_HARTS-1:0][31:0] in_rsp_rdata,
    output logic [N_HARTS-1:0] in_rsp_error,
    output logic out_req_valid,
    input  logic out_req_ready,
    output logic [31:0] out_req_addr,
    output logic out_req_write,
    output logic [31:0] out_req_wdata,
    output logic [3:0] out_req_wstrb,
    input  logic out_rsp_valid,
    input  logic [31:0] out_rsp_rdata,
    input  logic out_rsp_error
);
    logic busy, found;
    logic [ID_WIDTH-1:0] owner, last_grant, selected;
    integer candidate;

    always_comb begin
        found = 1'b0;
        selected = '0;
        candidate = 0;
        for (integer offset = 0; offset < N_HARTS; offset++) begin
            candidate = (integer'(last_grant) + 1 + offset) % N_HARTS;
            if (!found && in_req_valid[candidate]) begin
                found = 1'b1;
                selected = ID_WIDTH'(candidate);
            end
        end
    end

    always_comb begin
        in_req_ready = '0;
        in_rsp_valid = '0;
        in_rsp_rdata = '0;
        in_rsp_error = '0;
        out_req_valid = !busy && found;
        out_req_addr = '0;
        out_req_write = 1'b0;
        out_req_wdata = '0;
        out_req_wstrb = '0;
        if (!busy && found) begin
            out_req_addr = in_req_addr[selected];
            out_req_write = in_req_write[selected];
            out_req_wdata = in_req_wdata[selected];
            out_req_wstrb = in_req_wstrb[selected];
            in_req_ready[selected] = out_req_ready;
        end
        if (busy) begin
            in_rsp_valid[owner] = out_rsp_valid;
            in_rsp_rdata[owner] = out_rsp_rdata;
            in_rsp_error[owner] = out_rsp_error;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            owner <= '0;
            last_grant <= ID_WIDTH'(N_HARTS-1);
        end else begin
            if (!busy && found && out_req_ready) begin
                busy <= 1'b1;
                owner <= selected;
                last_grant <= selected;
            end else if (busy && out_rsp_valid) begin
                busy <= 1'b0;
            end
        end
    end
endmodule

`default_nettype wire
