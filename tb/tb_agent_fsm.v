// tb_agent_fsm.v -- single-agent smoke test.

`timescale 1ns/1ps
`default_nettype none

module tb_agent_fsm;
    reg clk = 0;
    reg rst_n = 0;
    always #5 clk = ~clk;

    reg  [7:0] prompt_data  = 8'h00;
    reg        prompt_valid = 1'b0;
    wire       prompt_ready;

    wire [7:0] diff_data;
    wire       diff_valid;
    reg        diff_ready = 1'b1;

    wire       fb_req, fb_we;
    wire [7:0] fb_addr, fb_wdata;
    reg  [7:0] fb_rdata = 8'h00;
    reg        fb_grant = 1'b0;

    wire [2:0] state_out;
    wire       busy;

    agent_fsm #(.THINK_CYCLES(4), .ID(0)) dut (
        .clk(clk), .rst_n(rst_n),
        .prompt_data(prompt_data),
        .prompt_valid(prompt_valid),
        .prompt_ready(prompt_ready),
        .diff_data(diff_data),
        .diff_valid(diff_valid),
        .diff_ready(diff_ready),
        .fb_req(fb_req), .fb_we(fb_we),
        .fb_addr(fb_addr), .fb_wdata(fb_wdata),
        .fb_rdata(fb_rdata), .fb_grant(fb_grant),
        .state_out(state_out), .busy(busy)
    );

    integer diff_count = 0;
    always @(posedge clk) begin
        if (diff_valid && diff_ready) begin
            $display("[%0t] diff byte: %h (%c)", $time, diff_data, diff_data);
            diff_count = diff_count + 1;
        end
    end

    // Crude grant: assert one cycle after every fb_req.
    always @(posedge clk) fb_grant <= fb_req;

    initial begin
        $dumpfile("build/tb_agent.vcd");
        $dumpvars(0, tb_agent_fsm);

        #20 rst_n = 1'b1;

        // Stream a prompt: "HI\n"
        @(posedge clk); prompt_data <= "H"; prompt_valid <= 1'b1;
        @(posedge clk); prompt_data <= "I";
        @(posedge clk); prompt_data <= 8'h0A; // newline = end
        @(posedge clk); prompt_valid <= 1'b0;

        // Wait for the agent to walk through its lifecycle.
        repeat (200) @(posedge clk);

        if (diff_count == 4) $display("PASS: agent emitted %0d diff bytes", diff_count);
        else                 $display("FAIL: expected 4 diff bytes, got %0d", diff_count);

        $finish;
    end
endmodule

`default_nettype wire
