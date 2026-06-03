
`default_nettype none

module tb_regfile;
    localparam XLEN = 32;

    // DUT (Device Under Test: register_file) の信号宣言
    reg            tb_clock;
    reg            tb_resetn;

    logic          tb_we;
    logic   [ 4:0] tb_addr_rs1;
    logic   [ 4:0] tb_addr_rs2;
    logic   [ 4:0] tb_addr_rd;
    logic   [31:0] tb_write_data;
    logic   [31:0] tb_data_rs1;
    logic   [31:0] tb_data_rs2;

    integer        fail_cnt = 0;
    integer        compare_cnt = 0;

    // テスト対象モジュールのインスタンス化
    regfile #(
        .XLEN(XLEN)
    ) i_regfile (
        .clock(tb_clock),
        .resetn(tb_resetn),
        .we(tb_we),
        .addr_rs1(tb_addr_rs1),
        .addr_rs2(tb_addr_rs2),
        .addr_rd(tb_addr_rd),
        .write_data(tb_write_data),
        .data_rs1(tb_data_rs1),
        .data_rs2(tb_data_rs2)
    );

    // クロック生成 (50%デューティサイクル)
    always #5 tb_clock = ~tb_clock;

    initial begin
        // Set up for waveform dumping
        $dumpfile("tb_regfile.vcd");
        $dumpvars(0, tb_regfile);

        for (int i = 0; i < XLEN; i = i + 1) begin
            $dumpvars(0, tb_regfile.i_regfile.register_array[i]);
        end
    end

    task compare(input logic [XLEN-1:0] exp, input logic [XLEN-1:0] act,
                 input int addr);
        compare_cnt = compare_cnt + 1;
        if (exp != act) begin
            fail_cnt = fail_cnt + 1;
            $display("Error: Expected %b, Actually %b (Addr: %d) at time %t",
                     exp, act, addr, $time);
        end else begin
            // $display("Pass: Expected %b, Actually %b", exp, act);
        end
    endtask

    function void display_result();
        if (0 == fail_cnt) begin
            $display("Pass: 0 errors, %d checks", compare_cnt);
        end else begin
            $display("Error: %d errors, %d checks", fail_cnt, compare_cnt);
        end
    endfunction

    initial begin
        tb_resetn = 1;
        #10 tb_clock = 0;
        tb_resetn = 0;
        tb_we = 0;
        tb_addr_rs1 = 5'd0;
        tb_addr_rs2 = 5'd0;
        tb_addr_rd = 5'd0;

        #10 tb_resetn = 1;
        @(posedge tb_clock);

        $display("-- Clear check");
        fail_cnt = 0;
        compare_cnt = 0;
        for (int i = 0; i < 32; i = i + 1) begin
            tb_addr_rs1 = i;
            @(posedge tb_clock);

            compare(32'd0, tb_data_rs1, i);
        end
        display_result();

        $display("-- Write check (x0 exclude)");
        fail_cnt = 0;
        compare_cnt = 0;
        for (int i = 1; i < 32; i = i + 1) begin
            tb_addr_rs1 = i;
            tb_addr_rd = i;
            tb_we = 1;
            tb_write_data = {(XLEN / 2) {2'b10}};
            @(posedge tb_clock);
            tb_we = 0;

            @(posedge tb_clock);

            compare(tb_write_data, tb_data_rs1, i);
        end
        display_result();

        $display("-- x0 check");
        fail_cnt = 0;
        compare_cnt = 0;
        tb_addr_rd = 5'd0;
        tb_addr_rs1 = 5'd0;
        tb_we = 1;
        tb_write_data = {(XLEN / 2) {2'b10}};
        @(posedge tb_clock);
        tb_we = 0;

        @(posedge tb_clock);

        compare(32'd0, tb_data_rs1, 5'd0);
        display_result();

        $display("-- Simultaneous Read check");
        fail_cnt = 0;
        compare_cnt = 0;
        // rs1 and rs2 read different registers simultaneously
        tb_addr_rs1 = 5'd5;
        tb_addr_rs2 = 5'd10;
        #1;
        compare({(XLEN / 2) {2'b10}}, tb_data_rs1, 5'd5);
        compare({(XLEN / 2) {2'b10}}, tb_data_rs2, 5'd10);

        // rs1 and rs2 read the same register simultaneously
        tb_addr_rs1 = 5'd8;
        tb_addr_rs2 = 5'd8;
        #1;
        compare({(XLEN / 2) {2'b10}}, tb_data_rs1, 5'd8);
        compare({(XLEN / 2) {2'b10}}, tb_data_rs2, 5'd8);
        display_result();

        $display("-- Simultaneous Write/Read check");
        fail_cnt = 0;
        compare_cnt = 0;
        // Write to x15, and simultaneously read x15 via rs1, and x16 via rs2
        tb_addr_rd = 5'd15;
        tb_write_data = 32'h55555555;
        tb_we = 1;
        tb_addr_rs1 = 5'd15;
        tb_addr_rs2 = 5'd16;

        // Before posedge clock, rs1 and rs2 should output old values
        #1;
        compare({(XLEN / 2) {2'b10}}, tb_data_rs1, 5'd15);
        compare({(XLEN / 2) {2'b10}}, tb_data_rs2, 5'd16);

        // Trigger write at posedge clock
        @(posedge tb_clock);

        // After posedge clock, rs1 (x15) should output the newly written value
        // rs2 (x16) should still output the old value
        #1;
        compare(32'h55555555, tb_data_rs1, 5'd15);
        compare({(XLEN / 2) {2'b10}}, tb_data_rs2, 5'd16);

        tb_we = 0;
        @(posedge tb_clock);
        display_result();

        $finish;
    end
endmodule
