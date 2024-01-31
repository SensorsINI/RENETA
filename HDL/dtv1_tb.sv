`timescale 1ns/1ps

import definesPkg::*;

// `define TVALID_I_RND
// `define TREADY_I_RND


// (!) NZI HIST not checked for MxV_SP MTxV_SP
// (!) VXV_SP: Force nzl_head_addr and nzl_head_peid to be 0 for IPM_SRG0 and IPM_SRG
//             Pad NZIL and NZVL for the last timestep
//             Reset LMEM_MAC


// -----------------------------------------------------------------------------

module tb_DTv1;

    // ---------------- Overall parameters ----------------
    // parameter NUM_PE        = 16;           //16
    // parameter MAX_N         = 256; //8;     //1024
    // parameter MAX_M         = 256; //4;     //32
    // parameter MAX_NoP       = MAX_N/NUM_PE; //64

    // FXP16
    parameter WEIGHT_QM     = 16;
    parameter WEIGHT_QN     = 0;
    parameter ACT_QM        = 16;
    parameter ACT_QN        = 0;

    // BFP16: (7,8)
    // parameter sig_width     = 7;
    // parameter exp_width     = 8;
    // parameter ieee_compliance = 1;
    
    // ---------------- DRAM ----------------
    parameter DRAM_WW       = 16;
    parameter DRAM_WIDTH    = DRAM_WW*NUM_PE;
    parameter DRAM_DEPTH    = MAX_N*MAX_NoP*1;

    // localparam DRAM_ADDR_BW = $clog2(DRAM_DEPTH);

    // ---------------- SPM ----------------
    parameter SPM_WW        = $clog2(MAX_NoP*MAX_M) + $clog2(NUM_PE) + $clog2(MAX_N);
    parameter SPM_DEPTH     = MAX_M * 2;

    localparam SPM_ADDR_BW  = $clog2(SPM_DEPTH);
    // localparam NZL_HA_BW    = $clog2(MAX_NoP*MAX_M);    // NZL head address bit-width
    // localparam MAX_CNT      = (MAX_N>MAX_M)? (MAX_N):(MAX_M);
    // localparam NT_BW        = $clog2(MAX_M+1);

    // ---------------- IPM_DRG ----------------
    parameter AXI_DM_CMD_WIDTH  = 72;
    parameter DRAM_ADDR_BW      = 32;
    parameter BTT_BW            = 23;
    parameter AXI_DM_CMD_BASE   = 32'h4080_0000;

    // ---------------- SMEM ----------------
    parameter SMEM_WW       = 16;
    parameter SMEM_DEPTH    = MAX_M*MAX_NoP*2;
    
    parameter NUM_CH_RD     = 3;    // 3
    parameter NUM_CH_WR     = 2;    // 2

    parameter SMEM_BUF_IN_DEPTH  = 4;
    parameter SMEM_BUF_MID_DEPTH = 1;
    parameter SMEM_BUF_OUT_DEPTH = 1;

    localparam SMEM_ADDR_BW = $clog2(SMEM_DEPTH);       // MSB: bank(SRAM0/SRAM1)
    localparam WSEL_BW      = $clog2(NUM_PE) + 1;       // {WordOp, WordIdx}

    // ---------------- CCM ----------------
    // parameter NUM_FUNC      = 4;                //2
    parameter LMEM_MAC_DEPTH = (MAX_M>MAX_N)? (MAX_M):(MAX_N);
    parameter LMEM_ACC_DEPTH = MAX_M;           //32
    
    // localparam WEIGHT_BW    = 1 + exp_width + sig_width;
    // localparam ACT_BW       = 1 + exp_width + sig_width;
    // localparam ACC_BW       = 1 + exp_width + sig_width;
    // localparam MAX_CNT      = (MAX_N>MAX_M)? (MAX_N):(MAX_M);
    
    // ---------------- IPM_SRG0 CFG FIFO parameters ----------------
    localparam SRG0_CFG_FIFO_WIDTH  = CFG_BW + NZL_HA_BW + $clog2(NUM_PE);
    localparam SRG0_CFG_FIFO_DEPTH  = 4;                // 2^int

    // ---------------- IPM_SRG CFG FIFO parameters ----------------
    localparam SRG_CFG_FIFO_WIDTH  = CFG_BW + NZL_HA_BW + $clog2(NUM_PE);
    localparam SRG_CFG_FIFO_DEPTH  = 4;                 // 2^int

    // ---------------- IPM_DRG CFG FIFO parameters ----------------
    localparam DRG_CFG_FIFO_WIDTH  = CFG_BW + $clog2(MAX_N);
    localparam DRG_CFG_FIFO_DEPTH  = 4;                 // 2^int

    // ---------------- IPM_DMX CFG FIFO parameters ----------------
    localparam DMX_CFG_FIFO_WIDTH  = CFG_BW;
    localparam DMX_CFG_FIFO_DEPTH  = 4;                 // 2^int

    // ---------------- IPM_CCM CFG FIFO parameters ----------------
    localparam CCM_CFG_FIFO_WIDTH  = CFG_BW;
    localparam CCM_CFG_FIFO_DEPTH  = 4;                 // 2^int

    // ---------------- IPM_SRG0 NZN FIFO parameters ----------------
    localparam SRG0_NZN_FIFO_WIDTH  = $clog2(MAX_N);
    localparam SRG0_NZN_FIFO_DEPTH  = 16;               // 2^int

    // ---------------- IPM_SRG NZN FIFO parameters ----------------
    localparam SRG_NZN_FIFO_WIDTH   = $clog2(MAX_N);
    localparam SRG_NZN_FIFO_DEPTH   = 16;               // 2^int

    // ---------------- IPM_DMX NZN FIFO parameters ----------------
    localparam DMX_NZN_FIFO_WIDTH   = $clog2(MAX_N);
    localparam DMX_NZN_FIFO_DEPTH   = 16;               // 2^int

    // ---------------- IPM_DRG NZI FIFO parameters ----------------
    localparam DRG_NZI_FIFO_WIDTH   = $clog2(MAX_N);
    localparam DRG_NZI_FIFO_DEPTH   = MAX_N;

    // ---------------- IPM_DMX NZI FIFO parameters ----------------
    localparam DMX_NZI_FIFO_WIDTH   = $clog2(MAX_N);
    localparam DMX_NZI_FIFO_DEPTH   = MAX_N;

    // ---------------- IPM_DMX Data FIFO parameters ----------------
    localparam FIFO_DRAM_WIDTH      = DRAM_WIDTH;
    localparam FIFO_DRAM_DEPTH      = 16;
    localparam FIFO_SMEM1_WIDTH     = WSEL_BW + SMEM_WW*NUM_PE;
    localparam FIFO_SMEM1_DEPTH     = 16;
    localparam FIFO_SMEM2_WIDTH     = WSEL_BW + SMEM_WW*NUM_PE;
    localparam FIFO_SMEM2_DEPTH     = 16;

    // ---------------- CCM NZN FIFO parameters ----------------
    localparam CCM_NZN_FIFO_WIDTH   = $clog2(MAX_N);
    localparam CCM_NZN_FIFO_DEPTH   = 16;               // 2^int

    // ---------------- Testbench parameters ----------------
    localparam int Ns = 3;          // Number of samples
    localparam int Nl = 1;          // Number of RNN layers
    // localparam int Nh[Nl+1] = {16, 32};
    localparam int Nh[Nl+1] = {64, 64};
    // localparam int Nh[Nl+1] = {128, 128};
    // localparam int Nh[Nl+1] = {256, 256};


