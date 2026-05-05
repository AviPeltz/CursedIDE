// file_buffer.v -- parameterized register-file "file" shared across agents.
//
// One write port, one read port, one cycle of latency. Grant is asserted
// the cycle after a request -- crude but enough for round-robin sims.

`default_nettype none

module file_buffer #(
    parameter integer DEPTH = 256,
    parameter integer WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             req,
    input  wire             we,
    input  wire [7:0]       addr,
    input  wire [WIDTH-1:0] wdata,
    output reg  [WIDTH-1:0] rdata,
    output reg              grant
);

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grant <= 1'b0;
            rdata <= {WIDTH{1'b0}};
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= {WIDTH{1'b0}};
        end else begin
            grant <= req;
            if (req && we) mem[addr] <= wdata;
            rdata <= mem[addr];
        end
    end

endmodule

`default_nettype wire
