
import definesPkg::*;


// -----------------------------------------------------------------------------

module SMEM_FIFO #(
    parameter NUM_PE        = 16,               //16
    parameter SMEM_WW       = 16,
    // parameter AXIS_BW       = 256,              //256
    parameter MAX_N         = 256,              //1024
    parameter MAX_M         = 256,              //32
    parameter MAX_NoP       = MAX_N/NUM_PE,     //64
    parameter SMEM_DEPTH    = MAX_M*MAX_NoP*4,

    parameter NUM_CH_RD     = 2,
    parameter NUM_CH_WR     = 2,

    parameter BUF_IN_DEPTH  = 4,

    localparam ADDR_BW      = $clog2(SMEM_DEPTH),   // MSB: bank(SRAM0/SRAM1)
    localparam WSEL_BW      = $clog2(NUM_PE) + 1,   // {WordOp, WordIdx}
    localparam CH_IDX_BW    = $clog2(NUM_CH_RD),
    localparam FIFO_PTR_BW  = $clog2(BUF_IN_DEPTH),
    localparam FIFO_CNT_BW  = $clog2(BUF_IN_DEPTH+1)
) (
    input  logic        clk,
    input  logic        rstn,

    // ---------------- Read channels ----------------
    input  logic                    rd_push   [NUM_CH_RD-1:0],
    input  logic                    rd_pop    [NUM_CH_RD-1:0],
    output logic                    rd_empty  [NUM_CH_RD-1:0],
    output logic                    rd_full   [NUM_CH_RD-1:0],

    input  logic [WSEL_BW-1:0]      rd_wsel_i [NUM_CH_RD-1:0],
    input  logic [ADDR_BW-1:0]      rd_addr_i [NUM_CH_RD-1:0],

    output logic [WSEL_BW-1:0]      rd_wsel_o [NUM_CH_RD-1:0],
    output logic [ADDR_BW-1:0]      rd_addr_o [NUM_CH_RD-1:0],
    
    // ---------------- Write channels ----------------
    input  logic                    wr_push   [NUM_CH_WR-1:0],
    input  logic                    wr_pop    [NUM_CH_WR-1:0],
    output logic                    wr_empty  [NUM_CH_WR-1:0],
    output logic                    wr_full   [NUM_CH_WR-1:0],

    input  logic [WSEL_BW-1:0]      wr_wsel_i [NUM_CH_WR-1:0],
    input  logic [ADDR_BW-1:0]      wr_addr_i [NUM_CH_WR-1:0],
    input  logic [SMEM_WW-1:0]      wr_din_i  [NUM_CH_WR-1:0][0:NUM_PE-1],

    output logic [WSEL_BW-1:0]      wr_wsel_o [NUM_CH_WR-1:0],
    output logic [ADDR_BW-1:0]      wr_addr_o [NUM_CH_WR-1:0],
    output logic [SMEM_WW-1:0]      wr_din_o  [NUM_CH_WR-1:0][0:NUM_PE-1]
    
);


// -----------------------------------------------------------------------------
// Global variables

    // ---------------- Read channel FIFO ----------------
    logic [WSEL_BW-1:0]         rd_wsel_r   [0:BUF_IN_DEPTH-1][NUM_CH_RD-1:0];
    logic [ADDR_BW-1:0]         rd_addr_r   [0:BUF_IN_DEPTH-1][NUM_CH_RD-1:0];
    logic [FIFO_PTR_BW-1:0]     rd_head     [NUM_CH_RD-1:0];
    logic [FIFO_PTR_BW-1:0]     rd_tail     [NUM_CH_RD-1:0];
    logic [FIFO_CNT_BW-1:0]     rd_cnt      [NUM_CH_RD-1:0];

    // ---------------- Write channel FIFO ----------------
    logic [WSEL_BW-1:0]         wr_wsel_r   [0:BUF_IN_DEPTH-1][NUM_CH_WR-1:0];
    logic [ADDR_BW-1:0]         wr_addr_r   [0:BUF_IN_DEPTH-1][NUM_CH_WR-1:0];
    logic [SMEM_WW-1:0]         wr_din_r    [0:BUF_IN_DEPTH-1][NUM_CH_WR-1:0][0:NUM_PE-1];
    logic [FIFO_PTR_BW-1:0]     wr_head     [NUM_CH_WR-1:0];
    logic [FIFO_PTR_BW-1:0]     wr_tail     [NUM_CH_WR-1:0];
    logic [FIFO_CNT_BW-1:0]     wr_cnt      [NUM_CH_WR-1:0];