// -----------------------------------------------------------------------------

    // ---------------- Consts ----------------
    const integer T_SIM = 5000;

    const string dir = "../../../../dat";
    
    const logic [SPM_ADDR_BW-1:0]   SPM_ADDR_M0 = {1'b0, {SPM_ADDR_BW-1{1'b0}}};
    const logic [SPM_ADDR_BW-1:0]   SPM_ADDR_M1 = {1'b1, {SPM_ADDR_BW-1{1'b0}}};
    
    const logic [SMEM_ADDR_BW-1:0]  SMEM_ADDR_M0 = {1'b0, {SMEM_ADDR_BW-1{1'b0}}};
    const logic [SMEM_ADDR_BW-1:0]  SMEM_ADDR_M1 = {1'b1, {SMEM_ADDR_BW-1{1'b0}}};
    
    const logic [DRAM_ADDR_BW-1:0]  DRAM_ADDR_0 = 32'h0000_0000;

    // FSM - states
    // typedef enum logic [1:0] {S_IDLE, S_INIT, S_GEN} state_t;
    
    // ---------------- Clock and Reset ----------------
    logic   clk = 1;
    always #5 clk = ~clk;
    
    logic                               rstn;
    
    // ---------------- CONFIG signals ----------------
    // logic                               cfg_valid;
    // PROC_t                              cfg_proc;
    // logic [NT_BW-1:0]                   cfg_nt;
    // logic [$clog2(MAX_M)-1:0]           cfg_t;
    // FUNC_t                              cfg_func;
    // logic [$clog2(MAX_CNT)-1:0]         cfg_cnt0;
    // logic [$clog2(MAX_CNT)-1:0]         cfg_cnt1;
    // logic [$clog2(MAX_CNT)-1:0]         cfg_cnt2;
    cfg_t                               cfg_data;
    logic                               cfg_ready_all;

    // ---------------- IPM_SPM Config ----------------
    logic                               spm_cfg_valid;
    cfg_t                               spm_cfg_data;
    logic                               spm_cfg_ready;
    logic [SPM_ADDR_BW-1:0]             spm_addr;

    // ---------------- IPM_SPM Read Port ----------------
    logic                               spm_rd_en;
    logic [SPM_ADDR_BW-1:0]             spm_rd_addr;
    logic [SPM_WW-1:0]                  spm_rd_data;
    logic                               spm_rd_regce;
    logic                               spm_rd_rstn;

    // ---------------- IPM_SPM Output Data ----------------
    logic                               spm_nzn_valid_o;
    logic                               spm_nzn_ready_i;
    logic [$clog2(MAX_N)-1:0]           spm_dout_nzn;
    logic                               spm_cfg_valid_o;
    logic                               spm_cfg_ready_i;
    cfg_t                               spm_cfg_data_o;
    logic [NZL_HA_BW-1:0]               nzl_head_addr;
    logic [$clog2(NUM_PE)-1:0]          nzl_head_peid;

    // ---------------- IPM_SRG0 CFG FIFO signals ----------------
    logic                               srg0_cfg_fifo_push;
    logic                               srg0_cfg_fifo_pop;
    logic                               srg0_cfg_fifo_empty;
    logic                               srg0_cfg_fifo_full;
    logic [SRG0_CFG_FIFO_WIDTH-1:0]     srg0_cfg_fifo_din;
    logic [SRG0_CFG_FIFO_WIDTH-1:0]     srg0_cfg_fifo_dout;
    
    // ---------------- IPM_SRG CFG FIFO signals ----------------
    logic                               srg_cfg_fifo_push;
    logic                               srg_cfg_fifo_pop;
    logic                               srg_cfg_fifo_empty;
    logic                               srg_cfg_fifo_full;
    logic [SRG_CFG_FIFO_WIDTH-1:0]      srg_cfg_fifo_din;
    logic [SRG_CFG_FIFO_WIDTH-1:0]      srg_cfg_fifo_dout;
    
    // ---------------- IPM_DRG CFG FIFO signals ----------------
    logic                               drg_cfg_fifo_push;
    logic                               drg_cfg_fifo_pop;
    logic                               drg_cfg_fifo_empty;
    logic                               drg_cfg_fifo_full;
    logic [DRG_CFG_FIFO_WIDTH-1:0]      drg_cfg_fifo_din;
    logic [DRG_CFG_FIFO_WIDTH-1:0]      drg_cfg_fifo_dout;
    
    // ---------------- IPM_DMX CFG FIFO signals ----------------
    logic                               dmx_cfg_fifo_push;
    logic                               dmx_cfg_fifo_pop;
    logic                               dmx_cfg_fifo_empty;
    logic                               dmx_cfg_fifo_full;
    logic [DMX_CFG_FIFO_WIDTH-1:0]      dmx_cfg_fifo_din;
    
    // ---------------- IPM_CCM CFG FIFO signals ----------------
    logic                               ccm_cfg_fifo_push;
    logic                               ccm_cfg_fifo_pop;
    logic                               ccm_cfg_fifo_empty;
    logic                               ccm_cfg_fifo_full;
    logic [CCM_CFG_FIFO_WIDTH-1:0]      ccm_cfg_fifo_din;
    
    // ---------------- IPM_SRG0 signals ----------------
    logic                               srg0_cfg_valid;
    cfg_t                               srg0_cfg_data;
    logic                               srg0_cfg_ready;

    logic [SMEM_ADDR_BW-1:0]            smem_addr0;
    logic [NZL_HA_BW-1:0]               srg0_nzl_head_addr;
    logic [$clog2(NUM_PE)-1:0]          srg0_nzl_head_peid;

    logic [$clog2(MAX_N)-1:0]           srg0_din_nzn;
    logic                               srg0_pop_nzn;

    // ---------------- IPM_SRG0 NZN FIFO signals ----------------
    logic                               srg0_nzn_fifo_push;
    logic                               srg0_nzn_fifo_empty;
    logic                               srg0_nzn_fifo_full;
    logic [SRG0_NZN_FIFO_WIDTH-1:0]     srg0_nzn_fifo_din;
    
    // ---------------- IPM_SRG signals ----------------
    logic                               srg_cfg_valid;
    cfg_t                               srg_cfg_data;
    logic                               srg_cfg_ready;

    logic [SMEM_ADDR_BW-1:0]            smem_addr1;
    logic [SMEM_ADDR_BW-1:0]            smem_addr2;
    logic [NZL_HA_BW-1:0]               srg_nzl_head_addr;
    logic [$clog2(NUM_PE)-1:0]          srg_nzl_head_peid;

    logic [$clog2(MAX_N)-1:0]           srg_din_nzn;
    logic                               srg_pop_nzn;

    // ---------------- IPM_SRG NZN FIFO signals ----------------
    logic                               srg_nzn_fifo_push;
    logic                               srg_nzn_fifo_empty;
    logic                               srg_nzn_fifo_full;
    logic [SRG_NZN_FIFO_WIDTH-1:0]      srg_nzn_fifo_din;

    // ---------------- IPM_DRG signals ----------------
    logic                               drg_cfg_valid;
    cfg_t                               drg_cfg_data;
    logic                               drg_cfg_ready;

    logic [$clog2(MAX_N)-1:0]           drg_cfg_nzn;
    logic [DRAM_ADDR_BW-1:0]            dram_addr0;

    logic [$clog2(MAX_N)-1:0]           drg_din_nzi;
    logic                               drg_pop_nzi;
    
    logic                               drg_cmd_tvalid;
    logic [AXI_DM_CMD_WIDTH-1:0]        drg_cmd_tdata;
    logic                               drg_cmd_tready;

    // ---------------- IPM_DRG NZI FIFO signals ----------------
    logic                               drg_nzi_fifo_push;
    logic                               drg_nzi_fifo_empty;
    logic                               drg_nzi_fifo_full;
    logic [DRG_NZI_FIFO_WIDTH-1:0]      drg_nzi_fifo_din;
    
    // ---------------- SMEM Read Channels ----------------
    logic [WSEL_BW-1:0]                 rd_wsel   [NUM_CH_RD-1:0];
    logic [SMEM_ADDR_BW-1:0]            rd_addr   [NUM_CH_RD-1:0];
    logic                               rd_avalid [NUM_CH_RD-1:0];
    logic                               rd_aready [NUM_CH_RD-1:0];
    logic [SMEM_WW-1:0]                 rd_dout   [NUM_CH_RD-1:0][0:NUM_PE-1];
    logic [WSEL_BW-1:0]                 rd_dwsel  [NUM_CH_RD-1:0];
    // logic                               rd_dstrobe[NUM_CH_RD-1:0][0:NUM_PE-1];
    logic                               rd_dvalid [NUM_CH_RD-1:0];
    logic                               rd_dready [NUM_CH_RD-1:0];
    
    // ---------------- SMEM Write Channels ----------------
    logic [WSEL_BW-1:0]                 wr_wsel   [NUM_CH_WR-1:0];
    logic [SMEM_ADDR_BW-1:0]            wr_addr   [NUM_CH_WR-1:0];
    logic                               wr_avalid [NUM_CH_WR-1:0];
    logic                               wr_aready [NUM_CH_WR-1:0];
    logic [SMEM_WW-1:0]                 wr_din    [NUM_CH_WR-1:0][0:NUM_PE-1];
    // logic [STS_BW-1:0]                  wr_sout   [NUM_CH_WR-1:0];      // status
    // logic                               wr_svalid [NUM_CH_WR-1:0];
    // logic                               wr_sready [NUM_CH_WR-1:0];
    
    // ---------------- IPM_DMX signals ----------------
    logic                               dmx_cfg_valid;
    cfg_t                               dmx_cfg_data;
    logic                               dmx_cfg_ready;

    logic [$clog2(MAX_N)-1:0]           dmx_din_nzn;
    logic                               dmx_pop_nzn;

    logic [$clog2(MAX_N)-1:0]           dmx_din_nzi;
    logic                               dmx_pop_nzi;

    // ---------------- IPM_DMX DRAM Input Channel ----------------
    // logic [DRAM_WW-1:0]                 dram_data;
    logic [SMEM_WW-1:0]                 dram_data[0:NUM_PE-1];
    logic                               dram_empty;
    logic                               dram_pop;

    // ---------------- IPM_DMX SMEM Input Channels ----------------
    logic [SMEM_WW-1:0]                 smem1_data[0:NUM_PE-1];
    logic [WSEL_BW-1:0]                 smem1_dwsel;
    logic                               smem1_empty;
    logic                               smem1_pop;

    logic [SMEM_WW-1:0]                 smem2_data[0:NUM_PE-1];
    logic [WSEL_BW-1:0]                 smem2_dwsel;
    logic                               smem2_empty;
    logic                               smem2_pop;

    // ---------------- IPM_DMX Output Channels ----------------
    logic [ACT_BW-1:0]                  dmx_dout_act[0:NUM_PE-1];
    logic [WEIGHT_BW-1:0]               dmx_dout_weight[0:NUM_PE-1];
    logic [$clog2(MAX_N)-1:0]           dmx_dout_nzi;
    logic                               en_hist_nzi;
    logic                               dmx_valid_o;
    logic                               dmx_ready_i;

    // ---------------- IPM_DMX NZN FIFO signals ----------------
    logic                               dmx_nzn_fifo_push;
    logic                               dmx_nzn_fifo_empty;
    logic                               dmx_nzn_fifo_full;
    logic [DMX_NZN_FIFO_WIDTH-1:0]      dmx_nzn_fifo_din;
    
    // ---------------- IPM_DMX NZI FIFO signals ----------------
    logic                               dmx_nzi_fifo_push;
    logic                               dmx_nzi_fifo_empty;
    logic                               dmx_nzi_fifo_full;
    logic [DMX_NZI_FIFO_WIDTH-1:0]      dmx_nzi_fifo_din;
    
    // ---------------- IPM_DMX DRAM FIFO signals ----------------
    logic                               dram_push;
    logic                               dram_full;
    logic [FIFO_DRAM_WIDTH-1:0]         dram_fifo_din;
    logic [FIFO_DRAM_WIDTH-1:0]         dram_fifo_dout;
    logic                               dram_fifo_wen;
    // logic [DRAM_WW-1:0]                 dram_fifo_data[0:NUM_PE-1];
    // logic [DRAM_WIDTH-1:0]              dram_fifo_data;
    
    // ---------------- IPM_DMX SMEM1 FIFO signals ----------------
    logic                               smem1_push;
    logic                               smem1_full;
    logic [FIFO_SMEM1_WIDTH-1:0]        smem1_fifo_din;
    logic [FIFO_SMEM1_WIDTH-1:0]        smem1_fifo_dout;
    logic [SMEM_WW-1:0]                 smem1_fifo_data[0:NUM_PE-1];
    // logic                               smem1_fifo_wen;
    logic [WSEL_BW-1:0]                 smem1_fifo_dwsel;

    // ---------------- IPM_DMX SMEM2 FIFO signals ----------------
    logic                               smem2_push;
    logic                               smem2_full;
    logic [FIFO_SMEM2_WIDTH-1:0]        smem2_fifo_din;
    logic [FIFO_SMEM2_WIDTH-1:0]        smem2_fifo_dout;
    logic [SMEM_WW-1:0]                 smem2_fifo_data[0:NUM_PE-1];
    // logic                               smem2_fifo_wen;
    logic [WSEL_BW-1:0]                 smem2_fifo_dwsel;

    // ---------------- CCM signals ----------------
    logic                               ccm_cfg_valid;
    cfg_t                               ccm_cfg_data;
    logic                               ccm_cfg_ready;

    logic                               ccm_valid_i;
    logic                               ccm_ready_i;

    logic [$clog2(MAX_N)-1:0]           ccm_din_nzn;
    logic                               ccm_pop_nzn;

    logic [ACT_BW-1:0]                  ccm_din_act[0:NUM_PE-1];
    logic [WEIGHT_BW-1:0]               ccm_din_weight[0:NUM_PE-1];
    logic [$clog2(MAX_N)-1:0]           ccm_din_nzi;
    
    logic                               ccm_valid_o;
    logic                               ccm_ready_o;
    logic [ACT_BW-1:0]                  ccm_dout_act[0:NUM_PE];     // acc
    
    // ---------------- HIST signals ----------------
    logic                               hist_ready_o;
    logic [$clog2(MAX_N)-1:0]           hist_nzi[0:3];
    logic                               hist_nzi_v[0:3];

    // ---------------- CCM NZN FIFO signals ----------------
    logic                               ccm_nzn_fifo_push;
    logic                               ccm_nzn_fifo_empty;
    logic                               ccm_nzn_fifo_full;
    logic [CCM_NZN_FIFO_WIDTH-1:0]      ccm_nzn_fifo_din;

    // ---------------- Testbench signals ----------------
    logic [NT_BW-1:0]                   Nt[Ns];
    logic [15:0]                        nt_temp;                // '>i2'
    logic [31:0]                        spm_temp[SPM_DEPTH];    // '>i4'
    logic [$clog2(MAX_N*MAX_M)-1:0]     nzn_tot[Ns];
    logic [15:0]                        smem_temp[NUM_PE];      // '>i2'

    // ---------------- Testbench debug signals ----------------
    event                               event_DRAM_NZIL;
    event                               event_DRAM_dL_DM;
    event                               event_CCM_output;
    time                                time_start;
    time                                time_proc[3];
    logic [DRAM_WIDTH-1:0]              DRAM[DRAM_DEPTH];
    logic [DRAM_ADDR_BW-1:0]            dram_addr;
    logic [DRAM_WIDTH-1:0]              DOV[DRAM_DEPTH];
    logic [NZL_HA_BW-1:0]               dov_lha[SPM_DEPTH];
    logic [$clog2(NUM_PE)-1:0]          dov_lhp[SPM_DEPTH];
    logic [$clog2(MAX_N)-1:0]           dov_nzn[SPM_DEPTH];
    logic [$clog2(MAX_N)-1:0]           dov_nzi[SPM_DEPTH][MAX_N];

    int                                 s_curr = 0;
    int                                 l_curr = 0;
    int                                 t_curr = 0;

    // int fo;
    // // logic [ACC_BW-1:0]  BPE[0:NUM_PE-1][BRAM_PE_DEPTH-1:0];
    
    // logic TE_f;
    // logic TG_f;
    // logic [0:5] f_cur;
    // logic [0:5] f_prev;

    // int x_del[4*6];
    // int x_del_num_nzi[4] = {2, 1, 3, 2};
    

// -----------------------------------------------------------------------------
// Utility functions

    function logic signed[ACT_BW-1:0] i2qa(input int signed sint);
        logic signed[31:0] act_in;
        logic signed[ACT_BW-1:0] act_out;

        act_in = $signed(sint) <<< ACT_QN;

        if (act_in > 2**(ACT_BW-1)-1) begin
            act_out = 2**(ACT_BW-1)-1;
        end else if (act_in < -2**(ACT_BW-1)) begin
            act_out = -2**(ACT_BW-1);
        end else begin
            act_out = act_in;
        end

        return act_out;
    endfunction
    

    function logic signed[ACT_BW-1:0] r2qa(input real real_in);
        logic signed[31:0] act_in;
        logic signed[ACT_BW-1:0] act_out;
        
        `ifdef ROUND_FLOOR
            act_in = real_in * (2 ** ACT_QN);
        `else
            // act_in = real_in * (2 ** ACT_QN) + 0.5;
            act_in = (real_in + 2 ** (-1-ACT_QN)) * (2 ** ACT_QN);
        `endif
        
        if (act_in > 2**(ACT_BW-1)-1) begin
            act_out = 2**(ACT_BW-1)-1;
        end else if (act_in < -2**(ACT_BW-1)) begin
            act_out = -2**(ACT_BW-1);
        end else begin
            act_out = act_in;
        end

        return act_out;
    endfunction
    

    function logic signed[WEIGHT_BW-1:0] i2qw(input int signed sint);
        logic signed[31:0] weight_in;
        logic signed[WEIGHT_BW-1:0] weight_out;

        weight_in = $signed(sint) <<< WEIGHT_QN;

        if (weight_in > 2**(WEIGHT_BW-1)-1) begin
            weight_out = 2**(WEIGHT_BW-1)-1;
        end else if (weight_in < -2**(WEIGHT_BW-1)) begin
            weight_out = -2**(WEIGHT_BW-1);
        end else begin
            weight_out = weight_in;
        end

        return weight_out;
    endfunction
    

    function logic signed[WEIGHT_BW-1:0] r2qw(input real real_in);
        logic signed[31:0] weight_in;
        logic signed[WEIGHT_BW-1:0] weight_out;
        
        `ifdef ROUND_FLOOR
            weight_in = real_in * (2 ** WEIGHT_QN);
        `else
            // weight_in = real_in * (2 ** WEIGHT_QN) + 0.5;
            weight_in = (real_in + 2 ** (-1-WEIGHT_QN)) * (2 ** WEIGHT_QN);
        `endif

        if (weight_in > 2**(WEIGHT_BW-1)-1) begin
            weight_out = 2**(WEIGHT_BW-1)-1;
        end else if (weight_in < -2**(WEIGHT_BW-1)) begin
            weight_out = -2**(WEIGHT_BW-1);
        end else begin
            weight_out = weight_in;
        end

        return weight_out;
    endfunction
    

