// cursed_ide_top.v -- top-level wiring for CursedIDE.
//
//   prompt --> prompt_channel --> agent_pool --> file_buffer
//                                            \-> prompt_channel --> diff
//
// Parameterize N for how many agents you want to race against each other.

`default_nettype none

module cursed_ide_top #(
    parameter integer N            = 4,
    parameter integer THINK_CYCLES = 8
) (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [7:0]  prompt_in_data,
    input  wire        prompt_in_valid,
    output wire        prompt_in_ready,

    output wire [7:0]  diff_out_data,
    output wire        diff_out_valid,
    input  wire        diff_out_ready,

    output wire [N-1:0] busy_vec
);

    wire [7:0] p_data;  wire p_valid;  wire p_ready;
    wire [7:0] d_data;  wire d_valid;  wire d_ready;

    wire        fb_req, fb_we, fb_grant;
    wire [7:0]  fb_addr, fb_wdata, fb_rdata;

    prompt_channel #(.WIDTH(8)) u_prompt_in (
        .clk(clk), .rst_n(rst_n),
        .in_data (prompt_in_data),
        .in_valid(prompt_in_valid),
        .in_ready(prompt_in_ready),
        .out_data(p_data),
        .out_valid(p_valid),
        .out_ready(p_ready)
    );

    agent_pool #(.N(N), .THINK_CYCLES(THINK_CYCLES)) u_pool (
        .clk(clk), .rst_n(rst_n),
        .prompt_data (p_data),
        .prompt_valid(p_valid),
        .prompt_ready(p_ready),
        .diff_data   (d_data),
        .diff_valid  (d_valid),
        .diff_ready  (d_ready),
        .fb_req      (fb_req),
        .fb_we       (fb_we),
        .fb_addr     (fb_addr),
        .fb_wdata    (fb_wdata),
        .fb_rdata    (fb_rdata),
        .fb_grant    (fb_grant),
        .busy_vec    (busy_vec)
    );

    file_buffer #(.DEPTH(256), .WIDTH(8)) u_fb (
        .clk(clk), .rst_n(rst_n),
        .req  (fb_req),
        .we   (fb_we),
        .addr (fb_addr),
        .wdata(fb_wdata),
        .rdata(fb_rdata),
        .grant(fb_grant)
    );

    prompt_channel #(.WIDTH(8)) u_diff_out (
        .clk(clk), .rst_n(rst_n),
        .in_data (d_data),
        .in_valid(d_valid),
        .in_ready(d_ready),
        .out_data (diff_out_data),
        .out_valid(diff_out_valid),
        .out_ready(diff_out_ready)
    );

endmodule

`default_nettype wire
