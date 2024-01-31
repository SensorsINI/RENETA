
import definesPkg::*;


//  ARB_CH-M        ARB_M-CH        RD_DOUT
//  pend ch-m
//  +---------------pend m-ch
//                  +---------------ch_rd_ndready

// ARB_CH-M: pend ch when its m is processing requests from prioritized channels
//           pend ch when its m is pended
// ARB_M-CH: pend m when its ch is outputing data from prioritized memory block 
//           pend m when its ch is pended
// RD_DOUT:  pend ch(rd) when rd_dready[ch]==1'b0

// -----------------------------------------------------------------------------

module SMEM #(
    // parameter NUM_PE        = 16,               //16
    parameter SMEM_WW       = 16,
    // parameter AXIS_BW       = 256,              //256
    // parameter MAX_N         = 256,              //1024
    // parameter MAX_M         = 256,              //32
    // parameter MAX_NoP       = MAX_N/NUM_PE,     //64
    parameter SMEM_DEPTH    = MAX_M*MAX_NoP*4,

    parameter NUM_CH_RD     = 3,
    parameter NUM_CH_WR     = 2,

    parameter BUF_IN_DEPTH  = 4,
    parameter BUF_MID_DEPTH = 1,
    parameter BUF_OUT_DEPTH = 1,

    localparam ADDR_BW      = $clog2(SMEM_DEPTH),   // MSB: bank(SRAM0/SRAM1)
    localparam WSEL_BW      = $clog2(NUM_PE) + 1,   // {WordOp, WordIdx}
    localparam CH_IDX_BW    = $clog2(NUM_CH_RD)
    // localparam STS_BW       = 2
) (
    input  logic        clk,
    input  logic        rstn,

    // ---------------- Read channels ----------------
    input  logic [WSEL_BW-1:0]      rd_wsel   [NUM_CH_RD-1:0],
    input  logic [ADDR_BW-1:0]      rd_addr   [NUM_CH_RD-1:0],
    input  logic                    rd_avalid [NUM_CH_RD-1:0],
    output logic                    rd_aready [NUM_CH_RD-1:0],
    output logic [SMEM_WW-1:0]      rd_dout   [NUM_CH_RD-1:0][0:NUM_PE-1],
    output logic [WSEL_BW-1:0]      rd_dwsel  [NUM_CH_RD-1:0],
    // output logic                    rd_dstrobe[NUM_CH_RD-1:0][0:NUM_PE-1],
    output logic                    rd_dvalid [NUM_CH_RD-1:0],
    input  logic                    rd_dready [NUM_CH_RD-1:0],
    
    // ---------------- Write channels ----------------
    input  logic [WSEL_BW-1:0]      wr_wsel   [NUM_CH_WR-1:0],
    input  logic [ADDR_BW-1:0]      wr_addr   [NUM_CH_WR-1:0],
    input  logic                    wr_avalid [NUM_CH_WR-1:0],
    output logic                    wr_aready [NUM_CH_WR-1:0],
    input  logic [SMEM_WW-1:0]      wr_din    [NUM_CH_WR-1:0][0:NUM_PE-1]
    // output logic [STS_BW-1:0]       wr_sout   [NUM_CH_WR-1:0],      // status
    // output logic                    wr_svalid [NUM_CH_WR-1:0],
    // input  logic                    wr_sready [NUM_CH_WR-1:0],
    
);