// -----------------------------------------------------------------------------
// Tasks


    task automatic write_smem0 (
        input logic [SMEM_ADDR_BW-1-1:0] addr
    );
        SMEM_INST.genblk1[ 0].SMEM_0.BRAM[addr] = smem_temp[ 0];
        SMEM_INST.genblk1[ 1].SMEM_0.BRAM[addr] = smem_temp[ 1];
        SMEM_INST.genblk1[ 2].SMEM_0.BRAM[addr] = smem_temp[ 2];
        SMEM_INST.genblk1[ 3].SMEM_0.BRAM[addr] = smem_temp[ 3];
        SMEM_INST.genblk1[ 4].SMEM_0.BRAM[addr] = smem_temp[ 4];
        SMEM_INST.genblk1[ 5].SMEM_0.BRAM[addr] = smem_temp[ 5];
        SMEM_INST.genblk1[ 6].SMEM_0.BRAM[addr] = smem_temp[ 6];
        SMEM_INST.genblk1[ 7].SMEM_0.BRAM[addr] = smem_temp[ 7];
        SMEM_INST.genblk1[ 8].SMEM_0.BRAM[addr] = smem_temp[ 8];
        SMEM_INST.genblk1[ 9].SMEM_0.BRAM[addr] = smem_temp[ 9];
        SMEM_INST.genblk1[10].SMEM_0.BRAM[addr] = smem_temp[10];
        SMEM_INST.genblk1[11].SMEM_0.BRAM[addr] = smem_temp[11];
        SMEM_INST.genblk1[12].SMEM_0.BRAM[addr] = smem_temp[12];
        SMEM_INST.genblk1[13].SMEM_0.BRAM[addr] = smem_temp[13];
        SMEM_INST.genblk1[14].SMEM_0.BRAM[addr] = smem_temp[14];
        SMEM_INST.genblk1[15].SMEM_0.BRAM[addr] = smem_temp[15];
    endtask

    task automatic write_smem1 (
        input logic [SMEM_ADDR_BW-1-1:0] addr
    );
        SMEM_INST.genblk2[ 0].SMEM_1.BRAM[addr] = smem_temp[ 0];
        SMEM_INST.genblk2[ 1].SMEM_1.BRAM[addr] = smem_temp[ 1];
        SMEM_INST.genblk2[ 2].SMEM_1.BRAM[addr] = smem_temp[ 2];
        SMEM_INST.genblk2[ 3].SMEM_1.BRAM[addr] = smem_temp[ 3];
        SMEM_INST.genblk2[ 4].SMEM_1.BRAM[addr] = smem_temp[ 4];
        SMEM_INST.genblk2[ 5].SMEM_1.BRAM[addr] = smem_temp[ 5];
        SMEM_INST.genblk2[ 6].SMEM_1.BRAM[addr] = smem_temp[ 6];
        SMEM_INST.genblk2[ 7].SMEM_1.BRAM[addr] = smem_temp[ 7];
        SMEM_INST.genblk2[ 8].SMEM_1.BRAM[addr] = smem_temp[ 8];
        SMEM_INST.genblk2[ 9].SMEM_1.BRAM[addr] = smem_temp[ 9];
        SMEM_INST.genblk2[10].SMEM_1.BRAM[addr] = smem_temp[10];
        SMEM_INST.genblk2[11].SMEM_1.BRAM[addr] = smem_temp[11];
        SMEM_INST.genblk2[12].SMEM_1.BRAM[addr] = smem_temp[12];
        SMEM_INST.genblk2[13].SMEM_1.BRAM[addr] = smem_temp[13];
        SMEM_INST.genblk2[14].SMEM_1.BRAM[addr] = smem_temp[14];
        SMEM_INST.genblk2[15].SMEM_1.BRAM[addr] = smem_temp[15];
    endtask

    task automatic read_smem0 (
        input  logic [SMEM_ADDR_BW-1-1:0] addr
    );
        smem_temp[ 0] = SMEM_INST.genblk1[ 0].SMEM_0.BRAM[addr];
        smem_temp[ 1] = SMEM_INST.genblk1[ 1].SMEM_0.BRAM[addr];
        smem_temp[ 2] = SMEM_INST.genblk1[ 2].SMEM_0.BRAM[addr];
        smem_temp[ 3] = SMEM_INST.genblk1[ 3].SMEM_0.BRAM[addr];
        smem_temp[ 4] = SMEM_INST.genblk1[ 4].SMEM_0.BRAM[addr];
        smem_temp[ 5] = SMEM_INST.genblk1[ 5].SMEM_0.BRAM[addr];
        smem_temp[ 6] = SMEM_INST.genblk1[ 6].SMEM_0.BRAM[addr];
        smem_temp[ 7] = SMEM_INST.genblk1[ 7].SMEM_0.BRAM[addr];
        smem_temp[ 8] = SMEM_INST.genblk1[ 8].SMEM_0.BRAM[addr];
        smem_temp[ 9] = SMEM_INST.genblk1[ 9].SMEM_0.BRAM[addr];
        smem_temp[10] = SMEM_INST.genblk1[10].SMEM_0.BRAM[addr];
        smem_temp[11] = SMEM_INST.genblk1[11].SMEM_0.BRAM[addr];
        smem_temp[12] = SMEM_INST.genblk1[12].SMEM_0.BRAM[addr];
        smem_temp[13] = SMEM_INST.genblk1[13].SMEM_0.BRAM[addr];
        smem_temp[14] = SMEM_INST.genblk1[14].SMEM_0.BRAM[addr];
        smem_temp[15] = SMEM_INST.genblk1[15].SMEM_0.BRAM[addr];
    endtask

    task automatic read_smem1 (
        input logic [SMEM_ADDR_BW-1-1:0] addr
    );
        smem_temp[ 0] = SMEM_INST.genblk2[ 0].SMEM_1.BRAM[addr];
        smem_temp[ 1] = SMEM_INST.genblk2[ 1].SMEM_1.BRAM[addr];
        smem_temp[ 2] = SMEM_INST.genblk2[ 2].SMEM_1.BRAM[addr];
        smem_temp[ 3] = SMEM_INST.genblk2[ 3].SMEM_1.BRAM[addr];
        smem_temp[ 4] = SMEM_INST.genblk2[ 4].SMEM_1.BRAM[addr];
        smem_temp[ 5] = SMEM_INST.genblk2[ 5].SMEM_1.BRAM[addr];
        smem_temp[ 6] = SMEM_INST.genblk2[ 6].SMEM_1.BRAM[addr];
        smem_temp[ 7] = SMEM_INST.genblk2[ 7].SMEM_1.BRAM[addr];
        smem_temp[ 8] = SMEM_INST.genblk2[ 8].SMEM_1.BRAM[addr];
        smem_temp[ 9] = SMEM_INST.genblk2[ 9].SMEM_1.BRAM[addr];
        smem_temp[10] = SMEM_INST.genblk2[10].SMEM_1.BRAM[addr];
        smem_temp[11] = SMEM_INST.genblk2[11].SMEM_1.BRAM[addr];
        smem_temp[12] = SMEM_INST.genblk2[12].SMEM_1.BRAM[addr];
        smem_temp[13] = SMEM_INST.genblk2[13].SMEM_1.BRAM[addr];
        smem_temp[14] = SMEM_INST.genblk2[14].SMEM_1.BRAM[addr];
        smem_temp[15] = SMEM_INST.genblk2[15].SMEM_1.BRAM[addr];
    endtask


    task automatic file2DRAM (
        input string str_stage,
        input string file_name,
        input int    dram_size,
        input int    dram_offset = 0,
        input int    file_offset = 0
    );
        int fi, fs, num_bytes, dat_idx, pe_idx;

        fi = $fopen(file_name, "rb");
        if (!fi) begin
            $error("%s [f->DRAM] Can not open \"%s\"!", str_stage, file_name);
        end else begin
            fs = $fseek(fi, file_offset, 0);
            $display("%s [f->DRAM] At position (0x%08x).", str_stage, $ftell(fi));
            num_bytes = $fread(DRAM, fi, dram_offset, dram_size);
            // for (dat_idx=0; dat_idx<dram_size; dat_idx++) begin
            //     // DRAM[dat_idx]: {p0, p1, p2, ..., p15}
            //     for(pe_idx=0; pe_idx<NUM_PE; pe_idx++) begin
            //         $write("%4d ", $signed(DRAM[dram_offset + dat_idx][DRAM_WW*(NUM_PE-1-pe_idx) +: DRAM_WW]));
            //     end
            //     $write("\n");
            // end
            // for (dat_idx=0; dat_idx<dram_size; dat_idx++) begin
            //     $display("%064x", DRAM[dram_offset + dat_idx]);
            // end
            $display("%s [f->DRAM] (%0d) bytes read from \"%s\".", str_stage, num_bytes, file_name);
            $display("%s [f->DRAM] At position (0x%08x).", str_stage, $ftell(fi));
        end
        $fclose(fi);
    endtask


    task automatic file2SPM (
        input string file_name,
        input int    file_offset = 0,
        input int    s_idx = 0,                 // Sample index
        input string str_stage = "INIT_SPM"
    );
        int fi, fs, num_bytes, dat_idx, nzn_temp;

        fi = $fopen(file_name, "rb");
        if (!fi) begin
            $error("%s [f->SPM] Can not open \"%s\"!", str_stage, file_name);
        end else begin
            fs = $fseek(fi, file_offset, 0);
            $display("%s [f->SPM] At position (0x%08x).", str_stage, $ftell(fi));
            num_bytes = $fread(nt_temp, fi);
            $display("%s [f->SPM] (%0d) bytes read from \"%s\".", str_stage, num_bytes, file_name);
            Nt[s_idx] = nt_temp;
            $display("%s [f->SPM] Nt[%0d] = %0d.", str_stage, s_idx, nt_temp);
            num_bytes = $fread(spm_temp, fi, 0, nt_temp);
            nzn_temp = 0;
            for (dat_idx=0; dat_idx<nt_temp; dat_idx++) begin
                {dov_lha[dat_idx], dov_lhp[dat_idx], dov_nzn[dat_idx]} = spm_temp[dat_idx];
                $write("    %08x -> (%d, %d), %d\n",
                       spm_temp[dat_idx], dov_lha[dat_idx], dov_lhp[dat_idx], dov_nzn[dat_idx]);
                nzn_temp += spm_temp[dat_idx][0 +: $clog2(MAX_N)];
                // (!) (nzn-1) for cfg_cnt_x
                spm_temp[dat_idx][0+:$clog2(MAX_N)] = spm_temp[dat_idx][0+:$clog2(MAX_N)] - 1;
                SPM_MEM.BRAM[dat_idx] = spm_temp[dat_idx][SPM_WW-1:0];
                // $display("%06x", SPM_MEM.BRAM[dat_idx]);
            end
            nzn_tot[s_idx] = nzn_temp;
            $display("%s [f->SPM] nzn_tot[%0d] = %0d.", str_stage, s_idx, nzn_temp);
            $display("%s [f->SPM] (%0d) bytes read from \"%s\".", str_stage, num_bytes, file_name);
            $display("%s [f->SPM] At position (0x%08x).", str_stage, $ftell(fi));
        end
        $fclose(fi);
    endtask


    // logic [SMEM_WW-1:0] SMEM_0[NUM_PE-1:0][SMEM_DEPTH/2-1:0];
    // generate
    //     for (genvar pe_idx=0; pe_idx<NUM_PE; pe_idx++) begin
    //         assign SMEM_0[pe_idx] = SMEM_INST.genblk1[pe_idx].SMEM_0.BRAM;
    //     end
    // endgenerate

    task automatic file2SMEM_nzl (
        input string str_stage,
        input string file_name,
        input int    file_offset = 0,
        input int    s_idx = 0                 // Sample index
        // input logic [SMEM_ADDR_BW-1:0] addr_nzil = SMEM_ADDR_M0,
        // input logic [SMEM_ADDR_BW-1:0] addr_nzvl = SMEM_ADDR_M1
    );
        int fi, fs, num_bytes, pe_idx, num_chk, chk_rmd, chk_idx, chk_size;
        int dat_idx, t_idx;

        fi = $fopen(file_name, "rb");
        if (!fi) begin
            $error("%s [f->SMEM(nzl)] Can not open \"%s\"!", str_stage, file_name);
        end else begin
            fs = $fseek(fi, file_offset, 0);

            // NZIL
            $display("%s [f->SMEM(nzl)] At position (0x%08x).", str_stage, $ftell(fi));
            $display("    NZIL[%0d], length = %0d.", s_idx, nzn_tot[s_idx]);
            num_chk = nzn_tot[s_idx] / NUM_PE;
            chk_rmd = nzn_tot[s_idx] % NUM_PE;
            if (chk_rmd > 0)
                num_chk += 1;
            dat_idx = 0;
            t_idx = 0;
            for (chk_idx=0; chk_idx<num_chk; chk_idx++) begin
                if ((chk_rmd > 0) && (chk_idx == (num_chk-1)))
                    chk_size = chk_rmd;
                else
                    chk_size = NUM_PE;
                num_bytes = $fread(smem_temp, fi, 0, chk_size);
                // $display("%s [f->SMEM(nzl)] (%0d) bytes read from \"%s\".", str_stage, num_bytes, file_name);
                // $write("    ");
                // for (pe_idx=0; pe_idx<chk_size; pe_idx++) begin
                //     $write("%4d ", smem_temp[pe_idx]);
                //     // SMEM_INST.SMEM_0[pe_idx].BRAM[chk_idx] = smem_temp[pe_idx];
                // end
                // $write("\n");
                // Write NZIL to SMEM_ADDR_M0
                write_smem0(chk_idx);
                // Write NZIL to dov_nzi
                for (pe_idx=0; pe_idx<chk_size; pe_idx++) begin
                    dov_nzi[t_idx][dat_idx++] = smem_temp[pe_idx];
                    if (dat_idx >= dov_nzn[t_idx]) begin
                        t_idx++;
                        dat_idx = 0;
                    end
                end
            end
            // for (t_idx=0; t_idx<Nt[s_idx]; t_idx++) begin
            //     $write("    t=%04d: ", t_idx);
            //     for (dat_idx=0; dat_idx<dov_nzn[t_idx]; dat_idx++) begin
            //         $write("%4d ", dov_nzi[t_idx][dat_idx]);
            //     end
            //     $write("\n");
            // end

            // NZVL
            $display("%s [f->SMEM(nzl)] At position (0x%08x).", str_stage, $ftell(fi));
            $display("    NZVL[%0d], length = %0d.", s_idx, nzn_tot[s_idx]);
            num_chk = nzn_tot[s_idx] / NUM_PE;
            chk_rmd = nzn_tot[s_idx] % NUM_PE;
            if (chk_rmd > 0)
                num_chk += 1;
            for (chk_idx=0; chk_idx<num_chk; chk_idx++) begin
                if ((chk_rmd > 0) && (chk_idx == (num_chk-1)))
                    chk_size = chk_rmd;
                else
                    chk_size = NUM_PE;
                num_bytes = $fread(smem_temp, fi, 0, chk_size);
                // $display("%s [f->SMEM(nzl)] (%0d) bytes read from \"%s\".", str_stage, num_bytes, file_name);
                // $write("    ");
                // for (pe_idx=0; pe_idx<chk_size; pe_idx++) begin
                //     $write("%4d ", $signed(smem_temp[pe_idx]));
                //     // SMEM_INST.SMEM_1[pe_idx].BRAM[chk_idx] = smem_temp[pe_idx];
                // end
                // $write("\n");
                // Write NZVL to SMEM_ADDR_M1
                write_smem1(chk_idx);
            end
            $display("%s [f->SMEM(nzl)] At position (0x%08x).", str_stage, $ftell(fi));
        end
        $fclose(fi);
    endtask


    // logic [SMEM_WW-1:0]         smem0_curr[NUM_PE-1:0];
    // logic [SMEM_WW-1:0]         smem1_curr[NUM_PE-1:0];
    // logic [SMEM_ADDR_BW-1:0]    smemx_addr;
    // generate
    //     for (genvar pe_idx=0; pe_idx<NUM_PE; pe_idx++) begin
    //         always_comb begin
    //             smem0_curr[pe_idx] = SMEM_INST.genblk1[pe_idx].SMEM_0.BRAM[smemx_addr];
    //             smem1_curr[pe_idx] = SMEM_INST.genblk2[pe_idx].SMEM_1.BRAM[smemx_addr];
    //         end
    //     end
    // endgenerate

    // Pad NZIL and NZVL for the last timestep for VXV_SP
    // task automatic pad_nzl (
    //     input int    s_idx = 0,                 // Sample index
    //     input int    l_idx = 0                  // Layer index
    // );
    //     logic [NZL_HA_BW-1:0]       lha_t;
    //     logic [$clog2(NUM_PE)-1:0]  lhp_t;
    //     logic [$clog2(MAX_N)-1:0]   nzn_t;
    //     logic [SMEM_WW-1:0]         nzil_t[MAX_N];
    //     logic [SMEM_WW-1:0]         nzvl_t[MAX_N];
    //     logic [SMEM_ADDR_BW-1:0]    addr;
    //     logic [$clog2(NUM_PE)-1:0]  peid;
    //     int dat_idx, pe_idx;

    //     // nt_temp = Nt[s_idx];
    //     {lha_t, lhp_t, nzn_t} = spm_temp[nt_temp-1];
    //     $display("    spm_temp[0x%04x] = (%d, %d), %d", nt_temp-1, lha_t, lhp_t, nzn_t);

    //     spm_temp[nt_temp-1][0 +: $clog2(MAX_N)] = Nh[l_idx-1] - 1;
    //     $display("    nzn <- %0d", Nh[l_idx-1] - 1);

    //     // Pad NZIL
    //     addr = SMEM_ADDR_M0 + lha_t;
    //     peid = lhp_t;
    //     read_smem0(addr);
    //     for (dat_idx=0; dat_idx<nzn_t+1; dat_idx++) begin
    //         $display("    addr=0x%08x, peid=%0d", addr, peid);
    //         $write("    smem0[0x%08x] = ", addr);
    //         for (pe_idx=0; pe_idx<NUM_PE; pe_idx++) begin
    //             $write("%04d ", smem_temp[pe_idx]);
    //         end
    //         $write("\n");

    //         if (peid == NUM_PE-1) begin
    //             peid = 0;
    //             addr += 1;
    //             read_smem0(addr);
    //         end else begin
    //             peid += 1;
    //         end
    //     end
    // endtask


    task automatic file2SMEM_dL_dMx (
        input string str_stage,
        input string file_name,
        input int    file_offset = 0,
        input int    s_idx = 0,                 // Sample index
        input int    l_idx = 0                  // Layer index
        // input logic [SMEM_ADDR_BW-1:0] smem_offset = 0
    );
        int fi, fs, num_bytes, pe_idx, num_chk, chk_idx;

        fi = $fopen(file_name, "rb");
        if (!fi) begin
            $error("%s [f->SMEM(dL_dMx)] Can not open \"%s\"!", str_stage, file_name);
        end else begin
            fs = $fseek(fi, file_offset, 0);
            $display("%s [f->SMEM(dL_dMx)] At position (0x%08x).", str_stage, $ftell(fi));
            num_chk = Nt[s_idx] * (Nh[l_idx]/NUM_PE);
            for (chk_idx=0; chk_idx<num_chk; chk_idx++) begin
                num_bytes = $fread(smem_temp, fi, 0, NUM_PE);
                // $display("%s [f->SMEM(dL_dMx)] (%0d) bytes read from \"%s\".", str_stage, num_bytes, file_name);
                // $write("    ");
                // for (pe_idx=0; pe_idx<NUM_PE; pe_idx++) begin
                //     $write("%4d ", $signed(smem_temp[pe_idx]));
                // end
                // $write("\n");
                // Write M to SMEM_ADDR_M1
                write_smem1(chk_idx);
            end
            $display("%s [f->SMEM(dL_dMx)] At position (0x%08x).", str_stage, $ftell(fi));
        end
        $fclose(fi);
    endtask


    task automatic file2DOV (
        input string str_stage,
        input string file_name,
        input int    dov_size,
        input int    dov_offset = 0,
        input int    file_offset = 0
    );
        int fi, fs, num_bytes, dat_idx, pe_idx;

        fi = $fopen(file_name, "rb");
        if (!fi) begin
            $error("%s [f->DOV] Can not open \"%s\"!", str_stage, file_name);
        end else begin
            fs = $fseek(fi, file_offset, 0);
            $display("%s [f->DOV] At position (0x%08x).", str_stage, $ftell(fi));
            num_bytes = $fread(DOV, fi, dov_offset, dov_size);
            // for (dat_idx=0; dat_idx<dov_size; dat_idx++) begin
            //     // DOV[dat_idx]: {p0, p1, p2, ..., p15}
            //     for(pe_idx=0; pe_idx<NUM_PE; pe_idx++) begin
            //         $write("%4d ", $signed(DOV[dov_offset + dat_idx][DRAM_WW*(NUM_PE-1-pe_idx) +: DRAM_WW]));
            //     end
            //     $write("\n");
            // end
            // for (dat_idx=0; dat_idx<dov_size; dat_idx++) begin
            //     $display("%064x", DOV[dov_offset + dat_idx]);
            // end
            $display("%s [f->DOV] (%0d) bytes read from \"%s\".", str_stage, num_bytes, file_name);
            $display("%s [f->DOV] At position (0x%08x).", str_stage, $ftell(fi));
        end
        $fclose(fi);
    endtask


    task automatic reset_LMEM_MAC ();
        CCM_INST.genblk1[ 0].LMEM_MAC.BRAM = '{default: '0};
        CCM_INST.genblk1[ 1].LMEM_MAC.BRAM = '{default: '0};
        CCM_INST.genblk1[ 2].LMEM_MAC.BRAM = '{default: '0};
        CCM_INST.genblk1[ 3].LMEM_MAC.BRAM = '{default: '0};
        CCM_INST.genblk1[ 4].LMEM_MAC.BRAM = '{default: '0};
        CCM_INST.genblk1[ 5].LMEM_MAC.BRAM = '{default: '0};
        CCM_INST.genblk1[ 6].LMEM_MAC.BRAM = '{default: '0};
        CCM_INST.genblk1[ 7].LMEM_MAC.BRAM = '{default: '0};
        CCM_INST.genblk1[ 8].LMEM_MAC.BRAM = '{default: '0};
        CCM_INST.genblk1[ 9].LMEM_MAC.BRAM = '{default: '0};
        CCM_INST.genblk1[10].LMEM_MAC.BRAM = '{default: '0};
        CCM_INST.genblk1[11].LMEM_MAC.BRAM = '{default: '0};
        CCM_INST.genblk1[12].LMEM_MAC.BRAM = '{default: '0};
        CCM_INST.genblk1[13].LMEM_MAC.BRAM = '{default: '0};
        CCM_INST.genblk1[14].LMEM_MAC.BRAM = '{default: '0};
        CCM_INST.genblk1[15].LMEM_MAC.BRAM = '{default: '0};
    endtask


    task automatic write_csv ();
        int fo;
        string file_name;

        file_name = $sformatf("%s/results.csv", dir);
        fo = $fopen(file_name, "a");
        if (!fo) begin
            $error("[write_csv] Can not open \"%s\"!", file_name);
        end else begin
            $fdisplay(fo, "%0t, %0t, %0t", time_proc[0], time_proc[1], time_proc[2]);
            $display("[write_csv] Time written to \"%s\".", file_name);
            $fclose(fo);
        end
    endtask


