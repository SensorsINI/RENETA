
import definesPkg::*;


// -----------------------------------------------------------------------------
// Simple Standard FIFO

module FIFO_STD #(
    parameter WIDTH = 16,
    parameter DEPTH = 4,
    parameter FWFT  = 0,                    // First-Word-Fall-Through

    localparam PTR_BW = $clog2(DEPTH),
    localparam CNT_BW = $clog2(DEPTH+1)
) (
    input  logic                clk,
    input  logic                rstn,

    input  logic                push,
    input  logic                pop,
    output logic                empty,
    output logic                full,

    input  logic [WIDTH-1:0]    din,
    output logic [WIDTH-1:0]    dout
);


// -----------------------------------------------------------------------------
// Global variables

    // ---------------- FIFO data, pointers, and status ----------------
    logic [WIDTH-1:0]           ram[0:DEPTH-1];
    logic [PTR_BW-1:0]          rd_ptr;
    logic [PTR_BW-1:0]          wr_ptr;
    logic [CNT_BW-1:0]          cnt;


// -----------------------------------------------------------------------------
// Module body


    always_ff @(posedge clk) begin
        if (!rstn) begin
            rd_ptr <= 0;
        end else if (pop) begin
        // end else if (pop && !empty) begin
            rd_ptr <= rd_ptr + 1;
        end
    end

    always_ff @(posedge clk) begin
        if (!rstn) begin
            wr_ptr <= 0;
        end else if (push) begin
        // end else if (push && !full) begin
            wr_ptr <= wr_ptr + 1;
        end
    end

    generate
        if (FWFT == 0) begin:   output_register
            // Read latency = 1 clock cycle
            always_ff @(posedge clk) begin
                if (!rstn) begin
                    dout <= '0;
                end else if (pop) begin
                // end else if (pop && !empty) begin
                    dout <= ram[rd_ptr];
                end
            end
        end else begin:         no_output_register
            // Read latency = 0 clock cycle
            assign dout = ram[rd_ptr];
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (push) begin
        // if (push && !full) begin
            ram[wr_ptr] <= din;
        end
    end
    
    always_ff @(posedge clk) begin
        if (!rstn) begin
            cnt <= 0;
        // end else if (pop && !empty) begin
        end else if (pop && !push) begin
            cnt <= cnt - 1;
        // end else if (push && !full) begin
        end else if (push && !pop) begin
            cnt <= cnt + 1;
        end
        // pop && push: cnt no change
    end

    assign empty = (cnt == 0);
    assign full = (cnt == DEPTH);

`ifndef SYNTHESIS
    // DEBUG: underflow/overflow check
    always_ff @(posedge clk) begin
        if (empty && pop)
            $display("[!!!] @%0t %m underflow!", $stime);
        if (full && push)
            $display("[!!!] @%0t %m overflow!", $stime);
    end

    // DEBUG: remaining data check
    final begin
        if (cnt > 0)
            $display("[!!!] @%0t %m remaining data! cnt = %d", $stime, cnt);
    end
`endif


endmodule
