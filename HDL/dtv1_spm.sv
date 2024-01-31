
import definesPkg::*;

// Sparse Data Descriptor Memory

//                 Width                   Depth
// nzl_head_addr   $clog2(MAX_NoP*MAX_M)   Nt*NUM_NZL
// nzl_head_peid   $clog2(NUM_PE)          Nt*NUM_NZL
// nzn             $clog2(MAX_N)           Nt*NUM_NZL

// NUM_PE=64, MAX_N=256, MAX_M=256, NUM_NZL=2:
// (10 + 6 + 8) * 256 * 2 = 12288 bit
//           32 * 256 * 2 = 16384 bit

// Pipeline Stages:
// 0: cnt*, spm_rd_addr, spm_rd_en
// 1: spm_rd_regce
// 2: spm_rd_data, dout

// Only output nzl_head_addr and nzl_head_peid when ((cnt2 == 0) && (cnt1 == 0))

// Modified for dtv1.0_perf_estm:
//   Register cfg_cnt0/cfg_cnt1/cfg_cnt2 to cfg_cnt1_r/cfg_cnt2_r according to cfg_proc
//   Output cfg_data_o, cfg_valid_o
//   (!) Use nzn_ready_i for both cfg_data_o and dout_nzn


module IPM_SPM #(
    // parameter NUM_PE        = 16,               //16
    // parameter MAX_N         = 256,              //1024
    // parameter MAX_M         = 256,              //32
    // parameter MAX_NoP       = MAX_N/NUM_PE,     //64

    parameter SPM_WW        = $clog2(MAX_NoP*MAX_M) + $clog2(NUM_PE) + $clog2(MAX_N),
    parameter SPM_DEPTH     = MAX_M * 2,

    localparam SPM_ADDR_BW  = $clog2(SPM_DEPTH)
    // localparam NZL_HA_BW    = $clog2(MAX_NoP*MAX_M),    // NZL head address bit-width
    // localparam MAX_CNT      = (MAX_N>MAX_M)? (MAX_N):(MAX_M)
) (
    input  logic                        clk,
    input  logic                        rstn,
    
    // ---------------- Config ----------------
    input  logic                        cfg_valid,
    // input  PROC_t                       cfg_proc,
    // // input  logic [$clog2(MAX_M)-1:0]    cfg_nt,
    // input  logic [$clog2(MAX_M)-1:0]    cfg_t,
    // input  logic [$clog2(MAX_CNT)-1:0]  cfg_cnt0,
    // input  logic [$clog2(MAX_CNT)-1:0]  cfg_cnt1,
    // input  logic [$clog2(MAX_CNT)-1:0]  cfg_cnt2,
    input  cfg_t                        cfg_data,
    output logic                        cfg_ready,

    input  logic [SPM_ADDR_BW-1:0]      spm_addr,
    
    // ---------------- SPM Read Port ----------------
    output logic                        spm_rd_en,
    output logic [SPM_ADDR_BW-1:0]      spm_rd_addr,
    input  logic [SPM_WW-1:0]           spm_rd_data,
    output logic                        spm_rd_regce,
    output logic                        spm_rd_rstn,

    // ---------------- Output Data ----------------
    output logic                        nzn_valid_o,
    input  logic                        nzn_ready_i,
    output logic [$clog2(MAX_N)-1:0]    dout_nzn,
    output logic                        cfg_valid_o,
    input  logic                        cfg_ready_i,
    output cfg_t                        cfg_data_o,
    output logic [NZL_HA_BW-1:0]        nzl_head_addr,
    output logic [$clog2(NUM_PE)-1:0]   nzl_head_peid

);