// -----------------------------------------------------------------------------
// IPM - Sparse Data Descriptor Memory

    IPM_SPM #(
        // .NUM_PE         (NUM_PE         ),
        // .MAX_N          (MAX_N          ),
        // .MAX_M          (MAX_M          ),
        // .MAX_NoP        (MAX_NoP        ),

        .SPM_WW         (SPM_WW         ),
        .SPM_DEPTH      (SPM_DEPTH      )
    ) IPM_SPM_INST (
        .clk            (clk            ),
        .rstn           (rstn           ),

        .cfg_valid      (spm_cfg_valid  ),
        // .cfg_proc       (cfg_proc       ),
        // .cfg_t          (cfg_t          ),
        // .cfg_cnt0       (cfg_cnt0       ),
        // .cfg_cnt1       (cfg_cnt1       ),
        // .cfg_cnt2       (cfg_cnt2       ),
        .cfg_data       (spm_cfg_data   ),
        .cfg_ready      (spm_cfg_ready  ),

        .spm_addr       (spm_addr       ),

        .spm_rd_en      (spm_rd_en      ),
        .spm_rd_addr    (spm_rd_addr    ),
        .spm_rd_data    (spm_rd_data    ),
        .spm_rd_regce   (spm_rd_regce   ),
        .spm_rd_rstn    (spm_rd_rstn    ),

        .nzn_valid_o    (spm_nzn_valid_o),
        .nzn_ready_i    (spm_nzn_ready_i),
        .dout_nzn       (spm_dout_nzn   ),
        .cfg_valid_o    (spm_cfg_valid_o),
        .cfg_ready_i    (spm_cfg_ready_i),
        .cfg_data_o     (spm_cfg_data_o ),
        .nzl_head_addr  (nzl_head_addr  ),
        .nzl_head_peid  (nzl_head_peid  )
    );
    
    
    // (* ram_style = "block" *)
    BRAM_SDP_1C #(
        .RAM_WIDTH      (SPM_WW             ),
        .RAM_DEPTH      (SPM_DEPTH          ),
        .RAM_PERFORMANCE("LOW_LATENCY"      ),
        .INIT_FILE      (""                 )
    ) SPM_MEM (
        .addra          (                   ),
        .addrb          (spm_rd_addr        ),
        .dina           (                   ),
        .clka           (clk                ),
        .wea            (                   ),
        .enb            (spm_rd_en          ),
        .rstb           (!spm_rd_rstn       ),
        .regceb         (spm_rd_regce       ),
        .doutb          (spm_rd_data        )
    );
    

    assign spm_cfg_data = cfg_data;
    // assign srg0_cfg_data = cfg_data;
    // assign srg_cfg_data = cfg_data;
    // assign dmx_cfg_data = cfg_data;
    // assign ccm_cfg_data = cfg_data;

    assign srg0_cfg_fifo_pop = !srg0_cfg_fifo_empty && srg0_cfg_ready;
    assign srg_cfg_fifo_pop = !srg_cfg_fifo_empty && srg_cfg_ready;
    assign drg_cfg_fifo_pop = !drg_cfg_fifo_empty && drg_cfg_ready;
    assign dmx_cfg_fifo_pop = !dmx_cfg_fifo_empty && dmx_cfg_ready;
    assign ccm_cfg_fifo_pop = !ccm_cfg_fifo_empty && ccm_cfg_ready;

    assign srg0_cfg_valid = !srg0_cfg_fifo_empty;
    assign srg_cfg_valid = !srg_cfg_fifo_empty;
    assign drg_cfg_valid = !drg_cfg_fifo_empty;
    assign dmx_cfg_valid = !dmx_cfg_fifo_empty;
    assign ccm_cfg_valid = !ccm_cfg_fifo_empty;

    assign {srg0_cfg_data, srg0_nzl_head_addr, srg0_nzl_head_peid} = srg0_cfg_fifo_dout;
    assign {srg_cfg_data, srg_nzl_head_addr, srg_nzl_head_peid} = srg_cfg_fifo_dout;
    assign {drg_cfg_data, drg_cfg_nzn} = drg_cfg_fifo_dout;

    // Broadcast cfg_data to FIFOs

    localparam NUM_FIFO_CFG = 5;

    logic                       cfg_s_tvalid;
    logic                       cfg_s_tready;

    logic                       cfg_m_tvalid[NUM_FIFO_CFG-1:0];
    logic                       cfg_m_tready[NUM_FIFO_CFG-1:0];
    // cfg_t                       cfg_m_din[NUM_FIFO_CFG-1:0];

    axis_broadcast #(
        .C_AXIS_TDATA_WIDTH (CFG_BW         ),
        .C_NUM_MI_SLOTS     (NUM_FIFO_CFG   )
    ) axis_broadcast_fifo_cfg (
    	.aclk               (clk            ),
        .aresetn            (rstn           ),
        .s_axis_tvalid      (cfg_s_tvalid   ),
        .s_axis_tready      (cfg_s_tready   ),
        // .s_axis_tdata       (spm_cfg_data_o ),
        .m_axis_tvalid      (cfg_m_tvalid   ),
        .m_axis_tready      (cfg_m_tready   )
        // .m_axis_tdata       (cfg_m_din      )
    );
    
    assign cfg_s_tvalid       = spm_cfg_valid_o;
    assign spm_cfg_ready_i    = cfg_s_tready;

    assign cfg_m_tready[0]    = !srg0_cfg_fifo_full;
    assign srg0_cfg_fifo_push = cfg_m_tvalid[0] && cfg_m_tready[0];
    assign srg0_cfg_fifo_din  = {spm_cfg_data_o, nzl_head_addr, nzl_head_peid};

    assign cfg_m_tready[1]    = !srg_cfg_fifo_full;
    assign srg_cfg_fifo_push  = cfg_m_tvalid[1] && cfg_m_tready[1];
    assign srg_cfg_fifo_din   = {spm_cfg_data_o, nzl_head_addr, nzl_head_peid};

    assign cfg_m_tready[2]    = !drg_cfg_fifo_full;
    assign drg_cfg_fifo_push  = cfg_m_tvalid[2] && cfg_m_tready[2];
    assign drg_cfg_fifo_din   = {spm_cfg_data_o, spm_dout_nzn};

    assign cfg_m_tready[3]    = !dmx_cfg_fifo_full;
    assign dmx_cfg_fifo_push  = cfg_m_tvalid[3] && cfg_m_tready[3];
    assign dmx_cfg_fifo_din   = spm_cfg_data_o;

    assign cfg_m_tready[4]    = !ccm_cfg_fifo_full;
    assign ccm_cfg_fifo_push  = cfg_m_tvalid[4] && cfg_m_tready[4];
    assign ccm_cfg_fifo_din   = spm_cfg_data_o;


    // Broadcast spm_dout_nzn to FIFOs

    localparam NUM_FIFO_NZN = 4;

    logic                       nzn_s_tvalid;
    logic                       nzn_s_tready;

    logic                       nzn_m_tvalid[NUM_FIFO_NZN-1:0];
    logic                       nzn_m_tready[NUM_FIFO_NZN-1:0];
    // logic [$clog2(MAX_N)-1:0]   nzn_m_din[NUM_FIFO_NZN-1:0];

    axis_broadcast #(
        .C_AXIS_TDATA_WIDTH ($clog2(MAX_N)  ),
        .C_NUM_MI_SLOTS     (NUM_FIFO_NZN   )
    ) axis_broadcast_fifo_nzn (
    	.aclk               (clk            ),
        .aresetn            (rstn           ),
        .s_axis_tvalid      (nzn_s_tvalid   ),
        .s_axis_tready      (nzn_s_tready   ),
        // .s_axis_tdata       (spm_dout_nzn   ),
        .m_axis_tvalid      (nzn_m_tvalid   ),
        .m_axis_tready      (nzn_m_tready   )
        // .m_axis_tdata       (nzn_m_din      )
    );
    
    assign nzn_s_tvalid       = spm_nzn_valid_o;
    assign spm_nzn_ready_i    = nzn_s_tready;

    assign nzn_m_tready[0]    = !srg0_nzn_fifo_full;
    assign srg0_nzn_fifo_push = nzn_m_tvalid[0] && nzn_m_tready[0];
    assign srg0_nzn_fifo_din  = spm_dout_nzn;

    assign nzn_m_tready[1]    = !srg_nzn_fifo_full;
    assign srg_nzn_fifo_push  = nzn_m_tvalid[1] && nzn_m_tready[1];
    assign srg_nzn_fifo_din   = spm_dout_nzn;

    assign nzn_m_tready[2]    = !dmx_nzn_fifo_full;
    assign dmx_nzn_fifo_push  = nzn_m_tvalid[2] && nzn_m_tready[2];
    assign dmx_nzn_fifo_din   = spm_dout_nzn;

    assign nzn_m_tready[3]    = !ccm_nzn_fifo_full;
    assign ccm_nzn_fifo_push  = nzn_m_tvalid[3] && nzn_m_tready[3];
    assign ccm_nzn_fifo_din   = spm_dout_nzn;


    // Broadcast nzl_head_addr nzl_head_peid

    // assign srg0_nzl_head_addr = nzl_head_addr;
    // assign srg0_nzl_head_peid = nzl_head_peid;

    // assign srg_nzl_head_addr  = nzl_head_addr;
    // assign srg_nzl_head_peid  = nzl_head_peid;