// -----------------------------------------------------------------------------
// Global variables

    // ---------------- Read channel FIFO signals ----------------
    logic                   rd_push     [NUM_CH_RD-1:0];
    logic                   rd_pop      [NUM_CH_RD-1:0];
    logic                   rd_empty    [NUM_CH_RD-1:0];
    logic                   rd_full     [NUM_CH_RD-1:0];
    logic [WSEL_BW-1:0]     rd_wsel_o   [NUM_CH_RD-1:0];
    logic [ADDR_BW-1:0]     rd_addr_o   [NUM_CH_RD-1:0];
    logic                   rd_avalid_o [NUM_CH_RD-1:0];
    
    // ---------------- Read channel output regs ----------------
    logic [SMEM_WW-1:0]     rd_dout_r   [0:BUF_OUT_DEPTH][NUM_CH_RD-1:0][0:NUM_PE-1];
    logic [WSEL_BW-1:0]     rd_dwsel_r  [0:BUF_OUT_DEPTH][NUM_CH_RD-1:0];
    // logic                   rd_dstrobe_r[0:BUF_OUT_DEPTH][NUM_CH_RD-1:0][0:NUM_PE-1];
    logic                   rd_dvalid_r [0:BUF_OUT_DEPTH][NUM_CH_RD-1:0];

    // ---------------- Write channel FIFO signals ----------------
    logic                   wr_push     [NUM_CH_WR-1:0];
    logic                   wr_pop      [NUM_CH_WR-1:0];
    logic                   wr_empty    [NUM_CH_WR-1:0];
    logic                   wr_full     [NUM_CH_WR-1:0];
    logic [WSEL_BW-1:0]     wr_wsel_o   [NUM_CH_WR-1:0];
    logic [ADDR_BW-1:0]     wr_addr_o   [NUM_CH_WR-1:0];
    logic [SMEM_WW-1:0]     wr_din_o    [NUM_CH_WR-1:0][0:NUM_PE-1];
    logic                   wr_avalid_o [NUM_CH_WR-1:0];

    // ---------------- Write channel output regs ----------------
    // logic [STS_BW-1:0]      wr_sout_r   [0:BUF_OUT_DEPTH][NUM_CH_WR-1:0];
    // logic                   wr_svalid_r [0:BUF_OUT_DEPTH][NUM_CH_WR-1:0];

    // ---------------- SRAM request procedure signals ----------------
    logic                   f_rd_pending[NUM_CH_RD-1:0];
    logic                   f_wr_pending[NUM_CH_WR-1:0];
    logic                   f_wr_any_0, f_wr_any_1;
    logic                   f_M0_pending;
    logic                   f_M1_pending;

    // ---------------- SRAM0 request regs ----------------
    logic                   M0_en_r     [0:BUF_MID_DEPTH][0:NUM_PE-1];
    logic                   M0_we_r     [0:BUF_MID_DEPTH][0:NUM_PE-1];
    logic [ADDR_BW-1-1:0]   M0_addr_r   [0:BUF_MID_DEPTH][0:NUM_PE-1];
    logic [SMEM_WW-1:0]     M0_din_r    [0:BUF_MID_DEPTH][0:NUM_PE-1];
    logic [CH_IDX_BW-1:0]   M0_ch_r     [0:BUF_MID_DEPTH];
    logic                   M0_ren_r    [0:BUF_MID_DEPTH];
    logic [WSEL_BW-1:0]     M0_wsel_r   [0:BUF_MID_DEPTH];

    // ---------------- SRAM1 request regs ----------------
    logic                   M1_en_r     [0:BUF_MID_DEPTH][0:NUM_PE-1];
    logic                   M1_we_r     [0:BUF_MID_DEPTH][0:NUM_PE-1];
    logic [ADDR_BW-1-1:0]   M1_addr_r   [0:BUF_MID_DEPTH][0:NUM_PE-1];
    logic [SMEM_WW-1:0]     M1_din_r    [0:BUF_MID_DEPTH][0:NUM_PE-1];
    logic [CH_IDX_BW-1:0]   M1_ch_r     [0:BUF_MID_DEPTH];
    logic                   M1_ren_r    [0:BUF_MID_DEPTH];
    logic [WSEL_BW-1:0]     M1_wsel_r   [0:BUF_MID_DEPTH];

    // ---------------- SRAM0 signals ----------------
    logic                   M0_en       [0:NUM_PE-1];
    logic                   M0_we       [0:NUM_PE-1];
    logic [ADDR_BW-1-1:0]   M0_addr     [0:NUM_PE-1];
    logic [SMEM_WW-1:0]     M0_din      [0:NUM_PE-1];
    logic [SMEM_WW-1:0]     M0_dout     [0:NUM_PE-1];

    // ---------------- SRAM1 signals ----------------
    logic                   M1_en       [0:NUM_PE-1];
    logic                   M1_we       [0:NUM_PE-1];
    logic [ADDR_BW-1-1:0]   M1_addr     [0:NUM_PE-1];
    logic [SMEM_WW-1:0]     M1_din      [0:NUM_PE-1];
    logic [SMEM_WW-1:0]     M1_dout     [0:NUM_PE-1];
    
    // ---------------- Extra regs and signals for SRAMs ----------------
    // Synchronized with M*_dout
    logic                   M0_en_prev  [0:NUM_PE-1];
    logic                   M0_we_prev  [0:NUM_PE-1];
    logic [CH_IDX_BW-1:0]   M0_ch_prev;
    logic                   M0_ren_prev;
    logic [WSEL_BW-1:0]     M0_wsel_prev;
    logic                   M1_en_prev  [0:NUM_PE-1];
    logic                   M1_we_prev  [0:NUM_PE-1];
    logic [CH_IDX_BW-1:0]   M1_ch_prev;
    logic                   M1_ren_prev;
    logic [WSEL_BW-1:0]     M1_wsel_prev;


