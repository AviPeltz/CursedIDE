// tb_cursed_ide_top.v -- full-system smoke test.

`timescale 1ns/1ps
`default_nettype none

module tb_cursed_ide_top;
    localparam integer N = 2;

    reg clk = 0;
    reg rst_n = 0;
    always #5 clk = ~clk;

    reg  [7:0] p_data  = 8'h00;
    reg        p_valid = 1'b0;
    wire       p_ready;

    wire [7:0] d_data;
    wire       d_valid;
    reg        d_ready = 1'b1;

    wire [N-1:0] busy_vec;

    cursed_ide_top #(.N(N), .THINK_CYCLES(4)) dut (
        .clk(clk), .rst_n(rst_n),
        .prompt_in_data (p_data),
        .prompt_in_valid(p_valid),
        .prompt_in_ready(p_ready),
        .diff_out_data  (d_data),
        .diff_out_valid (d_valid),
        .diff_out_ready (d_ready),
        .busy_vec       (busy_vec)
    );

    integer total = 0;
    always @(posedge clk) begin
        if (d_valid && d_ready) begin
            $display("[%0t] diff: %h (%c)  busy=%b", $time, d_data, d_data, busy_vec);
            total = total + 1;
        end
    end

    initial begin
        $dumpfile("build/tb_top.vcd");
        $dumpvars(0, tb_cursed_ide_top);

        #20 rst_n = 1'b1;

        // Send a prompt "GO\n" -- one agent picks it up.
        @(posedge clk); p_data <= "G"; p_valid <= 1'b1;
        @(posedge clk); p_data <= "O";
        @(posedge clk); p_data <= 8'h0A;
        @(posedge clk); p_valid <= 1'b0;

        repeat (400) @(posedge clk);

        if (total > 0) $display("PASS: top-level emitted %0d diff bytes", total);
        else           $display("FAIL: no diff bytes emitted");

        $finish;
    end
endmodule

`default_nettype wire