// -----------------------------------------------------------------------------
// IPM - SMEM Read Request Generator (CH_S0)

    IPM_SRG0 #(
        // .NUM_PE         (NUM_PE             ),
        // .MAX_N          (MAX_N              ),
        // .MAX_M          (MAX_M              ),
        // .MAX_NoP        (MAX_NoP            ),

        .SMEM_WW        (SMEM_WW            ),
        .SMEM_DEPTH     (SMEM_DEPTH         )
    ) IPM_SRG0_INST (
        .clk            (clk                ),
        .rstn           (rstn               ),

        .cfg_valid      (srg0_cfg_valid     ),
        // .cfg_proc       (cfg_proc           ),
        // .cfg_cnt0       (cfg_cnt0           ),
        // .cfg_cnt1       (cfg_cnt1           ),
        // .cfg_cnt2       (cfg_cnt2           ),
        .cfg_data       (srg0_cfg_data      ),
        .cfg_ready      (srg0_cfg_ready     ),

        .smem_addr0     (smem_addr0         ),
        .nzl_head_addr  (srg0_nzl_head_addr ),
        .nzl_head_peid  (srg0_nzl_head_peid ),

        .din_nzn        (srg0_din_nzn       ),
        .pop_nzn        (srg0_pop_nzn       ),
        .empty_nzn      (srg0_nzn_fifo_empty),

        .rd_wsel        (rd_wsel  [0:0]     ),
        .rd_addr        (rd_addr  [0:0]     ),
        .rd_avalid      (rd_avalid[0:0]     ),
        .rd_aready      (rd_aready[0:0]     )
    );
    
    
    FIFO_STD #(
        .WIDTH          (SRG0_CFG_FIFO_WIDTH),
        .DEPTH          (SRG0_CFG_FIFO_DEPTH),
        .FWFT           (1                  )
    ) FIFO_SRG0_CFG (
        .clk            (clk                ),
        .rstn           (rstn               ),
        .push           (srg0_cfg_fifo_push ),
        .pop            (srg0_cfg_fifo_pop  ),
        .empty          (srg0_cfg_fifo_empty),
        .full           (srg0_cfg_fifo_full ),
        .din            (srg0_cfg_fifo_din  ),
        .dout           (srg0_cfg_fifo_dout )
    );
    

    FIFO_STD #(
        .WIDTH          (SRG0_NZN_FIFO_WIDTH),
        .DEPTH          (SRG0_NZN_FIFO_DEPTH),
        .FWFT           (1                  )
    ) FIFO_SRG0_NZN (
        .clk            (clk                ),
        .rstn           (rstn               ),
        .push           (srg0_nzn_fifo_push ),
        .pop            (srg0_pop_nzn       ),
        .empty          (srg0_nzn_fifo_empty),
        .full           (srg0_nzn_fifo_full ),
        .din            (srg0_nzn_fifo_din  ),
        .dout           (srg0_din_nzn       )
    );
    

// -----------------------------------------------------------------------------
// IPM - SMEM Read Request Generator (CH_S0)

    IPM_DRG #(
        // .NUM_PE         (NUM_PE             ),
        // .MAX_N          (MAX_N              ),
        // .MAX_M          (MAX_M              ),
        // .MAX_NoP        (MAX_NoP            ),

        .AXI_DM_CMD_WIDTH (AXI_DM_CMD_WIDTH ),
        .DRAM_ADDR_BW     (DRAM_ADDR_BW     ),
        .BTT_BW           (BTT_BW           ),
        .AXI_DM_CMD_BASE  (AXI_DM_CMD_BASE  )
    ) IPM_DRG_INST(
        .clk            (clk                ),
        .rstn           (rstn               ),
        .cfg_valid      (drg_cfg_valid      ),
        .cfg_data       (drg_cfg_data       ),
        .cfg_ready      (drg_cfg_ready      ),
        .cfg_nzn        (drg_cfg_nzn        ),
        .dram_addr      (dram_addr0         ),
        .din_nzi        (drg_din_nzi        ),
        .pop_nzi        (drg_pop_nzi        ),
        .empty_nzi      (drg_nzi_fifo_empty ),
        .cmd_tvalid     (drg_cmd_tvalid     ),
        .cmd_tdata      (drg_cmd_tdata      ),
        .cmd_tready     (drg_cmd_tready     )
    );

    assign drg_cmd_tready = 1'b1;
    

    FIFO_STD #(
        .WIDTH          (DRG_CFG_FIFO_WIDTH ),
        .DEPTH          (DRG_CFG_FIFO_DEPTH ),
        .FWFT           (1                  )
    ) FIFO_DRG_CFG (
        .clk            (clk                ),
        .rstn           (rstn               ),
        .push           (drg_cfg_fifo_push  ),
        .pop            (drg_cfg_fifo_pop   ),
        .empty          (drg_cfg_fifo_empty ),
        .full           (drg_cfg_fifo_full  ),
        .din            (drg_cfg_fifo_din   ),
        .dout           (drg_cfg_fifo_dout  )
    );
    

    FIFO_STD #(
        .WIDTH          (DRG_NZI_FIFO_WIDTH ),
        .DEPTH          (DRG_NZI_FIFO_DEPTH ),
        .FWFT           (1                  )
    ) FIFO_DRG_NZI (
        .clk            (clk                ),
        .rstn           (rstn               ),
        .push           (drg_nzi_fifo_push  ),
        .pop            (drg_pop_nzi        ),
        .empty          (drg_nzi_fifo_empty ),
        .full           (drg_nzi_fifo_full  ),
        .din            (drg_nzi_fifo_din   ),
        .dout           (drg_din_nzi        )
    );
    

    // assign rd_dready[0] = !dmx_nzi_fifo_full;
    // assign dmx_nzi_fifo_push = rd_dvalid[0] && !dmx_nzi_fifo_full && (IPM_DMX_INST.cfg_proc_r == PROC_VXV_SP);
    // // assign rd_dready[0] = !dmx_nzi_fifo_full && !dram_full;     //////
    // // assign dmx_nzi_fifo_push = rd_dvalid[0] && !dmx_nzi_fifo_full && !dram_full && (cfg_proc == PROC_VXV_SP);   //////
    // assign dmx_nzi_fifo_din = rd_dout[0][rd_dwsel[0][WSEL_BW-1-1:0]];
    

    // Broadcast rd_dout[0] (NZI) to FIFOs

    localparam NUM_FIFO_NZI = 2;

    logic                       nzi_s_tvalid;
    logic                       nzi_s_tready;

    logic                       nzi_m_tvalid[NUM_FIFO_NZI-1:0];
    logic                       nzi_m_tready[NUM_FIFO_NZI-1:0];
    // logic [$clog2(MAX_N)-1:0]   nzi_m_din[NUM_FIFO_NZI-1:0];

    axis_broadcast #(
        .C_AXIS_TDATA_WIDTH ($clog2(MAX_N)  ),
        .C_NUM_MI_SLOTS     (NUM_FIFO_NZI   )
    ) axis_broadcast_fifo_nzi (
    	.aclk               (clk            ),
        .aresetn            (rstn           ),
        .s_axis_tvalid      (nzi_s_tvalid   ),
        .s_axis_tready      (nzi_s_tready   ),
        // .s_axis_tdata       (rd_dout[0][rd_dwsel[0][WSEL_BW-1-1:0]]),
        .m_axis_tvalid      (nzi_m_tvalid   ),
        .m_axis_tready      (nzi_m_tready   )
        // .m_axis_tdata       (nzi_m_din      )
    );
    
    assign nzi_s_tvalid       = rd_dvalid[0];
    assign rd_dready[0]       = nzi_s_tready;

    assign nzi_m_tready[0]    = !drg_nzi_fifo_full;
    assign drg_nzi_fifo_push  = nzi_m_tvalid[0] && nzi_m_tready[0] && (IPM_DRG_INST.cfg_proc_r inside {PROC_MxV_SP, PROC_MTxV_SP});
    assign drg_nzi_fifo_din   = rd_dout[0][rd_dwsel[0][WSEL_BW-1-1:0]];

    assign nzi_m_tready[1]    = !dmx_nzi_fifo_full;
    assign dmx_nzi_fifo_push  = nzi_m_tvalid[1] && nzi_m_tready[1] && (IPM_DMX_INST.cfg_proc_r == PROC_VXV_SP);
    assign dmx_nzi_fifo_din   = rd_dout[0][rd_dwsel[0][WSEL_BW-1-1:0]];


// -----------------------------------------------------------------------------
// IPM - SMEM Read Request Generator (CH_S1-2)

    IPM_SRG #(
        // .NUM_PE         (NUM_PE             ),
        // .MAX_N          (MAX_N              ),
        // .MAX_M          (MAX_M              ),
        // .MAX_NoP        (MAX_NoP            ),

        .SMEM_WW        (SMEM_WW            ),
        .SMEM_DEPTH     (SMEM_DEPTH         )
    ) IPM_SRG_INST (
        .clk            (clk                ),
        .rstn           (rstn               ),

        .cfg_valid      (srg_cfg_valid      ),
        // .cfg_proc       (cfg_proc           ),
        // .cfg_nt         (cfg_nt             ),
        // .cfg_t          (cfg_t              ),
        // .cfg_cnt0       (cfg_cnt0           ),
        // .cfg_cnt1       (cfg_cnt1           ),
        // .cfg_cnt2       (cfg_cnt2           ),
        .cfg_data       (srg_cfg_data       ),
        .cfg_ready      (srg_cfg_ready      ),

        .smem_addr1     (smem_addr1         ),
        .smem_addr2     (smem_addr2         ),
        .nzl_head_addr  (srg_nzl_head_addr  ),
        .nzl_head_peid  (srg_nzl_head_peid  ),

        .din_nzn        (srg_din_nzn        ),
        .pop_nzn        (srg_pop_nzn        ),

        .rd_wsel        (rd_wsel  [2:1]     ),
        .rd_addr        (rd_addr  [2:1]     ),
        .rd_avalid      (rd_avalid[2:1]     ),
        .rd_aready      (rd_aready[2:1]     )
    );
    
    
    FIFO_STD #(
        .WIDTH          (SRG_CFG_FIFO_WIDTH ),
        .DEPTH          (SRG_CFG_FIFO_DEPTH ),
        .FWFT           (1                  )
    ) FIFO_SRG_CFG (
        .clk            (clk                ),
        .rstn           (rstn               ),
        .push           (srg_cfg_fifo_push  ),
        .pop            (srg_cfg_fifo_pop   ),
        .empty          (srg_cfg_fifo_empty ),
        .full           (srg_cfg_fifo_full  ),
        .din            (srg_cfg_fifo_din   ),
        .dout           (srg_cfg_fifo_dout  )
    );
    

    FIFO_STD #(
        .WIDTH          (SRG_NZN_FIFO_WIDTH ),
        .DEPTH          (SRG_NZN_FIFO_DEPTH ),
        .FWFT           (1                  )
    ) FIFO_SRG_NZN (
        .clk            (clk                ),
        .rstn           (rstn               ),
        .push           (srg_nzn_fifo_push  ),
        .pop            (srg_pop_nzn        ),
        .empty          (srg_nzn_fifo_empty ),
        .full           (srg_nzn_fifo_full  ),
        .din            (srg_nzn_fifo_din   ),
        .dout           (srg_din_nzn        )
    );
    

// -----------------------------------------------------------------------------
// Shared Memory Controller

    SMEM #(
        // .NUM_PE         (NUM_PE            ),
        .SMEM_WW        (SMEM_WW           ),

        // .MAX_N          (MAX_N             ),
        // .MAX_M          (MAX_M             ),
        // .MAX_NoP        (MAX_NoP           ),
        .SMEM_DEPTH     (SMEM_DEPTH        ),

        .NUM_CH_RD      (NUM_CH_RD         ),
        .NUM_CH_WR      (NUM_CH_WR         ),

        .BUF_IN_DEPTH   (SMEM_BUF_IN_DEPTH ),
        .BUF_MID_DEPTH  (SMEM_BUF_MID_DEPTH),
        .BUF_OUT_DEPTH  (SMEM_BUF_OUT_DEPTH)
    ) SMEM_INST (
        .clk            (clk               ),
        .rstn           (rstn              ),

        .rd_wsel        (rd_wsel           ),
        .rd_addr        (rd_addr           ),
        .rd_avalid      (rd_avalid         ),
        .rd_aready      (rd_aready         ),
        .rd_dout        (rd_dout           ),
        .rd_dwsel       (rd_dwsel          ),
        // .rd_dstrobe     (rd_dstrobe        ),
        .rd_dvalid      (rd_dvalid         ),
        .rd_dready      (rd_dready         ),

        .wr_wsel        (wr_wsel           ),
        .wr_addr        (wr_addr           ),
        .wr_avalid      (wr_avalid         ),
        .wr_aready      (wr_aready         ),
        .wr_din         (wr_din            )
    );
    

    // assgin rd_dready[0] = 1'b1;
    
    // assign rd_avalid[1] = 1'b0;
    // assign rd_dready[1] = 1'b1;

    // assign rd_avalid[2] = 1'b0;
    // assign rd_dready[2] = 1'b1;

    // assign wr_avalid[0] = 1'b0;

    // assign wr_avalid[1] = 1'b0;


