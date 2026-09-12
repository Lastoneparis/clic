// systolic.v — an N x N output-stationary systolic array (clic-A1 compute core).
//
// Computes C[N][N] = A[N][K] * B[K][N]. Row i of A streams in from the west
// (skewed by i cycles); column j of B streams in from the north (skewed by j).
// A value entering west of row i and one entering north of col j meet at
// PE(i,j) exactly when their k indices match, so PE(i,j) accumulates
// sum_k A[i][k]*B[k][j] = C[i][j]. Parameterized and synthesizable.
//
// Ports are flattened buses (portable Verilog-2001 / synthesis-friendly):
//   west_in [row*DW +: DW]      feeds row `row`
//   north_in[col*DW +: DW]      feeds col `col`
//   acc_out [(i*N+j)*ACCW +: ACCW] = C[i][j]

module systolic #(
    parameter N    = 4,
    parameter DW   = 8,
    parameter ACCW = 32
) (
    input  wire                       clk,
    input  wire                       rst,
    input  wire        [N*DW-1:0]     west_in,
    input  wire        [N*DW-1:0]     north_in,
    output wire        [N*N*ACCW-1:0] acc_out
);
    // inter-PE wires: one extra column/row for the far edges (unused)
    wire signed [DW-1:0] a_h [0:N-1][0:N];   // a_h[i][j] -> a_in of PE(i,j)
    wire signed [DW-1:0] b_v [0:N][0:N-1];   // b_v[i][j] -> b_in of PE(i,j)

    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin : west_edge
            assign a_h[i][0] = west_in[i*DW +: DW];
        end
        for (j = 0; j < N; j = j + 1) begin : north_edge
            assign b_v[0][j] = north_in[j*DW +: DW];
        end
        for (i = 0; i < N; i = i + 1) begin : rows
            for (j = 0; j < N; j = j + 1) begin : cols
                wire signed [ACCW-1:0] acc_ij;
                pe #(.DW(DW), .ACCW(ACCW)) u_pe (
                    .clk   (clk),
                    .rst   (rst),
                    .a_in  (a_h[i][j]),
                    .b_in  (b_v[i][j]),
                    .a_out (a_h[i][j+1]),
                    .b_out (b_v[i+1][j]),
                    .acc   (acc_ij)
                );
                assign acc_out[(i*N + j)*ACCW +: ACCW] = acc_ij;
            end
        end
    endgenerate
endmodule
