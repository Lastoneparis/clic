// gemm_accel.v — a self-contained GEMM accelerator block (clic-A1 cluster shape).
//
// Wraps the systolic array with on-chip memories and a control FSM. The host
// loads A and B through a simple write port, pulses `start`, and reads C back
// after `done`. The FSM performs the input skewing in HARDWARE (it moved off
// the testbench), clears the array, streams the tiles, drains, and latches the
// result. This is the gen-1 MVP cluster: SRAM + sequencer + MAC array + a
// simple host interface (no PCIe/NoC/DRAM — those are gen-2).
//
// Memories are behavioural reg arrays here; on an ASIC they become foundry SRAM
// macros (memory compiler), on an FPGA block RAM.

module gemm_accel #(
    parameter N    = 4,          // array / tile dimension
    parameter K    = 4,          // contraction dimension
    parameter DW   = 8,          // operand width (INT8)
    parameter ACCW = 32,         // accumulator width
    parameter AW   = 16          // host address width
) (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    start,
    output reg                     done,
    // host load port (write A / B)
    input  wire                    host_we,
    input  wire                    host_sel,     // 0 = A, 1 = B
    input  wire [AW-1:0]           host_waddr,
    input  wire signed [DW-1:0]    host_wdata,
    // host read port (read C)
    input  wire [AW-1:0]           host_raddr,
    output wire signed [ACCW-1:0]  host_rdata
);
    localparam FEED_CYC = K + 2*N;

    reg signed [DW-1:0]   A_mem [0:N*K-1];
    reg signed [DW-1:0]   B_mem [0:K*N-1];
    reg signed [ACCW-1:0] C_mem [0:N*N-1];

    // host load
    always @(posedge clk) begin
        if (host_we) begin
            if (host_sel == 1'b0) A_mem[host_waddr] <= host_wdata;
            else                  B_mem[host_waddr] <= host_wdata;
        end
    end
    assign host_rdata = C_mem[host_raddr];

    // systolic array
    reg              pe_rst;
    reg  [N*DW-1:0]  west_in, north_in;
    wire [N*N*ACCW-1:0] acc_out;
    systolic #(.N(N), .DW(DW), .ACCW(ACCW)) arr (
        .clk(clk), .rst(rst | pe_rst),
        .west_in(west_in), .north_in(north_in), .acc_out(acc_out)
    );

    // control FSM
    localparam S_IDLE=0, S_CLEAR=1, S_FEED=2, S_DRAIN=3, S_CAP=4, S_DONE=5;
    reg [2:0]  state;
    reg [15:0] cnt;
    reg [N*DW-1:0] w_tmp, n_tmp;
    integer r, c, ki, i, j;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE; done <= 0; pe_rst <= 0; cnt <= 0;
            west_in <= 0; north_in <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0; west_in <= 0; north_in <= 0;
                    if (start) begin pe_rst <= 1; state <= S_CLEAR; end
                end
                S_CLEAR: begin                      // one cycle: zero the accumulators
                    pe_rst <= 0; cnt <= 0; state <= S_FEED;
                end
                S_FEED: begin                       // stream skewed A/B into the array
                    w_tmp = 0; n_tmp = 0;
                    for (r = 0; r < N; r = r + 1) begin
                        ki = cnt - r;               // row r delayed by r
                        if (ki >= 0 && ki < K) w_tmp[r*DW +: DW] = A_mem[r*K + ki];
                    end
                    for (c = 0; c < N; c = c + 1) begin
                        ki = cnt - c;               // col c delayed by c
                        if (ki >= 0 && ki < K) n_tmp[c*DW +: DW] = B_mem[ki*N + c];
                    end
                    west_in <= w_tmp; north_in <= n_tmp;
                    if (cnt == FEED_CYC-1) state <= S_DRAIN;
                    cnt <= cnt + 1;
                end
                S_DRAIN: begin                      // let the pipeline settle
                    west_in <= 0; north_in <= 0;
                    if (cnt == FEED_CYC+2) state <= S_CAP;
                    cnt <= cnt + 1;
                end
                S_CAP: begin                        // latch C from the accumulators
                    for (i = 0; i < N; i = i + 1)
                        for (j = 0; j < N; j = j + 1)
                            C_mem[i*N + j] <= $signed(acc_out[(i*N+j)*ACCW +: ACCW]);
                    state <= S_DONE;
                end
                S_DONE: begin
                    done <= 1;
                    if (!start) state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
