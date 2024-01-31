
import definesPkg::*;

// SMEM Read Request Generator

// cfg_ready initialized to 1?
//           set to 1 only when cfg_valid==1?


module IPM_SRG #(
    // parameter NUM_PE        = 16,               //16
    // parameter MAX_N         = 256,              //1024
    // parameter MAX_M         = 256,              //32
    // parameter MAX_NoP       = MAX_N/NUM_PE,     //64

    parameter SMEM_WW       = 16,
    parameter SMEM_DEPTH    = MAX_M*MAX_NoP*4,

    localparam ADDR_BW      = $clog2(SMEM_DEPTH),       // MSB: bank(SRAM0/SRAM1)
    localparam WSEL_BW      = $clog2(NUM_PE) + 1        // {WordOp, WordIdx}
    // localparam NZL_HA_BW    = $clog2(MAX_NoP*MAX_M),    // NZL head address bit-width
    // localparam MAX_CNT      = (MAX_N>MAX_M)? (MAX_N):(MAX_M),
    // localparam NT_BW        = $clog2(MAX_M+1)
) (
    input  logic                        clk,
    input  logic                        rstn,
    
    input  logic                        cfg_valid,
    // input  PROC_t                       cfg_proc,
    // input  logic [NT_BW-1:0]            cfg_nt,
    // input  logic [$clog2(MAX_M)-1:0]    cfg_t,
    // input  logic [$clog2(MAX_CNT)-1:0]  cfg_cnt0,
    // input  logic [$clog2(MAX_CNT)-1:0]  cfg_cnt1,
    // input  logic [$clog2(MAX_CNT)-1:0]  cfg_cnt2,
    input  cfg_t                        cfg_data,
    output logic                        cfg_ready,

    input  logic [ADDR_BW-1:0]          smem_addr1,
    input  logic [ADDR_BW-1:0]          smem_addr2,
    input  logic [NZL_HA_BW-1:0]        nzl_head_addr,
    input  logic [$clog2(NUM_PE)-1:0]   nzl_head_peid,

    input  logic [$clog2(MAX_N)-1:0]    din_nzn,
    output logic                        pop_nzn,

    // ---------------- SMEM Read Channels ----------------
    output logic [WSEL_BW-1:0]          rd_wsel   [2:1],
    output logic [ADDR_BW-1:0]          rd_addr   [2:1],
    output logic                        rd_avalid [2:1],
    input  logic                        rd_aready [2:1]
    // input  logic [SMEM_WW-1:0]          rd_dout   [2:1][0:NUM_PE-1],
    // input  logic                        rd_dvalid [2:1][0:NUM_PE-1],
    // output logic                        rd_dready [2:1]
    
);


// -----------------------------------------------------------------------------
// Global variables

    // Overall - control signals
    logic                               rstn_init;
    
    // Overall - flags
    logic [0:1]                         f_O;
    logic [0:1]                         f_O_rd1;
    logic [0:1]                         f_O_rd2;
    
    // Input Signal
    PROC_t                              cfg_proc_r;
    logic [NT_BW-1:0]                   cfg_nt_r;
    logic [$clog2(MAX_M)-1:0]           cfg_t_r;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt0_r;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt1_r;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt2_r;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt0_r1;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt1_r1;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt2_r1;

    logic [ADDR_BW-1:0]                 smem_addr1_r;
    logic [ADDR_BW-1:0]                 smem_addr2_r;
    logic [NZL_HA_BW-1:0]               nzl_head_addr_r;
    logic [$clog2(NUM_PE)-1:0]          nzl_head_peid_r;

    // logic [$clog2(MAX_N)-1:0]           din_nzn_r;
    // logic [0:1]                         pop_nzn_r;

    logic                               ready_i_eff;

    // Output Signal
    logic [0:1]                         valid_o_r;
    logic [WSEL_BW-1:0]                 rd_wsel_r   [2:1];
    logic [ADDR_BW-1:0]                 rd_addr_r   [2:1];
    logic                               rd_avalid_r [2:1];
    
    // FSM - states
    // (* mark_debug = "true" *)
    enum logic [1:0] {S_IDLE, S_INIT, S_GEN} state;
    logic                               f_proc_end;
    
    // SMEM Data I/O Counters
    logic [$clog2(MAX_CNT)-1:0]         cnt0;   // Inner most loop
    logic [$clog2(MAX_CNT)-1:0]         cnt1;
    logic [$clog2(MAX_CNT)-1:0]         cnt2;   // Outer most loop
    logic                               f_cnt_o;
    logic [0:1]                         f_cnt_o_r;

    // NZL Address Counters
    logic [NZL_HA_BW-1:0]               nzv_addr;
    logic [$clog2(NUM_PE)-1:0]          nzv_peid;
    
    
