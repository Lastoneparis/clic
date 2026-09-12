// tb_gemm_accel.sv — self-checking testbench for the GEMM accelerator block.
// Loads A and B through the host port, runs the accelerator, reads C back, and
// compares against a CPU reference. Exercises the full block: memories + FSM +
// hardware skewing + systolic array.
`timescale 1ns/1ps

module tb;
    localparam N = 4, K = 4, DW = 8, ACCW = 32, AW = 16;

    reg clk = 0, rst = 1, start = 0;
    reg host_we = 0, host_sel = 0;
    reg [AW-1:0] host_waddr = 0, host_raddr = 0;
    reg signed [DW-1:0] host_wdata = 0;
    wire done;
    wire signed [ACCW-1:0] host_rdata;

    gemm_accel #(.N(N), .K(K), .DW(DW), .ACCW(ACCW), .AW(AW)) dut (
        .clk(clk), .rst(rst), .start(start), .done(done),
        .host_we(host_we), .host_sel(host_sel), .host_waddr(host_waddr),
        .host_wdata(host_wdata), .host_raddr(host_raddr), .host_rdata(host_rdata)
    );

    always #5 clk = ~clk;

    integer i, j, k, errors;
    reg signed [DW-1:0] A [0:N-1][0:K-1];
    reg signed [DW-1:0] B [0:K-1][0:N-1];
    integer expected [0:N-1][0:N-1];

    task host_write(input sel, input [AW-1:0] a, input signed [DW-1:0] d);
        begin
            @(negedge clk);
            host_we = 1; host_sel = sel; host_waddr = a; host_wdata = d;
            @(negedge clk);
            host_we = 0;
        end
    endtask

    initial begin
        for (i=0;i<N;i=i+1) for (k=0;k<K;k=k+1) A[i][k] = (i+1) + k;
        for (k=0;k<K;k=k+1) for (j=0;j<N;j=j+1) B[k][j] = (k+1) - j;
        for (i=0;i<N;i=i+1) for (j=0;j<N;j=j+1) begin
            expected[i][j] = 0;
            for (k=0;k<K;k=k+1) expected[i][j] = expected[i][j] + A[i][k]*B[k][j];
        end

        @(negedge clk); rst = 1; @(negedge clk); rst = 0;

        // load A (sel=0, addr = i*K+k) and B (sel=1, addr = k*N+j)
        for (i=0;i<N;i=i+1) for (k=0;k<K;k=k+1) host_write(1'b0, i*K+k, A[i][k]);
        for (k=0;k<K;k=k+1) for (j=0;j<N;j=j+1) host_write(1'b1, k*N+j, B[k][j]);

        // run
        @(negedge clk); start = 1; @(negedge clk); start = 0;
        wait (done);
        @(negedge clk);

        // read C back and check
        errors = 0;
        for (i=0;i<N;i=i+1) for (j=0;j<N;j=j+1) begin
            host_raddr = i*N + j;
            @(negedge clk);
            if (host_rdata !== expected[i][j]) begin
                errors = errors + 1;
                $display("  MISMATCH C[%0d][%0d] got %0d exp %0d", i, j, host_rdata, expected[i][j]);
            end
        end

        if (errors == 0)
            $display("PASS: gemm_accel block (load->run->read) matches CPU reference (%0d elems)", N*N);
        else
            $display("FAIL: %0d mismatches", errors);
        $finish;
    end
endmodule
