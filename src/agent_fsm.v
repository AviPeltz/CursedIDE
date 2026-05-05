// agent_fsm.v -- single coding-agent state machine.
//
// One agent's life cycle: receive a prompt token-stream, "think", emit tool
// calls, await tool results, emit a diff, return to idle. The "thinking"
// here is a counter; the real LLM lives off-chip and is reached through the
// prompt_channel.

`default_nettype none

module agent_fsm #(
    parameter integer THINK_CYCLES = 8,
    parameter integer ID           = 0
) (
    input  wire        clk,
    input  wire        rst_n,

    // Inbound prompt stream (ready/valid, 8-bit tokens).
    input  wire [7:0]  prompt_data,
    input  wire        prompt_valid,
    output reg         prompt_ready,

    // Outbound diff stream (ready/valid, 8-bit tokens).
    output wire [7:0]  diff_data,
    output reg         diff_valid,
    input  wire        diff_ready,

    // Shared file-buffer port.
    output reg         fb_req,
    output reg         fb_we,
    output reg  [7:0]  fb_addr,
    output reg  [7:0]  fb_wdata,
    input  wire [7:0]  fb_rdata,
    input  wire        fb_grant,

    // Status.
    output reg  [2:0]  state_out,
    output reg         busy
);

    localparam [2:0]
        S_IDLE         = 3'd0,
        S_RECEIVING    = 3'd1,
        S_THINKING     = 3'd2,
        S_EMIT_TOOL    = 3'd3,
        S_AWAIT_RESULT = 3'd4,
        S_EMIT_DIFF    = 3'd5,
        S_DONE         = 3'd6;

    reg [2:0]               state, next_state;
    reg [$clog2(THINK_CYCLES+1)-1:0] think_ctr;
    reg [7:0]               write_ctr;

    // Combinational so the first beat of S_EMIT_DIFF carries 'A', not the
    // residual register value.
    assign diff_data = 8'h41 + write_ctr;

    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE:         if (prompt_valid)              next_state = S_RECEIVING;
            S_RECEIVING:    if (prompt_valid && prompt_data == 8'h0A)
                                                            next_state = S_THINKING;
            S_THINKING:     if (think_ctr == THINK_CYCLES) next_state = S_EMIT_TOOL;
            S_EMIT_TOOL:    if (fb_grant)                   next_state = S_AWAIT_RESULT;
            S_AWAIT_RESULT: if (fb_grant)                   next_state = S_EMIT_DIFF;
            S_EMIT_DIFF:    if (diff_ready && write_ctr == 8'd3)
                                                            next_state = S_DONE;
            S_DONE:                                         next_state = S_IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            think_ctr    <= 0;
            write_ctr    <= 0;
            prompt_ready <= 1'b0;
            diff_valid   <= 1'b0;
            fb_req       <= 1'b0;
            fb_we        <= 1'b0;
            fb_addr      <= 8'h00;
            fb_wdata     <= 8'h00;
            state_out    <= S_IDLE;
            busy         <= 1'b0;
        end else begin
            state     <= next_state;
            state_out <= next_state;
            busy      <= (next_state != S_IDLE);

            prompt_ready <= (next_state == S_IDLE) || (next_state == S_RECEIVING);
            diff_valid   <= (next_state == S_EMIT_DIFF);
            fb_req       <= (next_state == S_EMIT_TOOL) || (next_state == S_AWAIT_RESULT);
            fb_we        <= (next_state == S_EMIT_TOOL);
            fb_addr      <= 8'(ID);
            fb_wdata     <= 8'h2A; // '*' -- agent left its mark.

            if (state == S_THINKING)
                think_ctr <= think_ctr + 1'b1;
            else
                think_ctr <= 0;

            if (state == S_EMIT_DIFF && diff_ready)
                write_ctr <= write_ctr + 1'b1;
            else if (state != S_EMIT_DIFF)
                write_ctr <= 0;
        end
    end

endmodule

`default_nettype wire
