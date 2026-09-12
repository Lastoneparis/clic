// pe.v — one processing element of the clic-A1 systolic array.
//
// Output-stationary MAC cell: every clock it accumulates a_in*b_in and passes
// a to the right and b downward. An N x N grid of these computes a GEMM tile.
// Synthesizable Verilog-2001 (maps to a standard-cell multiplier + adder + regs;
// the multiplier becomes a hardened MAC on an ASIC, a DSP slice on an FPGA).

module pe #(
    parameter DW   = 8,     // operand width (INT8)
    parameter ACCW = 32     // accumulator width
) (
    input  wire                   clk,
    input  wire                   rst,
    input  wire signed [DW-1:0]   a_in,
    input  wire signed [DW-1:0]   b_in,
    output reg  signed [DW-1:0]   a_out,   // a flows east
    output reg  signed [DW-1:0]   b_out,   // b flows south
    output reg  signed [ACCW-1:0] acc      // C[i][j] partial sum
);
    always @(posedge clk) begin
        if (rst) begin
            a_out <= 0;
            b_out <= 0;
            acc   <= 0;
        end else begin
            acc   <= acc + a_in * b_in;   // multiply-accumulate
            a_out <= a_in;                // systolic hand-off
            b_out <= b_in;
        end
    end
endmodule
