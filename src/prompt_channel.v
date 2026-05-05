// prompt_channel.v -- skid-buffered ready/valid stream.
//
// In a real FPGA build this attaches to a UART, AXI-Stream, or an SPI bridge
// to the host where the LLM lives. Here we just provide a 1-deep skid buffer
// so the agent_pool can backpressure cleanly.

`default_nettype none

module prompt_channel #(
    parameter integer WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,

    input  wire [WIDTH-1:0] in_data,
    input  wire             in_valid,
    output wire             in_ready,

    output wire [WIDTH-1:0] out_data,
    output wire             out_valid,
    input  wire             out_ready
);

    reg [WIDTH-1:0] buf_data;
    reg             buf_full;

    assign in_ready  = !buf_full;
    assign out_data  = buf_full ? buf_data : in_data;
    assign out_valid = buf_full || in_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buf_full <= 1'b0;
            buf_data <= {WIDTH{1'b0}};
        end else begin
            if (!buf_full && in_valid && !out_ready) begin
                buf_full <= 1'b1;
                buf_data <= in_data;
            end else if (buf_full && out_ready) begin
                buf_full <= 1'b0;
            end
        end
    end

endmodule

`default_nettype wire