// -----------------------------------------------------------------------------
// IPM - Data Multiplexer

    IPM_DMX #(
        // .NUM_PE         (NUM_PE             ),
        // .MAX_N          (MAX_N              ),
        // .MAX_M          (MAX_M              ),
        // .MAX_NoP        (MAX_NoP            ),

        .SMEM_WW        (SMEM_WW            )

        // .sig_width      (sig_width          ),
        // .exp_width      (exp_width          ),
        // .ieee_compliance(ieee_compliance    )
    ) IPM_DMX_INST (
        .clk            (clk                ),
        .rstn           (rstn               ),

        .cfg_valid      (dmx_cfg_valid      ),
        // .cfg_proc       (cfg_proc           ),
        // .cfg_cnt0       (cfg_cnt0           ),
        // .cfg_cnt1       (cfg_cnt1           ),
        // .cfg_cnt2       (cfg_cnt2           ),
        .cfg_data       (dmx_cfg_data       ),
        .cfg_ready      (dmx_cfg_ready      ),

        .din_nzn        (dmx_din_nzn        ),
        .pop_nzn        (dmx_pop_nzn        ),

        .din_nzi        (dmx_din_nzi        ),
        .pop_nzi        (dmx_pop_nzi        ),

        .dram_data      (dram_data          ),
        .dram_empty     (dram_empty         ),
        .dram_pop       (dram_pop           ),

        .smem1_data     (smem1_data         ),
        .smem1_dwsel    (smem1_dwsel        ),
        .smem1_empty    (smem1_empty        ),
        .smem1_pop      (smem1_pop          ),

        .smem2_data     (smem2_data         ),
        .smem2_dwsel    (smem2_dwsel        ),
        .smem2_empty    (smem2_empty        ),
        .smem2_pop      (smem2_pop          ),

        .dout_act       (dmx_dout_act       ),
        .dout_weight    (dmx_dout_weight    ),
        .dout_nzi       (dmx_dout_nzi       ),
        .en_hist_nzi    (en_hist_nzi        ),
        .valid_o        (dmx_valid_o        ),
        .ready_i        (dmx_ready_i        )
    );


    FIFO_STD #(
        .WIDTH          (DMX_CFG_FIFO_WIDTH ),
        .DEPTH          (DMX_CFG_FIFO_DEPTH ),
        .FWFT           (1                  )
    ) FIFO_DMX_CFG (
        .clk            (clk                ),
        .rstn           (rstn               ),
        .push           (dmx_cfg_fifo_push  ),
        .pop            (dmx_cfg_fifo_pop   ),
        .empty          (dmx_cfg_fifo_empty ),
        .full           (dmx_cfg_fifo_full  ),
        .din            (dmx_cfg_fifo_din   ),
        .dout           (dmx_cfg_data       )
    );
    

    FIFO_STD #(
        .WIDTH          (DMX_NZN_FIFO_WIDTH ),
        .DEPTH          (DMX_NZN_FIFO_DEPTH ),
        .FWFT           (1                  )
    ) FIFO_DMX_NZN (
        .clk            (clk                ),
        .rstn           (rstn               ),
        .push           (dmx_nzn_fifo_push  ),
        .pop            (dmx_pop_nzn        ),
        .empty          (dmx_nzn_fifo_empty ),
        .full           (dmx_nzn_fifo_full  ),
        .din            (dmx_nzn_fifo_din   ),
        .dout           (dmx_din_nzn        )
    );
    
    FIFO_STD #(
        .WIDTH          (DMX_NZI_FIFO_WIDTH ),
        .DEPTH          (DMX_NZI_FIFO_DEPTH ),
        .FWFT           (0                  )
    ) FIFO_DMX_NZI (
        .clk            (clk                ),
        .rstn           (rstn               ),
        .push           (dmx_nzi_fifo_push  ),
        .pop            (dmx_pop_nzi        ),
        .empty          (dmx_nzi_fifo_empty ),
        .full           (dmx_nzi_fifo_full  ),
        .din            (dmx_nzi_fifo_din   ),
        .dout           (dmx_din_nzi        )
    );


    FIFO_STD #(
        .WIDTH          (FIFO_DRAM_WIDTH    ),
        .DEPTH          (FIFO_DRAM_DEPTH    ),
        .FWFT           (0                  )
    ) FIFO_DMX_DRAM (
        .clk            (clk                ),
        .rstn           (rstn               ),
        .push           (dram_push          ),
        .pop            (dram_pop           ),
        .empty          (dram_empty         ),
        .full           (dram_full          ),
        .din            (dram_fifo_din      ),
        .dout           (dram_fifo_dout     )
    );

    FIFO_STD #(
        .WIDTH          (FIFO_SMEM1_WIDTH   ),
        .DEPTH          (FIFO_SMEM1_DEPTH   ),
        .FWFT           (0                  )
    ) FIFO_DMX_SMEM1 (
        .clk            (clk                ),
        .rstn           (rstn               ),
        .push           (smem1_push         ),
        .pop            (smem1_pop          ),
        .empty          (smem1_empty        ),
        .full           (smem1_full         ),
        .din            (smem1_fifo_din     ),
        .dout           (smem1_fifo_dout    )
    );
    
    FIFO_STD #(
        .WIDTH          (FIFO_SMEM2_WIDTH   ),
        .DEPTH          (FIFO_SMEM2_DEPTH   ),
        .FWFT           (0                  )
    ) FIFO_DMX_SMEM2 (
        .clk            (clk                ),
        .rstn           (rstn               ),
        .push           (smem2_push         ),
        .pop            (smem2_pop          ),
        .empty          (smem2_empty        ),
        .full           (smem2_full         ),
        .din            (smem2_fifo_din     ),
        .dout           (smem2_fifo_dout    )
    );
    

    // DRAM : {PE00, PE01, PE02, ...}
    // SMEM : {WSEL, PE00, PE01, PE02, ...}

    generate
        for (genvar pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
            // assign dram_fifo_din [DRAM_WW*(pe_idx) +: DRAM_WW] = dram_fifo_data [NUM_PE-1-pe_idx];
            assign smem1_fifo_din[SMEM_WW*(pe_idx) +: SMEM_WW] = smem1_fifo_data[NUM_PE-1-pe_idx];
            assign smem2_fifo_din[SMEM_WW*(pe_idx) +: SMEM_WW] = smem2_fifo_data[NUM_PE-1-pe_idx];
        end
        assign smem1_fifo_din[FIFO_SMEM1_WIDTH-1 -: WSEL_BW] = smem1_fifo_dwsel;
        assign smem2_fifo_din[FIFO_SMEM2_WIDTH-1 -: WSEL_BW] = smem2_fifo_dwsel;
    endgenerate

    generate
        for (genvar pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
            assign dram_data [pe_idx] = dram_fifo_dout [DRAM_WW*(NUM_PE-1-pe_idx) +: DRAM_WW];
            assign smem1_data[pe_idx] = smem1_fifo_dout[SMEM_WW*(NUM_PE-1-pe_idx) +: SMEM_WW];
            assign smem2_data[pe_idx] = smem2_fifo_dout[SMEM_WW*(NUM_PE-1-pe_idx) +: SMEM_WW];
        end
        assign smem1_dwsel = smem1_fifo_dout[FIFO_SMEM1_WIDTH-1 -: WSEL_BW];
        assign smem2_dwsel = smem2_fifo_dout[FIFO_SMEM2_WIDTH-1 -: WSEL_BW];
    endgenerate

    assign dram_push  = dram_fifo_wen  && !dram_full;
    assign smem1_push = rd_dvalid[1] && !smem1_full;
    assign smem2_push = rd_dvalid[2] && !smem2_full;

    assign rd_dready[1] = !smem1_full;
    assign rd_dready[2] = !smem2_full;
    
    assign smem1_fifo_data[0:NUM_PE-1] = rd_dout[1][0:NUM_PE-1];
    assign smem2_fifo_data[0:NUM_PE-1] = rd_dout[2][0:NUM_PE-1];
    assign smem1_fifo_dwsel = rd_dwsel[1];
    assign smem2_fifo_dwsel = rd_dwsel[2];


// -----------------------------------------------------------------------------
// Compute Core Module
    
    CCM #(
        // .NUM_PE             (NUM_PE),
        // .MAX_N              (MAX_N),
        // .MAX_M              (MAX_M),
        // .MAX_NoP            (MAX_NoP),

        // .sig_width          (sig_width),
        // .exp_width          (exp_width),
        // .ieee_compliance    (ieee_compliance),
        
        // .NUM_FUNC           (NUM_FUNC),
        .LMEM_MAC_DEPTH     (LMEM_MAC_DEPTH),
        .LMEM_ACC_DEPTH     (LMEM_ACC_DEPTH)
    ) CCM_INST (
        .clk                (clk),
        .rstn               (rstn),

        .cfg_valid          (ccm_cfg_valid),
        // .cfg_proc           (cfg_proc),
        // .cfg_func           (cfg_func),
        // .cfg_cnt0           (cfg_cnt0),
        // .cfg_cnt1           (cfg_cnt1),
        // .cfg_cnt2           (cfg_cnt2),
        .cfg_data           (ccm_cfg_data ),
        .cfg_ready          (ccm_cfg_ready),

        .din_nzn            (ccm_din_nzn),
        .pop_nzn            (ccm_pop_nzn),

        .din_act            (ccm_din_act),
        .din_weight         (ccm_din_weight),
        .din_nzi            (ccm_din_nzi),
        .valid_i            (ccm_valid_i),
        .ready_o            (ccm_ready_o),

        .valid_o            (ccm_valid_o),
        .ready_i            (ccm_ready_i),
        .dout_act           (ccm_dout_act)
    );
    
    
    assign ccm_din_act = dmx_dout_act;
    assign ccm_din_weight = dmx_dout_weight;
    assign ccm_din_nzi = dmx_dout_nzi;

    
    // Record NZI history, delay CCM input to prevent RAW hazard

    // assign ccm_valid_i = dmx_valid_o && hist_ready_o;
    // assign ccm_valid_i = dmx_valid_o && (hist_ready_o || (cfg_proc inside {PROC_MxV_SP, PROC_MTxV_SP}));    //////
    assign ccm_valid_i = dmx_valid_o && (hist_ready_o || !en_hist_nzi);    //////

    assign hist_nzi[0] = ccm_din_nzi;
    assign hist_nzi_v[0] = dmx_valid_o && hist_ready_o; // ccm_ready_o;

    always_ff @(posedge clk) begin
        for (int idx = 1; idx <= 3; idx++) begin
            if (!rstn) begin
                hist_nzi[idx] <= '0;
                hist_nzi_v[idx] <= 1'b0;
            end else if (ccm_ready_o) begin
                hist_nzi[idx] <= hist_nzi[idx-1];
                hist_nzi_v[idx] <= hist_nzi_v[idx-1];
            end
        end
    end

    always_comb begin
        hist_ready_o = 1'b1;
        for (int idx = 1; idx <= 3; idx++) begin
            if ((hist_nzi[0] == hist_nzi[idx]) && (hist_nzi_v[idx])) begin
                hist_ready_o = 1'b0;
                break;
            end
        end
        // if (cfg_proc inside {PROC_MxV_SP, PROC_MTxV_SP})    //////
        if (!en_hist_nzi)   //////
            hist_ready_o = 1'b0;
    end

    // assign dmx_ready_i = ccm_ready_o && hist_ready_o;
    // assign dmx_ready_i = ccm_ready_o && (hist_ready_o || (cfg_proc inside {PROC_MxV_SP, PROC_MTxV_SP}));    //////
    assign dmx_ready_i = ccm_ready_o && (hist_ready_o || !en_hist_nzi);    //////


    FIFO_STD #(
        .WIDTH          (CCM_CFG_FIFO_WIDTH ),
        .DEPTH          (CCM_CFG_FIFO_DEPTH ),
        .FWFT           (1                  )
    ) FIFO_CCM_CFG (
        .clk            (clk                ),
        .rstn           (rstn               ),
        .push           (ccm_cfg_fifo_push  ),
        .pop            (ccm_cfg_fifo_pop   ),
        .empty          (ccm_cfg_fifo_empty ),
        .full           (ccm_cfg_fifo_full  ),
        .din            (ccm_cfg_fifo_din   ),
        .dout           (ccm_cfg_data       )
    );
    

    FIFO_STD #(
        .WIDTH          (CCM_NZN_FIFO_WIDTH ),
        .DEPTH          (CCM_NZN_FIFO_DEPTH ),
        .FWFT           (1                  )
    ) FIFO_CCM_NZN (
        .clk            (clk                ),
        .rstn           (rstn               ),
        .push           (ccm_nzn_fifo_push  ),
        .pop            (ccm_pop_nzn        ),
        .empty          (ccm_nzn_fifo_empty ),
        .full           (ccm_nzn_fifo_full  ),
        .din            (ccm_nzn_fifo_din   ),
        .dout           (ccm_din_nzn        )
    );
    

// -----------------------------------------------------------------------------
// Testbench Debug Blocks

    // // generate
        // // for (genvar pe_idx=0; pe_idx<NUM_PE; pe_idx++) begin
            // // assign BPE[pe_idx] = CCM_DUT.genblk1[pe_idx].BRAM_PE.BRAM;
        // // end
    // // endgenerate
    
    
    
    // generate
        // for (genvar pe_idx=NUM_PE-1; pe_idx>=0; pe_idx--) begin
            // initial begin
                // #1000?
                // // // fo = $fopen("../../../../bram_out.mem", "a");
                // $fwrite(fo, "// CCM_DUT.genblk1[%0d].BRAM_PE.BRAM\n", pe_idx);
                // for (int idx=0; idx<BRAM_PE_DEPTH; idx++) begin
                    // $fwrite(fo, "%d", $signed(CCM_DUT.genblk1[pe_idx].BRAM_PE.BRAM[idx]));
                    // if (idx % 4 != 3) $fwrite(fo, " ");
                        // else $fwrite(fo, "\n");
                // end
                // // // $fclose(fo);
            // end
        // end
    // endgenerate
    
    