// -----------------------------------------------------------------------------
// Module body


    // ------------------------ SMEM FIFO instance ------------------------
    // Buffer incoming requests
    
    SMEM_FIFO #(
        .NUM_PE         ( NUM_PE       ),
        .SMEM_WW        ( SMEM_WW      ),

        .MAX_N          ( MAX_N        ),
        .MAX_M          ( MAX_M        ),
        .MAX_NoP        ( MAX_NoP      ),
        .SMEM_DEPTH     ( SMEM_DEPTH   ),

        .NUM_CH_RD      ( NUM_CH_RD    ),
        .NUM_CH_WR      ( NUM_CH_WR    ),

        .BUF_IN_DEPTH   ( BUF_IN_DEPTH )
    ) SMEM_FIFO_inst (
        .clk            ( clk          ),
        .rstn           ( rstn         ),

        .rd_push        ( rd_push      ),
        .rd_pop         ( rd_pop       ),
        .rd_empty       ( rd_empty     ),
        .rd_full        ( rd_full      ),
        .rd_wsel_i      ( rd_wsel      ),
        .rd_addr_i      ( rd_addr      ),
        .rd_wsel_o      ( rd_wsel_o    ),
        .rd_addr_o      ( rd_addr_o    ),

        .wr_push        ( wr_push      ),
        .wr_pop         ( wr_pop       ),
        .wr_empty       ( wr_empty     ),
        .wr_full        ( wr_full      ),
        .wr_wsel_i      ( wr_wsel      ),
        .wr_addr_i      ( wr_addr      ),
        .wr_din_i       ( wr_din       ),
        .wr_wsel_o      ( wr_wsel_o    ),
        .wr_addr_o      ( wr_addr_o    ),
        .wr_din_o       ( wr_din_o     )
    );

    always_comb begin
        for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_RD-1; ch_idx++) begin
            rd_push[ch_idx] = rd_avalid[ch_idx] && !rd_full[ch_idx];
            rd_aready[ch_idx] = !rd_full[ch_idx];
            rd_pop[ch_idx] = !rd_empty[ch_idx] && !f_rd_pending[ch_idx];
        end
    end

    always_comb begin
        for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_WR-1; ch_idx++) begin
            wr_push[ch_idx] = wr_avalid[ch_idx] && !wr_full[ch_idx];
            wr_aready[ch_idx] = !wr_full[ch_idx];
            wr_pop[ch_idx] = !wr_empty[ch_idx] && !f_wr_pending[ch_idx];
        end
    end

    always_ff @(posedge clk) begin
        for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_RD-1; ch_idx++) begin
            if (!rstn) begin
                rd_avalid_o[ch_idx] <= 1'b0;
            end else if (!f_rd_pending[ch_idx]) begin
                rd_avalid_o[ch_idx] <= !rd_empty[ch_idx];
            end
        end
    end

    always_ff @(posedge clk) begin
        for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_WR-1; ch_idx++) begin
            if (!rstn) begin
                wr_avalid_o[ch_idx] <= 1'b0;
            end else if (!f_wr_pending[ch_idx]) begin
                wr_avalid_o[ch_idx] <= !wr_empty[ch_idx];
            end
        end
    end


    // ------------------------ SRAM request procedure ------------------------
    // Proceed requests from read/write channels and send them to SRAMs
    // (NUM_CH_RD + NUM_CH_WR) channels --> 2 SRAMs

    always_comb begin
        logic [WSEL_BW-1-1:0] wsel_tmp;
        
        M0_en_r  [0] = '{NUM_PE{1'b0}};
        M0_we_r  [0] = '{NUM_PE{1'b0}};
        M0_addr_r[0] = M0_addr_r[1];    // ???
        M0_din_r [0] = M0_din_r [1];    // ???
        M0_ch_r  [0] = M0_ch_r  [1];    // ???
        M0_ren_r [0] = 1'b0;
        M0_wsel_r[0] = M0_wsel_r[1];    // ???

        M1_en_r  [0] = '{NUM_PE{1'b0}};
        M1_we_r  [0] = '{NUM_PE{1'b0}};
        M1_addr_r[0] = M1_addr_r[1];    // ???
        M1_din_r [0] = M1_din_r [1];    // ???
        M1_ch_r  [0] = M1_ch_r  [1];    // ???
        M1_ren_r [0] = 1'b0;
        M1_wsel_r[0] = M1_wsel_r[1];    // ???
        
        f_wr_pending[NUM_CH_WR-1:0] = wr_avalid_o[NUM_CH_WR-1:0];
        f_rd_pending[NUM_CH_RD-1:0] = rd_avalid_o[NUM_CH_RD-1:0];

        // -------- Find a request to SRAM 0 --------
        
        f_wr_any_0 = 1'b0;

        if (!f_M0_pending) begin

            // Write request first
            for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_WR-1; ch_idx++) begin
                if (wr_avalid_o[ch_idx] && (wr_addr_o[ch_idx][ADDR_BW-1] == 1'b0)) begin
                    // M0_ren_r[0] = 1'b0;
                    // M0_wsel_r[0] = wr_wsel_o[ch_idx];
                    wsel_tmp = wr_wsel_o[ch_idx][WSEL_BW-1-1:0];
                    if (wr_wsel_o[ch_idx][WSEL_BW-1] == 1'b0) begin
                        M0_en_r  [0][0:NUM_PE-1] = '{NUM_PE{1'b1}};
                        M0_we_r  [0][0:NUM_PE-1] = '{NUM_PE{1'b1}};
                        M0_addr_r[0][0:NUM_PE-1] = '{NUM_PE{wr_addr_o[ch_idx][ADDR_BW-1-1:0]}};
                        M0_din_r [0][0:NUM_PE-1] = wr_din_o[ch_idx][0:NUM_PE-1];
                    end else begin
                        M0_en_r  [0][wsel_tmp] = 1'b1;
                        M0_we_r  [0][wsel_tmp] = 1'b1;
                        M0_addr_r[0][wsel_tmp] = wr_addr_o[ch_idx][ADDR_BW-1-1:0];
                        M0_din_r [0][wsel_tmp] = wr_din_o[ch_idx][wsel_tmp];
                    end
                    // M0_ch_r[0] = ch_idx;
                    f_wr_pending[ch_idx] = 1'b0;
                    f_wr_any_0 = 1'b1;
                    break;
                end
            end
            
            // Read request next
            if (!f_wr_any_0) begin
                for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_RD-1; ch_idx++) begin
                    if (rd_avalid_o[ch_idx] && (rd_addr_o[ch_idx][ADDR_BW-1] == 1'b0)) begin
                        M0_ren_r[0] = 1'b1;
                        M0_wsel_r[0] = rd_wsel_o[ch_idx];
                        wsel_tmp = rd_wsel_o[ch_idx][WSEL_BW-1-1:0];
                        if (rd_wsel_o[ch_idx][WSEL_BW-1] == 1'b0) begin
                            M0_en_r  [0][0:NUM_PE-1] = '{NUM_PE{1'b1}};
                            M0_we_r  [0][0:NUM_PE-1] = '{NUM_PE{1'b0}};
                            M0_addr_r[0][0:NUM_PE-1] = '{NUM_PE{rd_addr_o[ch_idx][ADDR_BW-1-1:0]}};
                            // M0_din_r [0][0:NUM_PE-1]
                        end else begin
                            M0_en_r  [0][wsel_tmp] = 1'b1;
                            M0_we_r  [0][wsel_tmp] = 1'b0;
                            M0_addr_r[0][wsel_tmp] = rd_addr_o[ch_idx][ADDR_BW-1-1:0];
                            // M0_din_r [0][wsel_tmp]
                        end
                        M0_ch_r[0] = ch_idx;
                        f_rd_pending[ch_idx] = 1'b0;
                        break;
                    end
                end
            end
            
        end

        // -------- Find a request to SRAM 1 --------

        f_wr_any_1 = 1'b0;

        if (!f_M1_pending) begin

            // Write request first
            for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_WR-1; ch_idx++) begin
                if (wr_avalid_o[ch_idx] && (wr_addr_o[ch_idx][ADDR_BW-1] == 1'b1)) begin
                    // M1_ren_r[0] = 1'b0;
                    // M1_wsel_r[0] = wr_wsel_o[ch_idx];
                    wsel_tmp = wr_wsel_o[ch_idx][WSEL_BW-1-1:0];
                    if (wr_wsel_o[ch_idx][WSEL_BW-1] == 1'b0) begin
                        M1_en_r  [0][0:NUM_PE-1] = '{NUM_PE{1'b1}};
                        M1_we_r  [0][0:NUM_PE-1] = '{NUM_PE{1'b1}};
                        M1_addr_r[0][0:NUM_PE-1] = '{NUM_PE{wr_addr_o[ch_idx][ADDR_BW-1-1:0]}};
                        M1_din_r [0][0:NUM_PE-1] = wr_din_o[ch_idx][0:NUM_PE-1];
                    end else begin
                        M1_en_r  [0][wsel_tmp] = 1'b1;
                        M1_we_r  [0][wsel_tmp] = 1'b1;
                        M1_addr_r[0][wsel_tmp] = wr_addr_o[ch_idx][ADDR_BW-1-1:0];
                        M1_din_r [0][wsel_tmp] = wr_din_o[ch_idx][wsel_tmp];
                    end
                    // M1_ch_r[0] = ch_idx;
                    f_wr_pending[ch_idx] = 1'b0;
                    f_wr_any_1 = 1'b1;
                    break;
                end
            end
            
            // Read request next
            if (!f_wr_any_1) begin
                for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_RD-1; ch_idx++) begin
                    if (rd_avalid_o[ch_idx] && (rd_addr_o[ch_idx][ADDR_BW-1] == 1'b1)) begin
                        M1_ren_r[0] = 1'b1;
                        M1_wsel_r[0] = rd_wsel_o[ch_idx];
                        wsel_tmp = rd_wsel_o[ch_idx][WSEL_BW-1-1:0];
                        if (rd_wsel_o[ch_idx][WSEL_BW-1] == 1'b0) begin
                            M1_en_r  [0][0:NUM_PE-1] = '{NUM_PE{1'b1}};
                            M1_we_r  [0][0:NUM_PE-1] = '{NUM_PE{1'b0}};
                            M1_addr_r[0][0:NUM_PE-1] = '{NUM_PE{rd_addr_o[ch_idx][ADDR_BW-1-1:0]}};
                            // M1_din_r [0][0:NUM_PE-1]
                        end else begin
                            M1_en_r  [0][wsel_tmp] = 1'b1;
                            M1_we_r  [0][wsel_tmp] = 1'b0;
                            M1_addr_r[0][wsel_tmp] = rd_addr_o[ch_idx][ADDR_BW-1-1:0];
                            // M1_din_r [0][wsel_tmp]
                        end
                        M1_ch_r[0] = ch_idx;
                        f_rd_pending[ch_idx] = 1'b0;
                        break;
                    end
                end
            end

        end

    end


    // ------------------------ SRAM request regs ------------------------
    // Buffer SRAM commands

    always_ff @(posedge clk) begin
        for (int unsigned ps_idx = 1; ps_idx <= BUF_MID_DEPTH; ps_idx++) begin
            if (!rstn) begin
                M0_en_r  [ps_idx] <= '{NUM_PE{'0}};
                M0_we_r  [ps_idx] <= '{NUM_PE{'0}};
                M0_addr_r[ps_idx] <= '{NUM_PE{'0}};
                M0_din_r [ps_idx] <= '{NUM_PE{'0}};
                M0_ch_r  [ps_idx] <= '0;
                M0_ren_r [ps_idx] <= 1'b0;
                M0_wsel_r[ps_idx] <= '0;
            end else if (!f_M0_pending) begin
                M0_en_r  [ps_idx] <= M0_en_r  [ps_idx-1];
                M0_we_r  [ps_idx] <= M0_we_r  [ps_idx-1];
                M0_addr_r[ps_idx] <= M0_addr_r[ps_idx-1];
                M0_din_r [ps_idx] <= M0_din_r [ps_idx-1];
                M0_ch_r  [ps_idx] <= M0_ch_r  [ps_idx-1];
                M0_ren_r [ps_idx] <= M0_ren_r [ps_idx-1];
                M0_wsel_r[ps_idx] <= M0_wsel_r[ps_idx-1];
            end
        end
    end

    always_ff @(posedge clk) begin
        for (int unsigned ps_idx = 1; ps_idx <= BUF_MID_DEPTH; ps_idx++) begin
            if (!rstn) begin
                M1_en_r  [ps_idx] <= '{NUM_PE{'0}};
                M1_we_r  [ps_idx] <= '{NUM_PE{'0}};
                M1_addr_r[ps_idx] <= '{NUM_PE{'0}};
                M1_din_r [ps_idx] <= '{NUM_PE{'0}};
                M1_ch_r  [ps_idx] <= '0;
                M1_ren_r [ps_idx] <= 1'b0;
                M1_wsel_r[ps_idx] <= '0;
            end else if (!f_M1_pending) begin
                M1_en_r  [ps_idx] <= M1_en_r  [ps_idx-1];
                M1_we_r  [ps_idx] <= M1_we_r  [ps_idx-1];
                M1_addr_r[ps_idx] <= M1_addr_r[ps_idx-1];
                M1_din_r [ps_idx] <= M1_din_r [ps_idx-1];
                M1_ch_r  [ps_idx] <= M1_ch_r  [ps_idx-1];
                M1_ren_r [ps_idx] <= M1_ren_r [ps_idx-1];
                M1_wsel_r[ps_idx] <= M1_wsel_r[ps_idx-1];
            end
        end
    end


    // ------------------------ SRAM instances ------------------------

    // ---------------- SRAM 0 ----------------

    always_comb begin
        for (int unsigned pe_idx = 0; pe_idx <= NUM_PE-1; pe_idx++) begin
            M0_en  [pe_idx] = M0_en_r  [BUF_MID_DEPTH][pe_idx] & ~f_M0_pending;
            M0_we  [pe_idx] = M0_we_r  [BUF_MID_DEPTH][pe_idx];
            M0_addr[pe_idx] = M0_addr_r[BUF_MID_DEPTH][pe_idx];
            M0_din [pe_idx] = M0_din_r [BUF_MID_DEPTH][pe_idx];
        end
    end

    generate
        for (genvar pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
            // (* ram_style = "block" *)
            BRAM_SP_NC #(
                .RAM_WIDTH       ( SMEM_WW         ),
                .RAM_DEPTH       ( SMEM_DEPTH >> 1 ),
                .RAM_PERFORMANCE ( "LOW_LATENCY"   ),
                .INIT_FILE       ( ""              )
            ) SMEM_0 (
                .clka            ( clk             ),
                .rsta            ( !rstn           ),
                .ena             ( M0_en  [pe_idx] ),
                .wea             ( M0_we  [pe_idx] ),
                .addra           ( M0_addr[pe_idx] ),
                .dina            ( M0_din [pe_idx] ),
                .regcea          (                 ),
                .douta           ( M0_dout[pe_idx] )
            );
        end
    endgenerate

    // generate
    //     for (genvar pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
    //         sram_sp_hsc_rvt_rvt_16384x16m32 SMEM_0 (
    //             .CLK            (   clk             ),
    //             .CEN            ( ! M0_en  [pe_idx] ),
    //             .WEN            ( ! M0_we  [pe_idx] ),
    //             .A              (   M0_addr[pe_idx] ),
    //             .D              (   M0_din [pe_idx] ),
    //             .Q              (   M0_dout[pe_idx] ),
    //             .EMA            (   '0              ),
    //             .EMAW           (   '0              ),
    //             .EMAS           (   1'b0            ),
    //             .TEN            ( ! 1'b0            ),
    //             .TA             (   '0              ),
    //             .TD             (   '0              ),
    //             .TCEN           ( ! 1'b0            ),
    //             .TWEN           ( ! 1'b0            ),
    //             .SI             (   '0              ),
    //             .SE             (   1'b0            ),
    //             .SO             (                   ),
    //             .AY             (                   ),
    //             .CENY           (                   ),
    //             .WENY           (                   ),
    //             .RET1N          (   1'b1            ),
    //             .DFTRAMBYP      (   1'b0            )
    //         );
    //     end
    // endgenerate

    // Extra reg to synchronize with M0_dout
    always_ff @(posedge clk) begin
        if (!rstn) begin
            M0_en_prev   <= '{NUM_PE{'0}};
            M0_we_prev   <= '{NUM_PE{'0}};
            M0_ch_prev   <= '0;
            M0_ren_prev  <= 1'b0;
            M0_wsel_prev <= '0;
        end else if (!f_M0_pending) begin
            M0_en_prev   <= M0_en_r  [BUF_MID_DEPTH];
            M0_we_prev   <= M0_we_r  [BUF_MID_DEPTH];
            M0_ch_prev   <= M0_ch_r  [BUF_MID_DEPTH];
            M0_ren_prev  <= M0_ren_r [BUF_MID_DEPTH];
            M0_wsel_prev <= M0_wsel_r[BUF_MID_DEPTH];
        end
    end

    // always_comb begin
    //     M0_ren_prev = 1'b0;
    //     for (int unsigned pe_idx = 0; pe_idx <= NUM_PE-1; pe_idx++) begin
    //         M0_ren_prev = M0_ren_prev | (M0_en_prev[pe_idx] & ~M0_we_prev[pe_idx]);
    //     end
    // end

    // ---------------- SRAM 1 ----------------

    always_comb begin
        for (int unsigned pe_idx = 0; pe_idx <= NUM_PE-1; pe_idx++) begin
            M1_en  [pe_idx] = M1_en_r  [BUF_MID_DEPTH][pe_idx] & ~f_M1_pending;
            M1_we  [pe_idx] = M1_we_r  [BUF_MID_DEPTH][pe_idx];
            M1_addr[pe_idx] = M1_addr_r[BUF_MID_DEPTH][pe_idx];
            M1_din [pe_idx] = M1_din_r [BUF_MID_DEPTH][pe_idx];
        end
    end

    generate
        for (genvar pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
            // (* ram_style = "block" *)
            BRAM_SP_NC #(
                .RAM_WIDTH       ( SMEM_WW         ),
                .RAM_DEPTH       ( SMEM_DEPTH >> 1 ),
                .RAM_PERFORMANCE ( "LOW_LATENCY"   ),
                .INIT_FILE       ( ""              )
            ) SMEM_1 (
                .clka            ( clk             ),
                .rsta            ( !rstn           ),
                .ena             ( M1_en  [pe_idx] ),
                .wea             ( M1_we  [pe_idx] ),
                .addra           ( M1_addr[pe_idx] ),
                .dina            ( M1_din [pe_idx] ),
                .regcea          (                 ),
                .douta           ( M1_dout[pe_idx] )
            );
        end
    endgenerate

    // generate
    //     for (genvar pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
    //         sram_sp_hsc_rvt_rvt_16384x16m32 SMEM_1 (
    //             .CLK            (   clk             ),
    //             .CEN            ( ! M1_en  [pe_idx] ),
    //             .WEN            ( ! M1_we  [pe_idx] ),
    //             .A              (   M1_addr[pe_idx] ),
    //             .D              (   M1_din [pe_idx] ),
    //             .Q              (   M1_dout[pe_idx] ),
    //             .EMA            (   '0              ),
    //             .EMAW           (   '0              ),
    //             .EMAS           (   1'b0            ),
    //             .TEN            ( ! 1'b0            ),
    //             .TA             (   '0              ),
    //             .TD             (   '0              ),
    //             .TCEN           ( ! 1'b0            ),
    //             .TWEN           ( ! 1'b0            ),
    //             .SI             (   '0              ),
    //             .SE             (   1'b0            ),
    //             .SO             (                   ),
    //             .AY             (                   ),
    //             .CENY           (                   ),
    //             .WENY           (                   ),
    //             .RET1N          (   1'b1            ),
    //             .DFTRAMBYP      (   1'b0            )
    //         );
    //     end
    // endgenerate

    // Extra reg to synchronize with M1_dout
    always_ff @(posedge clk) begin
        if (!rstn) begin
            M1_en_prev   <= '{NUM_PE{'0}};
            M1_we_prev   <= '{NUM_PE{'0}};
            M1_ch_prev   <= '0;
            M1_ren_prev  <= 1'b0;
            M1_wsel_prev <= '0;
        end else if (!f_M1_pending) begin
            M1_en_prev   <= M1_en_r  [BUF_MID_DEPTH];
            M1_we_prev   <= M1_we_r  [BUF_MID_DEPTH];
            M1_ch_prev   <= M1_ch_r  [BUF_MID_DEPTH];
            M1_ren_prev  <= M1_ren_r [BUF_MID_DEPTH];
            M1_wsel_prev <= M1_wsel_r[BUF_MID_DEPTH];
        end
    end

    // always_comb begin
    //     M1_ren_prev = 1'b0;
    //     for (int unsigned pe_idx = 0; pe_idx <= NUM_PE-1; pe_idx++) begin
    //         M1_ren_prev = M1_ren_prev | (M1_en_prev[pe_idx] & ~M1_we_prev[pe_idx]);
    //     end
    // end


    // ------------------------ Read channel outputs ------------------------

    // always_comb begin
    //     logic [CH_IDX_BW-1:0] ch_tmp;
    // 
    //     rd_dout_r  [0][NUM_CH_RD-1:0] = rd_dout_r[1][NUM_CH_RD-1:0];  // ???
    //     rd_dvalid_r[0][NUM_CH_RD-1:0] = '{NUM_CH_RD{'{NUM_PE{1'b0}}}};
    // 
    //     for (int unsigned pe_idx = 0; pe_idx <= NUM_PE-1; pe_idx++) begin
    //         if (M0_en_prev[pe_idx] && !M0_we_prev[pe_idx]) begin
    //             ch_tmp = M0_ch_prev;
    //             rd_dout_r  [0][ch_tmp][pe_idx] = M0_dout[pe_idx];
    //             rd_dvalid_r[0][ch_tmp][pe_idx] = 1'b1;
    //         end
    //         if (M1_en_prev[pe_idx] && !M1_we_prev[pe_idx]) begin
    //             ch_tmp = M1_ch_prev;
    //             rd_dout_r  [0][ch_tmp][pe_idx] = M1_dout[pe_idx];
    //             rd_dvalid_r[0][ch_tmp][pe_idx] = 1'b1;
    //         end
    //     end
    // end
    
    always_comb begin
        rd_dout_r   [0][NUM_CH_RD-1:0] = rd_dout_r[1][NUM_CH_RD-1:0];   // ???
        rd_dwsel_r  [0][NUM_CH_RD-1:0] = rd_dwsel_r[1][NUM_CH_RD-1:0];  // ???
        // rd_dstrobe_r[0][NUM_CH_RD-1:0] = '{NUM_CH_RD{'{NUM_PE{1'b0}}}};
        rd_dvalid_r [0][NUM_CH_RD-1:0] = '{NUM_CH_RD{{1'b0}}};

        f_M0_pending = M0_ren_prev;
        f_M1_pending = M1_ren_prev;

        // for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_RD-1; ch_idx++) begin
        //     if (rd_dready[ch_idx]) begin
        //         for (int unsigned pe_idx = 0; pe_idx <= NUM_PE-1; pe_idx++) begin
        //             if (ch_idx == M0_ch_prev) begin
        //                 // -------- Find a read output from SRAM 0 --------
        //                 if (M0_en_prev[pe_idx] && !M0_we_prev[pe_idx]) begin
        //                     rd_dout_r   [0][ch_idx][pe_idx] = M0_dout[pe_idx];
        //                     // rd_dstrobe_r[0][ch_idx][pe_idx] = 1'b1;
        //                     rd_dvalid_r [0][ch_idx] = 1'b1;
        //                     f_M0_pending = 1'b0;
        //                 end
        //             end else if (ch_idx == M1_ch_prev) begin
        //                 // -------- Find a read output from SRAM 1 --------
        //                 if (M1_en_prev[pe_idx] && !M1_we_prev[pe_idx]) begin
        //                     rd_dout_r   [0][ch_idx][pe_idx] = M1_dout[pe_idx];
        //                     // rd_dstrobe_r[0][ch_idx][pe_idx] = 1'b1;
        //                     rd_dvalid_r [0][ch_idx] = 1'b1;
        //                     f_M1_pending = 1'b0;
        //                 end
        //             end
        //         end
        //     end
        // end

        for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_RD-1; ch_idx++) begin
            if (rd_dready[ch_idx]) begin
                if (ch_idx == M0_ch_prev) begin
                    // -------- Find a read output from SRAM 0 --------
                    if (M0_ren_prev) begin
                        rd_dout_r   [0][ch_idx][0:NUM_PE-1] = M0_dout[0:NUM_PE-1];
                        rd_dwsel_r  [0][ch_idx] = M0_wsel_prev;
                        // for (int unsigned pe_idx = 0; pe_idx <= NUM_PE-1; pe_idx++) begin
                        //     rd_dstrobe_r[0][ch_idx][pe_idx] = M0_en_prev[pe_idx] && !M0_we_prev[pe_idx];
                        // end
                        rd_dvalid_r [0][ch_idx] = 1'b1;
                        f_M0_pending = 1'b0;
                    end
                end else if (ch_idx == M1_ch_prev) begin
                    // -------- Find a read output from SRAM 1 --------
                    if (M1_ren_prev) begin
                        rd_dout_r   [0][ch_idx][0:NUM_PE-1] = M1_dout[0:NUM_PE-1];
                        rd_dwsel_r  [0][ch_idx] = M1_wsel_prev;
                        // for (int unsigned pe_idx = 0; pe_idx <= NUM_PE-1; pe_idx++) begin
                        //     rd_dstrobe_r[0][ch_idx][pe_idx] = M1_en_prev[pe_idx] && !M1_we_prev[pe_idx];
                        // end
                        rd_dvalid_r [0][ch_idx] = 1'b1;
                        f_M1_pending = 1'b0;
                    end
                end
            end
        end
    end
    
    always_ff @(posedge clk) begin
        for (int unsigned ps_idx = 1; ps_idx <= BUF_OUT_DEPTH; ps_idx++) begin
            for (int unsigned ch_idx = 0; ch_idx <= NUM_CH_RD-1; ch_idx++) begin
                if (!rstn) begin
                    rd_dout_r   [ps_idx][ch_idx] <= '{NUM_PE{'0}};
                    rd_dwsel_r  [ps_idx][ch_idx] <= '0;
                    // rd_dstrobe_r[ps_idx][ch_idx] <= '{NUM_PE{'0}};
                    rd_dvalid_r [ps_idx][ch_idx] <= '0;
                end else if (rd_dready[ch_idx]) begin
                    rd_dout_r   [ps_idx][ch_idx] <= rd_dout_r   [ps_idx-1][ch_idx];
                    rd_dwsel_r  [ps_idx][ch_idx] <= rd_dwsel_r  [ps_idx-1][ch_idx];
                    // rd_dstrobe_r[ps_idx][ch_idx] <= rd_dstrobe_r[ps_idx-1][ch_idx];
                    rd_dvalid_r [ps_idx][ch_idx] <= rd_dvalid_r [ps_idx-1][ch_idx];
                end
            end
        end
    end
    
    assign rd_dout   [NUM_CH_RD-1:0] = rd_dout_r   [BUF_OUT_DEPTH][NUM_CH_RD-1:0];
    assign rd_dwsel  [NUM_CH_RD-1:0] = rd_dwsel_r  [BUF_OUT_DEPTH][NUM_CH_RD-1:0];
    // assign rd_dstrobe[NUM_CH_RD-1:0] = rd_dstrobe_r[BUF_OUT_DEPTH][NUM_CH_RD-1:0];
    assign rd_dvalid [NUM_CH_RD-1:0] = rd_dvalid_r [BUF_OUT_DEPTH][NUM_CH_RD-1:0];


endmodule