// -----------------------------------------------------------------------------
// Module body


    // ------------------------ Read channel FIFO ------------------------

    always_ff @(posedge clk) begin
        for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_RD-1; ch_idx++) begin
            if (!rstn) begin
                rd_head[ch_idx] <= 0;
            end else if (rd_pop[ch_idx]) begin
            // end else if (rd_pop[ch_idx] && !rd_empty[ch_idx]) begin
                rd_head[ch_idx] <= rd_head[ch_idx] + 1;
            end
        end
    end

    always_ff @(posedge clk) begin
        for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_RD-1; ch_idx++) begin
            if (!rstn) begin
                rd_tail[ch_idx] <= 0;
            end else if (rd_push[ch_idx]) begin
            // end else if (rd_push[ch_idx] && !rd_full[ch_idx]) begin
                rd_tail[ch_idx] <= rd_tail[ch_idx] + 1;
            end
        end
    end

    always_ff @(posedge clk) begin
        for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_RD-1; ch_idx++) begin
            if (!rstn) begin
                rd_wsel_o[ch_idx] <= '0;
                rd_addr_o[ch_idx] <= '0;
            end else if (rd_pop[ch_idx]) begin
            // end else if (rd_pop[ch_idx] && !rd_empty[ch_idx]) begin
                rd_wsel_o[ch_idx] <= rd_wsel_r[rd_head[ch_idx]][ch_idx];
                rd_addr_o[ch_idx] <= rd_addr_r[rd_head[ch_idx]][ch_idx];
            end
        end
    end

    always_ff @(posedge clk) begin
        for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_RD-1; ch_idx++) begin
            if (rd_push[ch_idx]) begin
            // if (rd_push[ch_idx] && !rd_full[ch_idx]) begin
                rd_wsel_r[rd_tail[ch_idx]][ch_idx] <= rd_wsel_i[ch_idx];
                rd_addr_r[rd_tail[ch_idx]][ch_idx] <= rd_addr_i[ch_idx];
            end
        end
    end
    
    always_ff @(posedge clk) begin
        for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_RD-1; ch_idx++) begin
            if (!rstn) begin
                rd_cnt[ch_idx] <= 0;
            // end else if (rd_pop[ch_idx] && !rd_empty[ch_idx]) begin
            end else if (rd_pop[ch_idx] && !rd_push[ch_idx]) begin
                rd_cnt[ch_idx] <= rd_cnt[ch_idx] - 1;
            // end else if (rd_push[ch_idx] && !rd_full[ch_idx]) begin
            end else if (rd_push[ch_idx] && !rd_pop[ch_idx]) begin
                rd_cnt[ch_idx] <= rd_cnt[ch_idx] + 1;
            end
            // pop && push: rd_cnt no change
        end
    end

    always_comb begin
        for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_RD-1; ch_idx++) begin
            rd_empty[ch_idx] = (rd_cnt[ch_idx] == 0);
            rd_full[ch_idx] = (rd_cnt[ch_idx] == BUF_IN_DEPTH);
        end
    end


    // ------------------------ Write channel FIFO ------------------------

    always_ff @(posedge clk) begin
        for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_WR-1; ch_idx++) begin
            if (!rstn) begin
                wr_head[ch_idx] <= 0;
            end else if (wr_pop[ch_idx]) begin
            // end else if (wr_pop[ch_idx] && !wr_empty[ch_idx]) begin
                wr_head[ch_idx] <= wr_head[ch_idx] + 1;
            end
        end
    end

    always_ff @(posedge clk) begin
        for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_WR-1; ch_idx++) begin
            if (!rstn) begin
                wr_tail[ch_idx] <= 0;
            end else if (wr_push[ch_idx]) begin
            // end else if (wr_push[ch_idx] && !wr_full[ch_idx]) begin
                wr_tail[ch_idx] <= wr_tail[ch_idx] + 1;
            end
        end
    end

    always_ff @(posedge clk) begin
        for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_WR-1; ch_idx++) begin
            if (!rstn) begin
                wr_wsel_o[ch_idx] <= '0;
                wr_addr_o[ch_idx] <= '0;
                wr_din_o [ch_idx] <= '{NUM_PE{1'b0}};
            end else if (wr_pop[ch_idx]) begin
            // end else if (wr_pop[ch_idx] && !wr_empty[ch_idx]) begin
                wr_wsel_o[ch_idx] <= wr_wsel_r[wr_head[ch_idx]][ch_idx];
                wr_addr_o[ch_idx] <= wr_addr_r[wr_head[ch_idx]][ch_idx];
                wr_din_o [ch_idx] <= wr_din_r [wr_head[ch_idx]][ch_idx];
            end
        end
    end

    always_ff @(posedge clk) begin
        for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_WR-1; ch_idx++) begin
            if (wr_push[ch_idx]) begin
            // if (wr_push[ch_idx] && !wr_full[ch_idx]) begin
                wr_wsel_r[wr_tail[ch_idx]][ch_idx] <= wr_wsel_i[ch_idx];
                wr_addr_r[wr_tail[ch_idx]][ch_idx] <= wr_addr_i[ch_idx];
                wr_din_r [wr_tail[ch_idx]][ch_idx] <= wr_din_i [ch_idx];
            end
        end
    end
    
    always_ff @(posedge clk) begin
        for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_WR-1; ch_idx++) begin
            if (!rstn) begin
                wr_cnt[ch_idx] <= 0;
            // end else if (wr_pop[ch_idx] && !wr_empty[ch_idx]) begin
            end else if (wr_pop[ch_idx] && !wr_push[ch_idx]) begin
                wr_cnt[ch_idx] <= wr_cnt[ch_idx] - 1;
            // end else if (wr_push[ch_idx] && !wr_full[ch_idx]) begin
            end else if (wr_push[ch_idx] && !wr_pop[ch_idx]) begin
                wr_cnt[ch_idx] <= wr_cnt[ch_idx] + 1;
            end
            // pop && push: wr_cnt no change
        end
    end

    always_comb begin
        for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_WR-1; ch_idx++) begin
            wr_empty[ch_idx] = (wr_cnt[ch_idx] == 0);
            wr_full[ch_idx] = (wr_cnt[ch_idx] == BUF_IN_DEPTH);
        end
    end


endmodule
