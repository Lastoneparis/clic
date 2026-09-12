// mac4.v — a packed INT4 multiply-accumulate: two INT4 MACs per cycle.
//
// This is the hardware behind clic-A1's INT4 mode and the spec's "262 TOPS INT4
// = 2× the 131 TOPS INT8" claim: an INT8-width MAC datapath can instead do two
// INT4 multiply-accumulates per cycle, doubling throughput for quantized models.
// Synthesizable; the two 4×4 multipliers fit where one 8×8 would.

module mac4 #(parameter ACCW = 32) (
    input  wire                   clk,
    input  wire                   rst,
    input  wire signed [3:0]      a0, b0,   // lane 0 operands (INT4)
    input  wire signed [3:0]      a1, b1,   // lane 1 operands (INT4)
    output reg  signed [ACCW-1:0] acc
);
    always @(posedge clk) begin
        if (rst) acc <= 0;
        else     acc <= acc + a0 * b0 + a1 * b1;   // two INT4 MACs / cycle
    end
endmodule
