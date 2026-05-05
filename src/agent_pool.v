// agent_pool.v -- N parallel agent_fsm instances sharing one file_buffer.
//
// Prompt routing locks onto the first idle agent at the start of a prompt
// and stays locked until end-of-line ('\n'). Diff and file-buffer ports use
// round-robin arbitration. Real hardware parallelism is the entire pitch.

`default_nettype none

module agent_pool #(
    parameter integer N            = 4,
    parameter integer THINK_CYCLES = 8
) (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [7:0]  prompt_data,
    input  wire        prompt_valid,
    output wire        prompt_ready,

    output wire [7:0]  diff_data,
    output wire        diff_valid,
    input  wire        diff_ready,

    output wire        fb_req,
    output wire        fb_we,
    output wire [7:0]  fb_addr,
    output wire [7:0]  fb_wdata,
    input  wire [7:0]  fb_rdata,
    input  wire        fb_grant,

    output wire [N-1:0] busy_vec
);

    // Per-agent flattened buses.
    wire [N-1:0]       a_prompt_rdy;
    wire [N*8-1:0]     a_diff_data;
    wire [N-1:0]       a_diff_valid;
    wire [N-1:0]       a_fb_req;
    wire [N-1:0]       a_fb_we;
    wire [N*8-1:0]     a_fb_addr;
    wire [N*8-1:0]     a_fb_wdata;

    // First idle agent (priority encoder, one-hot).
    reg [N-1:0] first_idle_oh;
    integer i;
    always @(*) begin
        first_idle_oh = {N{1'b0}};
        for (i = 0; i < N; i = i + 1)
            if (first_idle_oh == {N{1'b0}} && !busy_vec[i])
                first_idle_oh[i] = 1'b1;
    end

    // Lock the prompt to one agent until '\n'.
    reg [N-1:0] lock_oh;
    reg         locked;
    wire [N-1:0] route_oh = locked ? lock_oh : first_idle_oh;
    wire         eol_handshake =
        prompt_valid && prompt_ready && (prompt_data == 8'h0A);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lock_oh <= {N{1'b0}};
            locked  <= 1'b0;
        end else if (!locked && prompt_valid && |first_idle_oh) begin
            lock_oh <= first_idle_oh;
            locked  <= 1'b1;
        end else if (locked && eol_handshake) begin
            locked  <= 1'b0;
            lock_oh <= {N{1'b0}};
        end
    end

    // Round-robin diff and file-buffer selectors.
    reg [$clog2(N)-1:0] sel_out, sel_fb;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sel_out <= 0;
            sel_fb  <= 0;
        end else begin
            // Skip past idle agents so we don't park on a silent one.
            if (!a_diff_valid[sel_out] && !diff_valid)
                sel_out <= sel_out + 1'b1;
            else if (diff_valid && diff_ready)
                sel_out <= sel_out + 1'b1;

            if (!a_fb_req[sel_fb] && !fb_req)
                sel_fb <= sel_fb + 1'b1;
            else if (fb_req && fb_grant)
                sel_fb <= sel_fb + 1'b1;
        end
    end

    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : agents
            agent_fsm #(
                .THINK_CYCLES(THINK_CYCLES),
                .ID(g)
            ) u_agent (
                .clk          (clk),
                .rst_n        (rst_n),
                .prompt_data  (prompt_data),
                .prompt_valid (prompt_valid && route_oh[g]),
                .prompt_ready (a_prompt_rdy[g]),
                .diff_data    (a_diff_data [g*8 +: 8]),
                .diff_valid   (a_diff_valid[g]),
                .diff_ready   (diff_ready && (sel_out == g[$clog2(N)-1:0])),
                .fb_req       (a_fb_req[g]),
                .fb_we        (a_fb_we [g]),
                .fb_addr      (a_fb_addr [g*8 +: 8]),
                .fb_wdata     (a_fb_wdata[g*8 +: 8]),
                .fb_rdata     (fb_rdata),
                .fb_grant     (fb_grant && (sel_fb == g[$clog2(N)-1:0])),
                .state_out    (),
                .busy         (busy_vec[g])
            );
        end
    endgenerate

    assign prompt_ready = |(route_oh & a_prompt_rdy);
    assign diff_data    = a_diff_data [sel_out*8 +: 8];
    assign diff_valid   = a_diff_valid[sel_out];
    assign fb_req       = a_fb_req    [sel_fb];
    assign fb_we        = a_fb_we     [sel_fb];
    assign fb_addr      = a_fb_addr   [sel_fb*8 +: 8];
    assign fb_wdata     = a_fb_wdata  [sel_fb*8 +: 8];

endmodule

`default_nettype wire