// -----------------------------------------------------------------------------
// Global variables

    // ---------------- Overall ----------------
    // Control signals
    logic                               rstn_init;
    
    // Flags
    logic [0:2]                         f_O;
    
    // ---------------- Input Signals ----------------
    PROC_t                              cfg_proc_r;
    // logic [$clog2(MAX_M)-1:0]           cfg_nt_r;
    logic [$clog2(MAX_M)-1:0]           cfg_t_r;
    // logic [$clog2(MAX_CNT)-1:0]         cfg_cnt0_r;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt1_r;         // Nt
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt2_r;         // N[l]/Np
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt0_r1;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt1_r1;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt2_r1;

    logic [SPM_ADDR_BW-1:0]             spm_addr_r;

    logic                               ready_i_eff;

    // ---------------- Output Signals ----------------
    logic [0:2]                         valid_o_r;
    // logic [NZL_HA_BW-1:0]               nzl_head_addr_r[0:1];
    // logic [$clog2(NUM_PE)-1:0]          nzl_head_peid_r[0:1];
    cfg_t                               cfg_data_r[0:2];
    logic [0:2]                         cfg_o_en_r;
    
    // ---------------- FSM ----------------
    // (* mark_debug = "true" *)
    enum logic [1:0] {S_IDLE, S_INIT, S_GEN} state;
    logic                               f_proc_end;
    
    // ---------------- SPM I/O Counter ----------------
    // logic [$clog2(MAX_CNT)-1:0]         cnt0;   // Inner most loop
    logic [$clog2(MAX_CNT)-1:0]         cnt1;
    logic [$clog2(MAX_CNT)-1:0]         cnt2;   // Outer most loop
    logic                               f_cnt_o;
    logic [0:2]                         f_cnt_o_r;

    // ---------------- SPM Read Port ----------------
    logic                               spm_rd_en_r[0:2];
    logic [SPM_ADDR_BW-1:0]             spm_rd_addr_r[0:0];
    logic [SPM_WW-1:0]                  spm_rd_data_r[0:0];
    logic                               spm_rd_valid;

    // ---------------- SPM Output Broadcast ----------------
    logic                               cfg_valid_o_s;
    logic                               nzn_valid_o_s;
    logic                               s_tvalid;
    logic                               s_tready;
    logic [1:0]                         m_ready_d;
    logic [1:0]                         m_tvalid;
    logic [1:0]                         m_tready;

    
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
                    if (cfg_proc_r inside {PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP})
                        state <= S_GEN;
                    else
                        state <= S_IDLE;
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
    
    assign f_proc_end = f_cnt_o_r[2] && valid_o_r[2] && ready_i_eff;

    
    
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
                S_INIT : begin
                    if (!(cfg_proc_r inside {PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP})) begin
                        cfg_proc_r <= PROC_IDLE;
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
            // cfg_nt_r        <= '0;
            cfg_t_r         <= '0;
            cfg_cnt0_r1     <= '0;
            cfg_cnt1_r1     <= '0;
            cfg_cnt2_r1     <= '0;
            spm_addr_r      <= '0;
        end else if ((state == S_IDLE) && cfg_valid) begin
            // cfg_nt_r        <= cfg_nt;
            cfg_t_r         <= cfg_data.t;
            cfg_cnt0_r1     <= cfg_data.cnt0;
            cfg_cnt1_r1     <= cfg_data.cnt1;
            cfg_cnt2_r1     <= cfg_data.cnt2;
            spm_addr_r      <= spm_addr;
        end
    end

    always_ff @(posedge clk) begin
        if (!rstn) begin
            // cfg_cnt0_r <= '0;
            cfg_cnt1_r <= '0;
            cfg_cnt2_r <= '0;
        end else if (state == S_INIT) begin
            // cfg_cnt0_r <= cfg_cnt0_r1;
            case (cfg_proc_r)
                PROC_MxV_SP : begin
                    cfg_cnt1_r <= cfg_cnt0_r1;      // Nt
                    cfg_cnt2_r <= cfg_cnt2_r1;      // N[l]/Np
                end
                PROC_MTxV_SP : begin
                    cfg_cnt1_r <= cfg_cnt0_r1;      // Nt
                    cfg_cnt2_r <= cfg_cnt1_r1;      // N[l]/Np
                end
                PROC_VXV_SP : begin
                    cfg_cnt1_r <= cfg_cnt1_r1;      // Nt
                    cfg_cnt2_r <= cfg_cnt2_r1;      // N[l]/Np
                end
            endcase
        end
    end



    // Control Signals
    
    assign ready_i_eff = s_tready;  // TODO

    assign valid_o_r[0] = f_O[0];
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 2; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                valid_o_r[ps_idx] <= 1'b0;
            end else if (ready_i_eff) begin
                valid_o_r[ps_idx] <= valid_o_r[ps_idx-1];
            end
        end
    end

    // always_comb begin
    //     case (cfg_proc_r) inside
    //         PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP : begin
    //             valid_o = valid_o_r[2];
    //         end
    //         default : begin
    //             valid_o = 1'b0;
    //         end
    //     endcase
    // end
    // assign valid_o = spm_rd_valid;
    assign nzn_valid_o_s = spm_rd_valid;
    


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
                    if (cfg_proc_r inside {PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP}) begin
                        f_O[0] <= 1'b1;
                    end
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
        for (int ps_idx = 1; ps_idx <= 2; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                f_O[ps_idx] <= '0;
            end else if ((valid_o_r[ps_idx-1] || valid_o_r[ps_idx]) && ready_i_eff) begin
                f_O[ps_idx] <= f_O[ps_idx-1];
            end
        end
    end
    
    
    
    // SMEM Data Counters
    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            // cnt0 <= 0;
            cnt1 <= 0;
            cnt2 <= 0;
        end else if (valid_o_r[0] && ready_i_eff) begin
            // if (cnt0 == cfg_cnt0_r) begin
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
            //     cnt0 <= 0;
            // end else begin
            //     cnt0 <= cnt0 + 1;
            // end
        end
    end
    
    assign f_cnt_o = (cnt2 == cfg_cnt2_r) && (cnt1 == cfg_cnt1_r); // && (cnt0 == cfg_cnt0_r);
    
    assign f_cnt_o_r[0] = f_cnt_o && valid_o_r[0];
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 2; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                f_cnt_o_r[ps_idx] <= '0;
            end else if ((valid_o_r[ps_idx-1] || valid_o_r[ps_idx]) && ready_i_eff) begin
                f_cnt_o_r[ps_idx] <= f_cnt_o_r[ps_idx-1];
            end
        end
    end
    


    // SPM Memory
    assign spm_rd_rstn = rstn_init;
    
    // SPM Read Port
    always_comb begin
        case (cfg_proc_r)
            PROC_MxV_SP : begin
                cfg_o_en_r[0] = (cnt2 == 0) && (cnt1 == 0);
                spm_rd_en_r[0] = (cnt2 == 0);
                spm_rd_addr_r[0] = spm_addr_r + cfg_t_r;
            end
            PROC_MTxV_SP : begin
                cfg_o_en_r[0] = (cnt2 == 0) && (cnt1 == 0);
                spm_rd_en_r[0] = (cnt2 == 0);
                spm_rd_addr_r[0] = spm_addr_r + cfg_t_r;
            end
            PROC_VXV_SP : begin
                cfg_o_en_r[0] = (cnt2 == 0) && (cnt1 == 0);
                spm_rd_en_r[0] = 1'b1;
                spm_rd_addr_r[0] = spm_addr_r + cnt1;
            end

            default : begin
                cfg_o_en_r[0] = 1'b0;
                spm_rd_en_r[0] = 1'b0;
                spm_rd_addr_r[0] = '0;
            end
        endcase
    end

    assign spm_rd_en = spm_rd_en_r[0] && valid_o_r[0] && ready_i_eff;
    assign spm_rd_addr = spm_rd_addr_r[0];
    assign spm_rd_regce = spm_rd_en_r[1] && valid_o_r[1] && ready_i_eff;
    assign spm_rd_valid = spm_rd_en_r[2] && valid_o_r[2];

    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 2; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                spm_rd_en_r[ps_idx] <= '0;
            end else if (valid_o_r[ps_idx-1] && ready_i_eff) begin
                spm_rd_en_r[ps_idx] <= spm_rd_en_r[ps_idx-1];
            end
        end
    end



    // CFG Output
    assign cfg_valid_o_s = cfg_o_en_r[2] && valid_o_r[2];
    
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 2; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                cfg_o_en_r[ps_idx] <= '0;
            end else if (valid_o_r[ps_idx-1] && ready_i_eff) begin
                cfg_o_en_r[ps_idx] <= cfg_o_en_r[ps_idx-1];
            end
        end
    end
    
    assign cfg_data_r[0] = cfg_data;

    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 2; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                cfg_data_r[ps_idx] <= '0;
            end else if (valid_o_r[ps_idx-1] && ready_i_eff) begin
                cfg_data_r[ps_idx] <= cfg_data_r[ps_idx-1];
            end
        end
    end
    
    always_comb begin
        cfg_data_o = cfg_data_r[2];
        // cfg_data_o.nzl_head_addr = nzl_head_addr;
        // cfg_data_o.nzl_head_peid = nzl_head_peid;
    end



    // Output Data
    
    always_ff @(posedge clk) begin
        if (!rstn) begin
            spm_rd_data_r[0] <= '0;
        end else if (spm_rd_regce) begin
            case (cfg_proc_r) inside
                PROC_MxV_SP, PROC_MTxV_SP :
                    spm_rd_data_r[0] <= spm_rd_data;
                PROC_VXV_SP :                                           // LHA, LHP = 0
                    spm_rd_data_r[0] <= spm_rd_data[$clog2(MAX_N)-1:0]; // Fill MSB with 0?
            endcase
        end
    end

    assign {nzl_head_addr, nzl_head_peid, dout_nzn} = spm_rd_data_r[0];


    // Output Broadcast

    assign s_tvalid = cfg_valid_o_s && nzn_valid_o_s;
    
    always_ff @(posedge clk) begin
        if (!rstn) begin
            m_ready_d <= 2'b0;
        end else begin
            if (s_tready) begin
                m_ready_d <= 2'b0;
            end else begin
                m_ready_d <= m_ready_d | (m_tvalid & m_tready);
            end
        end
    end

    assign s_tready = &(m_ready_d | m_tready);
    // assign m_tvalid = {2{s_tvalid}} & ~m_ready_d;                   // ???
    assign m_tvalid = {cfg_valid_o_s, nzn_valid_o_s} & ~m_ready_d;  // ???

    assign {cfg_valid_o, nzn_valid_o} = m_tvalid;
    assign m_tready = {cfg_ready_i, nzn_ready_i};


endmodule