// -----------------------------------------------------------------------------

    // initial begin
    //     // fo = $fopen("../../../../bram_out.mem", "w");
    //     #T_SIM
    //     // $fclose(fo);
        
    //     // // fo = $fopen("../../../../bram_out.mem", "w");
    //     // // $fwrite(fo, "// CCM_DUT.genblk1[%0d].BRAM_PE.BRAM\n", 0);
    //     // // for (idx=0; idx<BRAM_PE_DEPTH; idx++) begin
    //         // // $fwrite(fo, "%h", CCM_DUT.genblk1[0].BRAM_PE.BRAM[idx]);
    //         // // if (idx % 4 != 3) $fwrite(fo, " ");
    //             // // else $fwrite(fo, "\n");
    //     // // end
    //     // // $fclose(fo);
        
    //     // // fo = $fopen("../../../../bram_out.mem", "w");
    //     // // for (int pe_idx=0; pe_idx<NUM_PE; pe_idx++) begin
    //         // // $fwrite(fo, "// CCM_DUT.genblk1[%0d].BRAM_PE.BRAM\n", pe_idx);
    //         // // for (int idx=0; idx<BRAM_PE_DEPTH; idx++) begin
    //             // // $fwrite(fo, "%h", BPE[pe_idx][idx]);
    //             // // if (idx % 4 != 3) $fwrite(fo, " ");
    //                 // // else $fwrite(fo, "\n");
    //         // // end
    //     // // end
    //     // // $fclose(fo);
        
    //     $finish;
    // end
    
    
    
    // assign f_cur = {CCM_DUT.f_I};
    
    // always @(posedge clk) begin
    //     f_prev <= f_cur;
    // end
    
    // assign TE_f = |(f_prev & ~f_cur);   // Trailing edge
    // assign TG_f = |(f_prev ^ f_cur);    // Toggle
    
    
    
    // ---------------- IPM_SPM - Output Ready ----------------
    // initial begin
    //     $srandom(0);
        
    //     spm_ready_i = 1'b0;
    //     #1;
    //     #10;

    //     spm_ready_i = 1'b1;
    // end
    

    // ---------------- CCM - Output Ready ----------------
    initial begin: IB_ccm_ready_i
        $srandom(0);
        
        ccm_ready_i = 1'b0;
        #1;
        #10;
        
`ifndef TREADY_I_RND
        ccm_ready_i = 1'b1;
`else
        while ($stime < T_SIM) begin
            // ccm_ready_i = 1'b1;
            ccm_ready_i = |($urandom_range(0, 3));
            #($urandom_range(0, 4)*10);
        end
