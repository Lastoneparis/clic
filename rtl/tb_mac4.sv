// tb_mac4.sv — self-checking testbench for the packed INT4 MAC.
// Feeds random INT4 operands, accumulates 2 MACs/cycle, and compares the
// hardware accumulator to a reference sum.
`timescale 1ns/1ps

module tb;
    localparam ACCW = 32, NC = 100;
    reg clk = 0, rst = 1;
    reg signed [3:0] a0, b0, a1, b1;
    wire signed [ACCW-1:0] acc;

    mac4 #(.ACCW(ACCW)) dut (.clk(clk), .rst(rst),
                             .a0(a0), .b0(b0), .a1(a1), .b1(b1), .acc(acc));
    always #5 clk = ~clk;

    integer i, ref_acc;
    reg signed [3:0] A0 [0:NC-1], B0 [0:NC-1], A1 [0:NC-1], B1 [0:NC-1];

    initial begin
        for (i = 0; i < NC; i = i + 1) begin
            A0[i] = $random; B0[i] = $random; A1[i] = $random; B1[i] = $random;
        end

        @(negedge clk); rst = 1; @(negedge clk); rst = 0;

        ref_acc = 0; a0 = 0; b0 = 0; a1 = 0; b1 = 0;
        for (i = 0; i < NC; i = i + 1) begin
            a0 = A0[i]; b0 = B0[i]; a1 = A1[i]; b1 = B1[i];
            ref_acc = ref_acc + A0[i]*B0[i] + A1[i]*B1[i];   // 2 MACs / cycle
            @(negedge clk);
        end
        a0 = 0; b0 = 0; a1 = 0; b1 = 0; @(negedge clk);      // settle

        if (acc === ref_acc)
            $display("PASS: mac4 (2 INT4 MACs/cycle) matches reference over %0d cycles (acc=%0d)", NC, acc);
        else
            $display("FAIL: acc=%0d exp=%0d", acc, ref_acc);
        $finish;
    end
endmodule