// -----------------------------------------------------------------------------
// Module body

    
    // FSM
    always_ff @(posedge clk) begin
        if (!rstn) begin
            state <= S_IDLE;
        end else begin
            case (state) inside
    
                S_IDLE : begin              // Idle
                    if (cfg_valid) begin
                        state <= S_INIT;
                    end
                end
                
                S_INIT : begin              // Initialize
                    state <= S_GEN;
                end
                
                S_GEN : begin
                    if (f_proc_end) begin
                        state <= S_IDLE;
                    end
                end

                default : begin
                    state <= S_IDLE;
                end

            endcase
        end
    end
    
    assign f_proc_end = f_cnt_o_r[1] && valid_o_r[1] && ready_i_eff;
    
    
    
    // Configure Signals

    always_ff @(posedge clk) begin
        if (!rstn) begin
            cfg_ready <= 1'b1;
        end else begin
            case (state) inside
                // // Assert when there is a valid cfg. Deassert at the next cc.
                // // Should be initialized to 0.
                // S_IDLE : begin
                //     if (cfg_valid) begin
                //         cfg_ready <= 1'b1;
                //     end
                // end
                // ???: Deassert when a procedure is started
                S_IDLE : begin
                    if (cfg_valid) begin
                        cfg_ready <= 1'b0;
                    end
                end
                // Assert when a procedure is finished
                S_GEN : begin
                    if (f_proc_end) begin
                        cfg_ready <= 1'b1;
                    end
                end
                default : begin
                    cfg_ready <= 1'b0;
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (!rstn) begin
            cfg_proc_r <= PROC_IDLE;
        end else begin
            case (state) inside
                S_IDLE : begin
                    if (cfg_valid) begin
                        cfg_proc_r <= cfg_data.proc;
                    end
                end
                S_GEN : begin
                    if (f_proc_end) begin
                        cfg_proc_r <= PROC_IDLE;
                    end
                end
                default : begin
                    cfg_proc_r <= cfg_proc_r;
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (!rstn) begin
            cfg_nt_r        <= '0;
            cfg_t_r         <= '0;
            cfg_cnt0_r1     <= '0;
            cfg_cnt1_r1     <= '0;
            cfg_cnt2_r1     <= '0;
            smem_addr1_r    <= '0;
            smem_addr2_r    <= '0;
            nzl_head_addr_r <= '0;
            nzl_head_peid_r <= '0;
        end else if ((state == S_IDLE) && cfg_valid) begin
            cfg_nt_r        <= cfg_data.nt;
            cfg_t_r         <= cfg_data.t;
            cfg_cnt0_r1     <= cfg_data.cnt0;
            cfg_cnt1_r1     <= cfg_data.cnt1;
            cfg_cnt2_r1     <= cfg_data.cnt2;
            smem_addr1_r    <= smem_addr1;
            smem_addr2_r    <= smem_addr2;
            nzl_head_addr_r <= nzl_head_addr;
            nzl_head_peid_r <= nzl_head_peid;
        end
    end

    always_ff @(posedge clk) begin
        if (!rstn) begin
            cfg_cnt0_r <= '0;
            cfg_cnt1_r <= '0;
            cfg_cnt2_r <= '0;
        end else begin
            case (cfg_proc_r) inside
                PROC_MxV, PROC_MTxV, PROC_VXV : begin
                    if (state == S_INIT) begin
                        cfg_cnt0_r <= cfg_cnt0_r1;
                        cfg_cnt1_r <= cfg_cnt1_r1;
                        cfg_cnt2_r <= cfg_cnt2_r1;
                    end
                end
                PROC_MxV_SP : begin
                    if (state == S_INIT) begin
                        cfg_cnt0_r <= cfg_cnt0_r1;
                        cfg_cnt1_r <= din_nzn;
                        cfg_cnt2_r <= cfg_cnt2_r1;
                    end
                end
                PROC_MTxV_SP : begin
                    if (state == S_INIT) begin
                        cfg_cnt0_r <= cfg_cnt0_r1;
                        cfg_cnt1_r <= cfg_cnt1_r1;
                        cfg_cnt2_r <= din_nzn;
                    end
                end
                PROC_VXV_SP : begin
                    if (state == S_INIT) begin
                        cfg_cnt0_r <= din_nzn;
                        cfg_cnt1_r <= cfg_cnt1_r1;
                        cfg_cnt2_r <= cfg_cnt2_r1;
                    end else if (valid_o_r[0] && (cnt0 == cfg_cnt0_r) && !f_cnt_o && ready_i_eff) begin
                        cfg_cnt0_r <= din_nzn;
                    end
                end
                default : begin
                    if (state == S_INIT) begin
                        cfg_cnt0_r <= cfg_cnt0_r1;
                        cfg_cnt1_r <= cfg_cnt1_r1;
                        cfg_cnt2_r <= cfg_cnt2_r1;
                    end
                end
            endcase
        end
    end

    // (!) Not registered
    // (!) No empty check
    always_comb begin
        pop_nzn = 1'b0;
        case (cfg_proc_r) inside
            PROC_MxV_SP : begin
                if (state == S_INIT) begin
                    pop_nzn = 1'b1;
                end
            end
            PROC_MTxV_SP : begin
                if (state == S_INIT) begin
                    pop_nzn = 1'b1;
                end
            end
            PROC_VXV_SP : begin
                if (state == S_INIT) begin
                    pop_nzn = 1'b1;
                end else if (valid_o_r[0] && (cnt0 == cfg_cnt0_r) && !f_cnt_o && ready_i_eff) begin   // S_GEN
                    pop_nzn = 1'b1;
                end
            end
            default : begin
                if (state == S_INIT) begin
                    pop_nzn = 1'b0;
                end
            end
        endcase
    end



    // Control Signals
    
    assign ready_i_eff = rd_aready[2] && rd_aready[1];  // TODO

    assign valid_o_r[0] = f_O[0];
    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            valid_o_r[1] <= 1'b0;
        end else if (ready_i_eff) begin
            valid_o_r[1] <= valid_o_r[0];
        end
    end
    


    // assign rstn_init = !(state == S_INIT);
    always_ff @(posedge clk) begin
        if (!rstn) begin
            rstn_init <= 1'b1;
        end else begin
            if ((state == S_IDLE) && cfg_valid) begin
                rstn_init <= 1'b0;
            end else begin
                rstn_init <= 1'b1;
            end
        end
    end
    
    
    
    // Flags

    // Flag - Overall output
    always_ff @(posedge clk) begin
        if (!rstn) begin
            f_O[0] <= 1'b0;
        end else begin
            case (state) inside
                // Assert at transition S_INIT -> S_GEN
                S_INIT : begin
                    f_O[0] <= 1'b1;
                end
                // Deassert at transition S_GEN -> S_IDLE
                S_GEN : begin
                    if (f_cnt_o_r[0] && valid_o_r[0] && ready_i_eff) begin
                        f_O[0] <= 1'b0;
                    end
                end
                default : begin
                    f_O[0] <= 1'b0;
                end
            endcase
        end
    end
    
    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            f_O[1] <= '0;
        end else if ((valid_o_r[0] || valid_o_r[1]) && ready_i_eff) begin
            f_O[1] <= f_O[0];
        end
    end
    
    // Flag - SMEM Read Channel 1
    always_ff @(posedge clk) begin
        if (!rstn) begin
            f_O_rd1[0] <= 1'b0;
        end else begin
            case (state) inside
                // Assert at transition S_INIT -> S_GEN
                S_INIT : begin
                    case (cfg_proc_r) inside
                        PROC_MxV, PROC_MTxV, PROC_VXV          : f_O_rd1[0] <= 1'b1;
                        PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP : f_O_rd1[0] <= 1'b1;
                        default                                : f_O_rd1[0] <= 1'b0;
                    endcase
                end
                // Deassert at transition S_GEN -> S_IDLE
                S_GEN : begin
                    if (f_cnt_o_r[0] && valid_o_r[0] && ready_i_eff) begin
                        f_O_rd1[0] <= 1'b0;
                    end
                end
                default : begin
                    f_O_rd1[0] <= 1'b0;
                end
            endcase
        end
    end
    
    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            f_O_rd1[1] <= '0;
        end else if ((valid_o_r[0] || valid_o_r[1]) && ready_i_eff) begin
            f_O_rd1[1] <= f_O_rd1[0];
        end
    end
    
    // Flag - SMEM Read Channel 2
    always_ff @(posedge clk) begin
        if (!rstn) begin
            f_O_rd2[0] <= 1'b0;
        end else begin
            case (state) inside
                // Assert at transition S_INIT -> S_GEN
                S_INIT : begin
                    case (cfg_proc_r)
                        default : f_O_rd2[0] <= 1'b0;
                    endcase
                end
                // Deassert at transition S_GEN -> S_IDLE
                S_GEN : begin
                    if (f_cnt_o_r[0] && valid_o_r[0] && ready_i_eff) begin
                        f_O_rd2[0] <= 1'b0;
                    end
                end
                default : begin
                    f_O_rd2[0] <= 1'b0;
                end
            endcase
        end
    end
    
    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            f_O_rd2[1] <= '0;
        end else if ((valid_o_r[0] || valid_o_r[1]) && ready_i_eff) begin
            f_O_rd2[1] <= f_O_rd2[0];
        end
    end
    
    
    
    // SMEM Data Counters
    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            cnt0 <= 0;
            cnt1 <= 0;
            cnt2 <= 0;
        end else if (valid_o_r[0] && ready_i_eff) begin
            if (cnt0 == cfg_cnt0_r) begin
                if (cnt1 == cfg_cnt1_r) begin
                    if (cnt2 == cfg_cnt2_r) begin
                        cnt2 <= 0;
                    end else begin
                        cnt2 <= cnt2 + 1;
                    end
                    cnt1 <= 0;
                end else begin
                    cnt1 <= cnt1 + 1;
                end
                cnt0 <= 0;
            end else begin
                cnt0 <= cnt0 + 1;
            end
        end
    end
    
    assign f_cnt_o = (cnt2 == cfg_cnt2_r) && (cnt1 == cfg_cnt1_r) && (cnt0 == cfg_cnt0_r);
    
    assign f_cnt_o_r[0] = f_cnt_o && valid_o_r[0];
    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            f_cnt_o_r[1] <= '0;
        end else if ((valid_o_r[0] || valid_o_r[1]) && ready_i_eff) begin
            f_cnt_o_r[1] <= f_cnt_o_r[0];
        end
    end
    
    
    // NZL address counters
    always_ff @(posedge clk) begin
        // if (!rstn) begin
        //     nzv_addr <= '0;
        //     nzv_peid <= '0;
        // end else
        if (!rstn_init) begin
            nzv_addr <= nzl_head_addr_r;
            nzv_peid <= nzl_head_peid_r;
        end else if (valid_o_r[0] && ready_i_eff) begin     // MxV_SP, VXV_SP
            if ((cnt1 == cfg_cnt1_r) && (cnt0 == cfg_cnt0_r)) begin
                nzv_addr <= nzl_head_addr_r;
                nzv_peid <= nzl_head_peid_r;
            end else begin
                if (nzv_peid == '1) begin
                    nzv_addr <= nzv_addr + 1;
                end
                nzv_peid <= nzv_peid + 1;
            end
        end
    end
    


    // SMEM Read Channel 1 - read request signals
    always_comb begin
        case (cfg_proc_r)
            PROC_MxV : begin
                rd_avalid_r[1] = f_O_rd1[0];
                rd_wsel_r[1] = {1'b1, cnt1[$clog2(NUM_PE)-1:0]};                                // N_(l-1) mod Np
                // rd_addr_r[1] = smem_addr1_r + {cnt1 >> $clog2(NUM_PE), cnt0[$clog2(MAX_M)-1:0]};  // Nt===MaxNt
                rd_addr_r[1] = smem_addr1_r + (cnt1 >> $clog2(NUM_PE)) * cfg_nt_r + cnt0;
            end
            PROC_MTxV : begin
                rd_avalid_r[1] = f_O_rd1[0];
                rd_wsel_r[1] = '0;
                // rd_addr_r[1] = smem_addr1_r + {cnt1,                   cnt0[$clog2(MAX_M)-1:0]};  // Nt===MaxNt
                rd_addr_r[1] = smem_addr1_r + cnt1 * cfg_nt_r + cnt0;
            end
            PROC_VXV : begin
                rd_avalid_r[1] = f_O_rd1[0];
                rd_wsel_r[1] = {1'b1, cnt0[$clog2(NUM_PE)-1:0]};                                // N_(l-1) mod Np
                // rd_addr_r[1] = smem_addr1_r + {cnt0 >> $clog2(NUM_PE), cnt1[$clog2(MAX_M)-1:0]};  // Nt===MaxNt
                rd_addr_r[1] = smem_addr1_r + (cnt0 >> $clog2(NUM_PE)) * cfg_nt_r + cnt1;
            end

            PROC_MxV_SP : begin
                rd_avalid_r[1] = f_O_rd1[0];
                rd_wsel_r[1] = {1'b1, nzv_peid};
                rd_addr_r[1] = smem_addr1_r + nzv_addr;
            end
            PROC_MTxV_SP : begin
                rd_avalid_r[1] = f_O_rd1[0];
                rd_wsel_r[1] = '0;
                // rd_addr_r[1] = smem_addr1_r + {cnt1, cfg_t_r};  // Use current t    // Nt===MaxNt
                rd_addr_r[1] = smem_addr1_r + cnt1 * cfg_nt_r + cfg_t_r;  // Use current t
                // rd_addr_r[1] = smem_addr1_r + cnt1;
            end
            PROC_VXV_SP : begin
                rd_avalid_r[1] = f_O_rd1[0];
                rd_wsel_r[1] = {1'b1, nzv_peid};
                rd_addr_r[1] = smem_addr1_r + nzv_addr;
            end

            default : begin
                rd_avalid_r[1] = 1'b0;
                rd_wsel_r[1] = '0;
                rd_addr_r[1] = '0;
            end
        endcase
    end
    
    // SMEM Read Channel 2 - read request signals
    always_comb begin
        case (cfg_proc_r)
            default : begin
                rd_avalid_r[2] = 1'b0;
                rd_wsel_r[2] = '0;
                rd_addr_r[2] = '0;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        for (int unsigned ch_idx = 1; ch_idx <= 2; ch_idx++) begin
            if (!rstn || !rstn_init) begin
                rd_avalid[ch_idx] <= '0;
                rd_wsel[ch_idx] <= '0;
                rd_addr[ch_idx] <= '0;
            end else if (ready_i_eff) begin
                rd_avalid[ch_idx] <= rd_avalid_r[ch_idx];
                if (rd_avalid_r[ch_idx]) begin
                    rd_wsel[ch_idx] <= rd_wsel_r[ch_idx];
                    rd_addr[ch_idx] <= rd_addr_r[ch_idx];
                end
            end
        end
    end



endmodule