`endif
    end
    
    
// -----------------------------------------------------------------------------
// Config Modules - 1 sample

    task automatic train_sample (
        input int    s_idx = 0,                 // Sample index
        input int    l_idx = 0                  // Layer index
    );
        // -------------------- MxV_SP --------------------

        file2SPM(
            .file_name      ($sformatf("%s/x_del_nzp_l1_s%0d.dat", dir, s_curr)),
            .file_offset    (0),
            .s_idx          (s_curr)
        );
        
        file2DRAM(
            .str_stage      ("[MxV_SP]"),
            .file_name      ($sformatf("%s/Wx_l1.dat", dir)),
            .file_offset    (0),
            .dram_size      (Nh[l_curr]*1/NUM_PE*Nh[l_curr-1]),
            .dram_offset    (0)
        );

        file2SMEM_nzl(
            .str_stage      ("[MxV_SP]"),
            .file_name      ($sformatf("%s/x_del_nzl_l1_s%0d.dat", dir, s_curr)),
            .file_offset    (0),
            .s_idx          (s_curr)
            // .addr_nzil      (SMEM_ADDR_M0),
            // .addr_nzvl      (SMEM_ADDR_M1)
        );
        #10;

        file2DOV(
            .str_stage      ("[MxV_SP]"),
            .file_name      ($sformatf("%s/Mx_l1_s%0d.dat", dir, s_curr)),
            .file_offset    (0),
            .dov_size       (Nh[l_curr]*1/NUM_PE*Nt[s_curr]),
            .dov_offset     (0)
        );

        time_start  = $stime;

        for (t_curr=0; t_curr<Nt[s_curr]; t_curr++) begin: FL_train_MxV_SP
            spm_cfg_valid = 1'b1;
            cfg_data.proc   = PROC_MxV_SP;
            cfg_data.nt     = Nt[s_curr];
            cfg_data.t      = t_curr;
            cfg_data.func   = FUNC_NONE;
            cfg_data.cnt0   = 0;                        // Nt
            cfg_data.cnt1   = 'X;                       // Not used in MxV_SP
            cfg_data.cnt2   = Nh[l_curr]/NUM_PE - 1;    // N(l)/Np
            cfg_data.n1     = Nh[l_curr-1];
            spm_addr    = SPM_ADDR_M0;
            smem_addr0  = SMEM_ADDR_M0;
            smem_addr1  = SMEM_ADDR_M1;
            smem_addr2  = 'X;
            dram_addr0  = DRAM_ADDR_0;

            // Wait for IPM_SPM configured
            #9;
            while (!spm_cfg_ready && spm_cfg_valid) #10;
            #1;
            
            spm_cfg_valid = 1'b0;
            spm_addr    = 'X;
            cfg_ready_all = 1'b0;
            
            // Wait for IPM_SPM valid_o (nzl_head_addr nzl_head_peid valid)
            #9;
            while (!spm_cfg_valid_o) #10;   // while (!spm_valid_o) #10;
            #1;

            // srg0_cfg_valid = 1'b1;
            // srg_cfg_valid = 1'b1;
            // dmx_cfg_valid = 1'b1;
            // ccm_cfg_valid = 1'b1;
            
            fork
                begin
                    // Wait for IPM_SRG0 configured
                    #9;
                    while (!srg0_cfg_ready && srg0_cfg_valid) #10;
                    ->event_DRAM_NZIL;
                    #1;

                    // srg0_cfg_valid = 1'b0;
                    smem_addr0  = 'X;

                    // Wait for IPM_SRG0 finished
                    #9;
                    while (!srg0_cfg_ready) #10;
                    #1;
                end

                begin
                    // Wait for IPM_SRG configured
                    #9;
                    while (!srg_cfg_ready && srg_cfg_valid) #10;
                    #1;

                    // srg_cfg_valid = 1'b0;
                    smem_addr1  = 'X;
                    smem_addr2  = 'X;

                    // Wait for IPM_SRG finished
                    #9;
                    while (!srg_cfg_ready) #10;
                    #1;

                    #40;
                end
                
                begin
                    // Wait for IPM_DMX configured
                    #9;
                    while (!dmx_cfg_ready && dmx_cfg_valid) #10;
                    #1;

                    // dmx_cfg_valid = 1'b0;

                    // Wait for IPM_DMX finished
                    // #9;
                    // while (!dmx_cfg_ready) #10;
                    // #1;
                end
                
                begin
                    // Wait for CCM configured
                    #9;
                    while (!ccm_cfg_ready && ccm_cfg_valid) #10;
                    ->event_CCM_output;
                    #1;

                    // ccm_cfg_valid = 1'b0;

                    // Wait for CCM finished
                    // #9;
                    // while (!ccm_cfg_ready) #10;
                    // #1;
                end
            join

            // All modules finished
            cfg_ready_all = 1'b1;

        end

        #9;
        while (!ccm_cfg_ready) #10;
        #1;

        $display("[MxV_SP] Time consumed = %0t.", $time - time_start);
        time_proc[0] = $time - time_start;
        
        
        // -------------------- MTxV_SP --------------------

        // file2SPM(
        //     .file_name      ($sformatf("%s/x_del_nzp_l1_s%0d.dat", dir, s_curr)),
        //     .file_offset    (0),
        //     .s_idx          (s_curr)
        // );
        
        // file2DRAM(
        //     .str_stage      ("[MTxV_SP]"),
        //     .file_name      ($sformatf("%s/Wx_l1.dat", dir)),
        //     .file_offset    (0),
        //     .dram_size      (Nh[l_curr]*1/NUM_PE*Nh[l_curr-1]),
        //     .dram_offset    (0)
        // );

        // file2SMEM_nzl(
        //     .str_stage      ("[MTxV_SP]"),
        //     .file_name      ($sformatf("%s/x_del_nzl_l1_s%0d.dat", dir, s_curr)),
        //     .file_offset    (0),
        //     .s_idx          (s_curr)
        //     // .addr_nzil      (SMEM_ADDR_M0),
        //     // .addr_nzvl      (SMEM_ADDR_M1)
        // );
        
        file2SMEM_dL_dMx(
            .str_stage      ("[MTxV_SP]"),
            .file_name      ($sformatf("%s/dL_dMx_l1_s%0d.dat", dir, s_curr)),
            .file_offset    (0),
            .s_idx          (s_curr),
            .l_idx          (l_curr)
            // .smem_offset    (SMEM_ADDR_M1)
        );
        #10;

        file2DOV(
            .str_stage      ("[MTxV_SP]"),
            .file_name      ($sformatf("%s/dL_ddx_l1_s%0d.dat", dir, s_curr)),
            .file_offset    (0),
            .dov_size       (Nh[l_curr-1]/NUM_PE*Nt[s_curr]),
            .dov_offset     (0)
        );

        time_start = $time;

        for (t_curr=Nt[s_curr]-1; t_curr>=0; t_curr--) begin: FL_train_MTxV_SP
            spm_cfg_valid = 1'b1;
            cfg_data.proc   = PROC_MTxV_SP;
            cfg_data.nt     = Nt[s_curr];
            cfg_data.t      = t_curr;
            cfg_data.func   = FUNC_NONE;
            cfg_data.cnt0   = 0;                        // Nt
            cfg_data.cnt1   = Nh[l_curr]/NUM_PE - 1;    // N(l)/Np
            cfg_data.cnt2   = 'X;                       // Not used in MTxV_SP
            cfg_data.n1     = Nh[l_curr-1];
            spm_addr    = SPM_ADDR_M0;
            smem_addr0  = SMEM_ADDR_M0;
            smem_addr1  = SMEM_ADDR_M1;
            smem_addr2  = 'X;
            dram_addr0  = DRAM_ADDR_0;

            // Wait for IPM_SPM configured
            #9;
            while (!spm_cfg_ready && spm_cfg_valid) #10;
            #1;
            
            spm_cfg_valid = 1'b0;
            spm_addr    = 'X;
            cfg_ready_all = 1'b0;
            
            // Wait for IPM_SPM valid_o (nzl_head_addr nzl_head_peid valid)
            #9;
            while (!spm_cfg_valid_o) #10;   // while (!spm_valid_o) #10;
            #1;

            // srg0_cfg_valid = 1'b1;
            // srg_cfg_valid = 1'b1;
            // dmx_cfg_valid = 1'b1;
            // ccm_cfg_valid = 1'b1;
            
            fork
                begin
                    // Wait for IPM_SRG0 configured
                    #9;
                    while (!srg0_cfg_ready && srg0_cfg_valid) #10;
                    ->event_DRAM_NZIL;
                    #1;

                    // srg0_cfg_valid = 1'b0;
                    smem_addr0  = 'X;

                    // Wait for IPM_SRG0 finished
                    #9;
                    while (!srg0_cfg_ready) #10;
                    #1;
                end

                begin
                    // Wait for IPM_SRG configured
                    #9;
                    while (!srg_cfg_ready && srg_cfg_valid) #10;
                    #1;

                    // srg_cfg_valid = 1'b0;
                    smem_addr1  = 'X;
                    smem_addr2  = 'X;

                    // Wait for IPM_SRG finished
                    #9;
                    while (!srg_cfg_ready) #10;
                    #1;
                end
                
                begin
                    // Wait for IPM_DMX configured
                    #9;
                    while (!dmx_cfg_ready && dmx_cfg_valid) #10;
                    #1;

                    // dmx_cfg_valid = 1'b0;

                    // Wait for IPM_DMX finished
                    #9;
                    while (!dmx_cfg_ready) #10;
                    #1;

                    #80;
                end
                
                begin
                    // Wait for CCM configured
                    #9;
                    while (!ccm_cfg_ready && ccm_cfg_valid) #10;
                    ->event_CCM_output;
                    #1;

                    // ccm_cfg_valid = 1'b0;

                    // Wait for CCM finished
                    // #9;
                    // while (!ccm_cfg_ready) #10;
                    // #1;
                end
            join

            // All modules finished
            cfg_ready_all = 1'b1;

        end

        #9;
        while (!ccm_cfg_ready) #10;
        #1;

        $display("[MTxV_SP] Time consumed = %0t.", $time - time_start);
        time_proc[1] = $time - time_start;
        

        // -------------------- VXV_SP --------------------

        // file2SPM(
        //     .file_name      ($sformatf("%s/x_del_nzp_l1_s%0d.dat", dir, s_curr)),
        //     .file_offset    (0),
        //     .s_idx          (s_curr)
        // );
        
        file2DRAM(
            .str_stage      ("[VXV_SP]"),
            .file_name      ($sformatf("%s/dL_dMx_l1_s%0d.dat", dir, s_curr)),
            .file_offset    (0),
            .dram_size      (Nh[l_curr]*1/NUM_PE*Nt[s_curr]),
            .dram_offset    (0)
        );

        file2SMEM_nzl(
            .str_stage      ("[VXV_SP]"),
            .file_name      ($sformatf("%s/x_del_nzl_l1_s%0d.dat", dir, s_curr)),
            .file_offset    (0),
            .s_idx          (s_curr)
            // .addr_nzil      (SMEM_ADDR_M0),
            // .addr_nzvl      (SMEM_ADDR_M1)
        );
        #10;
        
        file2DOV(
            .str_stage      ("[VXV_SP]"),
            .file_name      ($sformatf("%s/dL_dWx_l1_s%0d.dat", dir, s_curr)),
            .file_offset    (0),
            .dov_size       (Nh[l_curr]*1/NUM_PE*Nh[l_curr-1]),
            .dov_offset     (0)
        );

        time_start = $time;

        begin: FL_train_VxV_SP
            spm_cfg_valid = 1'b1;
            cfg_data.proc   = PROC_VXV_SP;
            cfg_data.nt     = Nt[s_curr];
            cfg_data.t      = 'X;                       // Not used in VXV_SP
            cfg_data.func   = FUNC_NONE;
            cfg_data.cnt0   = 'X;                       // Not used in VXV_SP
            cfg_data.cnt1   = Nt[s_curr]-1;             // Nt
            cfg_data.cnt2   = Nh[l_curr]/NUM_PE - 1;    // N(l)/Np
            cfg_data.n1     = Nh[l_curr-1];
            spm_addr    = SPM_ADDR_M0;
            smem_addr0  = SMEM_ADDR_M0;
            smem_addr1  = SMEM_ADDR_M1;
            smem_addr2  = 'X;
            dram_addr0  = DRAM_ADDR_0;

            // Wait for IPM_SPM configured
            #9;
            while (!spm_cfg_ready && spm_cfg_valid) #10;
            #1;
            
            spm_cfg_valid = 1'b0;
            spm_addr    = 'X;
            cfg_ready_all = 1'b0;
            
            // Wait for IPM_SPM valid_o (nzl_head_addr nzl_head_peid valid)
            #9;
            while (!spm_cfg_valid_o) #10;   // while (!spm_valid_o) #10;
            #1;

            // force nzl_head_addr = 0;
            // force nzl_head_peid = 0;
            reset_LMEM_MAC();

            // srg0_cfg_valid = 1'b1;
            // srg_cfg_valid = 1'b1;
            // dmx_cfg_valid = 1'b1;
            // ccm_cfg_valid = 1'b1;
            ->event_DRAM_dL_DM;
            
            fork
                begin
                    // Wait for IPM_SRG0 configured
                    #9;
                    while (!srg0_cfg_ready && srg0_cfg_valid) #10;
                    #1;

                    // srg0_cfg_valid = 1'b0;
                    smem_addr0  = 'X;

                    // Wait for IPM_SRG0 finished
                    #9;
                    while (!srg0_cfg_ready) #10;
                    #1;
                end

                begin
                    // Wait for IPM_SRG configured
                    #9;
                    while (!srg_cfg_ready && srg_cfg_valid) #10;
                    #1;

                    // srg_cfg_valid = 1'b0;
                    smem_addr1  = 'X;
                    smem_addr2  = 'X;

                    // Wait for IPM_SRG finished
                    #9;
                    while (!srg_cfg_ready) #10;
                    #1;

                    #40;
                end
                
                begin
                    // Wait for IPM_DMX configured
                    #9;
                    while (!dmx_cfg_ready && dmx_cfg_valid) #10;
                    #1;

                    // dmx_cfg_valid = 1'b0;

                    // Wait for IPM_DMX finished
                    // #9;
                    // while (!dmx_cfg_ready) #10;
                    // #1;
                end
                
                begin
                    // Wait for CCM configured
                    #9;
                    while (!ccm_cfg_ready && ccm_cfg_valid) #10;
                    ->event_CCM_output;
                    #1;

                    // ccm_cfg_valid = 1'b0;

                    // Wait for CCM finished
                    // #9;
                    // while (!ccm_cfg_ready) #10;
                    // #1;

                    for (int cnt2=0; cnt2<CCM_INST.cfg_cnt2_r1; cnt2++) begin   // cfg_cnt2
                        @(posedge CCM_INST.rst_lmem_mac) #1;
                        reset_LMEM_MAC();
                    end
                end
            join

            // All modules finished
            cfg_ready_all = 1'b1;

            // release nzl_head_addr;
            // release nzl_head_peid;

        end

        #9;
        while (!ccm_cfg_ready) #10;
        #1;

        // -------------------- Finish --------------------
        $display("[VXV_SP] Time consumed = %0t.", $time - time_start);
        time_proc[2] = $time - time_start;
        // write_csv();

    endtask


// -----------------------------------------------------------------------------
// DRAM Data Input - 1 sample

    task automatic DRAM_input_sample (
        input int    s_idx = 0,                 // Sample index
        input int    l_idx = 0                  // Layer index
    );
        automatic logic [DRAM_ADDR_BW-1:0] dram_base = 0;
        automatic logic [$clog2(MAX_N)-1:0] nzn_curr;
        automatic logic [$clog2(MAX_N)-1:0] nop_curr;
        automatic int t_idx;
        automatic int dat_idx;
        automatic int row_idx;
        automatic int pe_idx;
        automatic logic [WSEL_BW-1-1:0] wsel_tmp;
        automatic logic [$clog2(MAX_N)-1:0] nzi_temp;
        
    
        // -------------------- MxV_SP --------------------
        nop_curr = Nh[l_idx]/NUM_PE;   // cfg_cnt2+1;

        for (t_idx=0; t_idx<Nt[s_idx]; t_idx++) begin
            wait(event_DRAM_NZIL.triggered);
            // $display("event_DRAM_NZIL triggered.");
            
            nzn_curr = spm_dout_nzn+1;
            
            for (row_idx=0; row_idx<nop_curr; row_idx++) begin
                for (dat_idx=0; dat_idx<nzn_curr; dat_idx++) begin
                    #1;
                    dram_fifo_wen = 1'b0;
                    while (!rd_dvalid[0] || !rd_dready[0]) #10;
                    
                    wsel_tmp = rd_dwsel[0][WSEL_BW-1-1:0];
                    nzi_temp = rd_dout[0][wsel_tmp];
                    dram_addr = dram_base + Nh[l_idx-1]*row_idx + nzi_temp;

                    // $display("0x%08x", dram_addr);
                    // for(pe_idx=0; pe_idx<NUM_PE; pe_idx++) begin
                    //     $write("%4d ", $signed(DRAM[dram_addr][DRAM_WW*(NUM_PE-1-pe_idx) +: DRAM_WW]));
                    // end
                    // $write("\n");

                    dram_fifo_wen = 1'b1;
                    dram_fifo_din = DRAM[dram_addr];
                    if (dram_full) $display("[!!!] @%0t DRAM FIFO full!", $stime);
                    // while (dram_full) #10;   //////
                    
                    #9;
                end
            end

            #1;
            dram_fifo_wen = 1'b0;
        end
        

        // -------------------- MTxV_SP --------------------
        // nop_curr = Nh[l_idx]/NUM_PE;   // cfg_cnt2+1;

        for (t_idx=0; t_idx<Nt[s_idx]; t_idx++) begin
            wait(event_DRAM_NZIL.triggered);
            // $display("event_DRAM_NZIL triggered.");
            
            nzn_curr = spm_dout_nzn+1;
            
            for (dat_idx=0; dat_idx<nzn_curr; dat_idx++) begin
                for (row_idx=0; row_idx<nop_curr; row_idx++) begin
                    #1;
                    dram_fifo_wen = 1'b0;
                    if (row_idx == 0) begin     // Only read NZI once, not repeated by Nl/Np
                        while (!rd_dvalid[0] || !rd_dready[0]) #10;
                        
                        wsel_tmp = rd_dwsel[0][WSEL_BW-1-1:0];
                        nzi_temp = rd_dout[0][wsel_tmp];
                    end
                    dram_addr = dram_base + Nh[l_idx-1]*row_idx + nzi_temp;

                    // $display("0x%08x", dram_addr);
                    // for(pe_idx=0; pe_idx<NUM_PE; pe_idx++) begin
                    //     $write("%4d ", $signed(DRAM[dram_addr][DRAM_WW*(NUM_PE-1-pe_idx) +: DRAM_WW]));
                    // end
                    // $write("\n");

                    dram_fifo_wen = 1'b1;
                    dram_fifo_din = DRAM[dram_addr];
                    if (dram_full) $display("[!!!] @%0t DRAM FIFO full!", $stime);
                    // while (dram_full) #10;   //////
                    
                    #9;
                end
            end

            #1;
            dram_fifo_wen = 1'b0;
        end
        

        // -------------------- VXV_SP --------------------
        // nop_curr = Nh[l_idx]/NUM_PE;   // cfg_cnt2+1;
        
        wait(event_DRAM_dL_DM.triggered);

        for (row_idx=0; row_idx<nop_curr; row_idx++) begin
            for (t_idx=0; t_idx<Nt[s_idx]; t_idx++) begin
                dram_addr = dram_base + Nt[s_idx]*row_idx + t_idx;

                // $display("0x%08x", dram_addr);
                // for(pe_idx=0; pe_idx<NUM_PE; pe_idx++) begin
                //     $write("%4d ", $signed(DRAM[dram_addr][DRAM_WW*(NUM_PE-1-pe_idx) +: DRAM_WW]));
                // end
                // $write("\n");

                dram_fifo_wen = 1'b1;
                dram_fifo_din = DRAM[dram_addr];
                // if (dram_full) $display("[!!!] @%0t DRAM FIFO full!", $stime);
                #9
                while (dram_full) #10;
                #1;
            end
        end

        dram_fifo_wen = 1'b0;

        // -------------------- Finish --------------------

    endtask


// -----------------------------------------------------------------------------
// CCM Data Output Check - 1 sample

    task automatic CCM_output_sample (
        input int    s_idx = 0,                 // Sample index
        input int    l_idx = 0                  // Layer index
    );
        automatic logic [$clog2(MAX_N)-1:0] nzn_curr;
        automatic logic [$clog2(MAX_N)-1:0] nop_curr;
        automatic int t_idx;
        automatic int dat_idx;
        automatic int row_idx;
        automatic int pe_idx;
        automatic int dov_idx;
        // automatic logic [WSEL_BW-1-1:0] wsel_tmp;
        automatic logic [$clog2(MAX_N)-1:0] nzi_temp;
        automatic int num_err_chk;
        automatic logic f_err;
        
    
        // -------------------- MxV_SP --------------------
        nop_curr = Nh[l_idx]/NUM_PE;   // cfg_cnt2+1;
        num_err_chk = 0;

        for (t_idx=0; t_idx<Nt[s_idx]; t_idx++) begin
            wait(event_CCM_output.triggered);
            // $display("event_CCM_output triggered.");
            
            for (row_idx=0; row_idx<nop_curr; row_idx++) begin
                #1;
                while (!ccm_valid_o || !ccm_ready_i) #10;
                
                // for(pe_idx=0; pe_idx<NUM_PE; pe_idx++) begin
                //     $write("%4d ", $signed(ccm_dout_act[pe_idx]));
                // end
                // $write("\n");

                f_err = 1'b0;
                dov_idx = Nt[s_idx] * row_idx + t_idx;
                for(pe_idx=0; pe_idx<NUM_PE; pe_idx++) begin
                    if (ccm_dout_act[pe_idx] != DOV[dov_idx][DRAM_WW*(NUM_PE-1-pe_idx) +: DRAM_WW])
                        f_err = 1'b1;
                end
                if (f_err) num_err_chk += 1;

                #9;
            end

            #1;
        end

        if (num_err_chk > 0)
            $display("[!!!] [MxV_SP] CCM output incorrect! (num_err_chk = %0d)", num_err_chk);
        else
            $display("[MxV_SP] CCM output correct.");
        

        // -------------------- MTxV_SP --------------------
        // nop_curr = Nh[l_idx]/NUM_PE;   // cfg_cnt2+1;
        num_err_chk = 0;
        
        for (t_idx=Nt[s_idx]-1; t_idx>=0; t_idx--) begin
            wait(event_CCM_output.triggered);
            // $display("event_CCM_output triggered.");

            nzn_curr = dov_nzn[t_idx];
            
            for (dat_idx=0; dat_idx<nzn_curr; dat_idx++) begin
                #1;
                while (!ccm_valid_o || !ccm_ready_i) #10;
                nzi_temp = dov_nzi[t_idx][dat_idx];
                
                // $write("%4d ", $signed(ccm_dout_act[NUM_PE]));

                f_err = 1'b0;
                dov_idx = Nt[s_idx] * (nzi_temp / NUM_PE) + t_idx;
                pe_idx = nzi_temp % NUM_PE;
                if (ccm_dout_act[NUM_PE] != DOV[dov_idx][DRAM_WW*(NUM_PE-1-pe_idx) +: DRAM_WW])
                    f_err = 1'b1;
                if (f_err) num_err_chk += 1;

                #9;
            end

            // $write("\n");
            #1;
        end

        if (num_err_chk > 0)
            $display("[!!!] [MTxV_SP] CCM output incorrect! (num_err_chk = %0d)", num_err_chk);
        else
            $display("[MTxV_SP] CCM output correct.");
        

        // -------------------- VXV_SP --------------------
        // nop_curr = Nh[l_idx]/NUM_PE;   // cfg_cnt2+1;
        
        wait(event_CCM_output.triggered);
        // $display("event_CCM_output triggered.");

        for (row_idx=0; row_idx<nop_curr; row_idx++) begin
            t_idx = Nt[s_idx]-1;
            nzn_curr = dov_nzn[t_idx];
            for (dat_idx=0; dat_idx<nzn_curr; dat_idx++) begin
                #1;
                while (!ccm_valid_o || !ccm_ready_i) #10;
                nzi_temp = dov_nzi[t_idx][dat_idx];
                // $write("row_idx=%04d dat_idx=%04d nzi_temp=%04d\n", row_idx, dat_idx, nzi_temp); ////

                // $write("CCM:"); ////
                // for(pe_idx=0; pe_idx<NUM_PE; pe_idx++) begin
                //     $write("%4d ", $signed(ccm_dout_act[pe_idx]));
                // end
                // $write("\n");

                f_err = 1'b0;
                dov_idx = Nh[l_idx-1] * row_idx + nzi_temp;
                // $write("DOV:"); ////
                for(pe_idx=0; pe_idx<NUM_PE; pe_idx++) begin
                    // $write("%4d ", $signed(DOV[dov_idx][DRAM_WW*(NUM_PE-1-pe_idx) +: DRAM_WW])); ////
                    if (ccm_dout_act[pe_idx] != DOV[dov_idx][DRAM_WW*(NUM_PE-1-pe_idx) +: DRAM_WW])
                        f_err = 1'b1;
                end
                // $write("\n"); ////
                if (f_err) num_err_chk += 1;

                #9;
            end
        end

        if (num_err_chk > 0)
            $display("[!!!] [VXV_SP] CCM output incorrect! (num_err_chk = %0d)", num_err_chk);
        else
            $display("[VXV_SP] CCM output correct.");
        
        // -------------------- Finish --------------------

    endtask


// -----------------------------------------------------------------------------
// Main

    initial begin: IB_main
        automatic int pe_idx = 0;
        
        $srandom(0);
        $timeformat(-9, 0, "");     // "ns"
        
        rstn        = 1'b1;

        // cfg_valid   = 1'b0;
        spm_cfg_valid  = 1'b0;
        // srg0_cfg_valid = 1'b0;
        // srg_cfg_valid  = 1'b0;
        // dmx_cfg_valid  = 1'b0;
        // ccm_cfg_valid  = 1'b0;
        cfg_data.proc  = PROC_IDLE;
        cfg_data.nt    = 0;
        cfg_data.t     = 0;
        cfg_data.func  = FUNC_NONE;
        cfg_data.cnt0  = 0;
        cfg_data.cnt1  = 0;
        cfg_data.cnt2  = 0;

        spm_addr    = '0;
        smem_addr0  = '0;
        smem_addr1  = '0;
        smem_addr2  = '0;

        wr_avalid[0] = 1'b0;
        wr_avalid[1] = 1'b0;

        dram_fifo_wen = 1'b0;
        dram_fifo_din = 'X;

        cfg_ready_all = 1'b0;

        #1;
        
        rstn        = 1'b0;
        #10;
        
        rstn        = 1'b1;
        cfg_ready_all = 1'b1;
        

        // -------------------- Train --------------------

        l_curr = 1;

        for (s_curr = 0; s_curr < Ns; s_curr++) ///DEBUG///
            fork
                train_sample(
                    .s_idx  (s_curr),
                    .l_idx  (l_curr)
                );
                
                DRAM_input_sample(
                    .s_idx  (s_curr),
                    .l_idx  (l_curr)
                );

                CCM_output_sample(
                    .s_idx  (s_curr),
                    .l_idx  (l_curr)
                );
            join
        
        // -------------------- Finish --------------------

        $display("[END] @%0t Test completed.", $stime);

        #50;
        $finish;
    end
    
    

endmodule


