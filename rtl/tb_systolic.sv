// tb_systolic.sv — self-checking testbench for the clic-A1 systolic array.
// Feeds skewed A/B streams, drains the pipeline, and compares every C[i][j]
// against a CPU-computed reference. Prints PASS/FAIL.
`timescale 1ns/1ps

module tb;
    localparam N = 4, K = 4, DW = 8, ACCW = 32;

    reg clk = 0, rst = 1;
    reg  signed [DW-1:0]     A [0:N-1][0:K-1];
    reg  signed [DW-1:0]     B [0:K-1][0:N-1];
    reg         [N*DW-1:0]   west_in, north_in;
    wire        [N*N*ACCW-1:0] acc_out;

    systolic #(.N(N), .DW(DW), .ACCW(ACCW)) dut (
        .clk(clk), .rst(rst), .west_in(west_in), .north_in(north_in), .acc_out(acc_out)
    );

    always #5 clk = ~clk;

    integer i, j, k, t, errors;
    integer expected [0:N-1][0:N-1];

    // present the correctly-skewed operands for feed-step t
    task set_inputs(input integer t);
        integer r, c, ki;
        begin
            west_in  = 0;
            north_in = 0;
            for (r = 0; r < N; r = r + 1) begin
                ki = t - r;                          // row r delayed by r
                if (ki >= 0 && ki < K) west_in[r*DW +: DW] = A[r][ki];
            end
            for (c = 0; c < N; c = c + 1) begin
                ki = t - c;                          // col c delayed by c
                if (ki >= 0 && ki < K) north_in[c*DW +: DW] = B[ki][c];
            end
        end
    endtask

    initial begin
        // deterministic operands, including negatives (exercise signed MAC)
        for (i = 0; i < N; i = i + 1)
            for (k = 0; k < K; k = k + 1) A[i][k] = (i + 1) + k;
        for (k = 0; k < K; k = k + 1)
            for (j = 0; j < N; j = j + 1) B[k][j] = (k + 1) - j;

        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                expected[i][j] = 0;
                for (k = 0; k < K; k = k + 1)
                    expected[i][j] = expected[i][j] + A[i][k] * B[k][j];
            end

        // reset
        west_in = 0; north_in = 0;
        @(negedge clk); rst = 1;
        @(negedge clk); rst = 0;

        // feed skewed streams long enough for all contributions to land
        for (t = 0; t < K + 2*N; t = t + 1) begin
            set_inputs(t);
            @(negedge clk);
        end
        west_in = 0; north_in = 0;
        repeat (2) @(negedge clk);                   // drain

        errors = 0;
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                if ($signed(acc_out[(i*N+j)*ACCW +: ACCW]) !== expected[i][j]) begin
                    errors = errors + 1;
                    $display("  MISMATCH C[%0d][%0d] got %0d exp %0d", i, j,
                             $signed(acc_out[(i*N+j)*ACCW +: ACCW]), expected[i][j]);
                end
            end

        if (errors == 0)
            $display("PASS: %0dx%0d systolic GEMM matches CPU reference (%0d elements)", N, N, N*N);
        else
            $display("FAIL: %0d mismatches", errors);
        $finish;
    end
endmodule
