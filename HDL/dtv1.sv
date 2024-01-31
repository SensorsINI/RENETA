`timescale 1ns/1ps

import definesPkg::*;


// (!) NZI HIST not checked for MxV_SP MTxV_SP
// (!) VXV_SP: Force nzl_head_addr and nzl_head_peid to be 0 for IPM_SRG0 and IPM_SRG
//             Pad NZIL and NZVL for the last timestep
//             Reset LMEM_MAC


// -----------------------------------------------------------------------------

module DTV1 #(

    // ---------------- Overall parameters ----------------
    // parameter NUM_PE        = 16,           //16
    // parameter MAX_N         = 256, //8,     //1024
    // parameter MAX_M         = 256, //4,     //32
    // parameter MAX_NoP       = MAX_N/NUM_PE, //64

    // BFP16: (7,8)
    // parameter sig_width     = 7,
    // parameter exp_width     = 8,
    // parameter ieee_compliance = 1,
    
    // ---------------- DTV1_CTL ----------------
    parameter C_S_AXI_DATA_WIDTH = 32,

    // ---------------- DRAM ----------------
    parameter DRAM_WW       = 16,
    parameter DRAM_WIDTH    = DRAM_WW*NUM_PE,
    parameter DRAM_DEPTH    = MAX_N*MAX_NoP*1,

    // localparam DRAM_ADDR_BW = $clog2(DRAM_DEPTH),

    // ---------------- SPM ----------------
    parameter SPM_WW        = $clog2(MAX_NoP*MAX_M) + $clog2(NUM_PE) + $clog2(MAX_N),
    parameter SPM_DEPTH     = MAX_M * 2,

    localparam SPM_ADDR_BW  = $clog2(SPM_DEPTH),
    // localparam NZL_HA_BW    = $clog2(MAX_NoP*MAX_M),    // NZL head address bit-width
    // localparam MAX_CNT      = (MAX_N>MAX_M)? (MAX_N):(MAX_M),
    // localparam NT_BW        = $clog2(MAX_M+1),

    // Parameters of BRAM Slave Interface SPM_MEM
    parameter C_SPM_MEM_ADDR_WIDTH = 32,
    parameter C_SPM_MEM_NB_COL     = 4,         // Specify number of columns (number of bytes)
    parameter C_SPM_MEM_COL_WIDTH  = 8,         // Specify column width (byte width, typically 8 or 9)
    parameter C_SPM_MEM_DATA_WIDTH = C_SPM_MEM_NB_COL*C_SPM_MEM_COL_WIDTH,  // >= SPM_ADDR_BW

    // ---------------- IPM_DRG ----------------
    parameter AXI_DM_CMD_WIDTH  = 72,
    parameter DRAM_ADDR_BW      = 32,
    parameter BTT_BW            = 23,
    parameter AXI_DM_CMD_BASE   = 32'h4080_0000,

    // ---------------- SMEM ----------------
    parameter SMEM_WW       = 16,
    parameter SMEM_DEPTH    = MAX_M*MAX_NoP*2,
    
    parameter NUM_CH_RD     = 3,    // 3
    parameter NUM_CH_WR     = 2,    // 2

    parameter SMEM_BUF_IN_DEPTH  = 4,
    parameter SMEM_BUF_MID_DEPTH = 1,
    parameter SMEM_BUF_OUT_DEPTH = 1,

    localparam SMEM_ADDR_BW = $clog2(SMEM_DEPTH),       // MSB: bank(SRAM0/SRAM1)
    localparam WSEL_BW      = $clog2(NUM_PE) + 1,       // {WordOp, WordIdx}

    // ---------------- CCM ----------------
    // parameter NUM_FUNC      = 4,                //2
    parameter LMEM_MAC_DEPTH = (MAX_M>MAX_N)? (MAX_M):(MAX_N),
    parameter LMEM_ACC_DEPTH = MAX_M,           //32
    
    // localparam WEIGHT_BW    = 1 + exp_width + sig_width,
    // localparam ACT_BW       = 1 + exp_width + sig_width,
    // localparam ACC_BW       = 1 + exp_width + sig_width,
    // localparam MAX_CNT      = (MAX_N>MAX_M)? (MAX_N):(MAX_M),
    
    // ---------------- IPM_SRG0 CFG FIFO parameters ----------------
    localparam SRG0_CFG_FIFO_WIDTH  = CFG_BW + NZL_HA_BW + $clog2(NUM_PE),
    localparam SRG0_CFG_FIFO_DEPTH  = 4,                // 2^int

    // ---------------- IPM_SRG CFG FIFO parameters ----------------
    localparam SRG_CFG_FIFO_WIDTH  = CFG_BW + NZL_HA_BW + $clog2(NUM_PE),
    localparam SRG_CFG_FIFO_DEPTH  = 4,                 // 2^int

    // ---------------- IPM_DRG CFG FIFO parameters ----------------
    localparam DRG_CFG_FIFO_WIDTH  = CFG_BW + $clog2(MAX_N),
    localparam DRG_CFG_FIFO_DEPTH  = 4,                 // 2^int

    // ---------------- IPM_DMX CFG FIFO parameters ----------------
    localparam DMX_CFG_FIFO_WIDTH  = CFG_BW,
    localparam DMX_CFG_FIFO_DEPTH  = 4,                 // 2^int

    // ---------------- IPM_CCM CFG FIFO parameters ----------------
    localparam CCM_CFG_FIFO_WIDTH  = CFG_BW,
    localparam CCM_CFG_FIFO_DEPTH  = 4,                 // 2^int

    // ---------------- IPM_SRG0 NZN FIFO parameters ----------------
    localparam SRG0_NZN_FIFO_WIDTH  = $clog2(MAX_N),
    localparam SRG0_NZN_FIFO_DEPTH  = 16,               // 2^int

    // ---------------- IPM_SRG NZN FIFO parameters ----------------
    localparam SRG_NZN_FIFO_WIDTH   = $clog2(MAX_N),
    localparam SRG_NZN_FIFO_DEPTH   = 16,               // 2^int

    // ---------------- IPM_DMX NZN FIFO parameters ----------------
    localparam DMX_NZN_FIFO_WIDTH   = $clog2(MAX_N),
    localparam DMX_NZN_FIFO_DEPTH   = 16,               // 2^int

    // ---------------- IPM_DRG NZI FIFO parameters ----------------
    localparam DRG_NZI_FIFO_WIDTH   = $clog2(MAX_N),
    localparam DRG_NZI_FIFO_DEPTH   = MAX_N,

    // ---------------- IPM_DMX NZI FIFO parameters ----------------
    localparam DMX_NZI_FIFO_WIDTH   = $clog2(MAX_N),
    localparam DMX_NZI_FIFO_DEPTH   = MAX_N,

    // ---------------- IPM_DMX Data FIFO parameters ----------------
    localparam FIFO_DRAM_WIDTH      = DRAM_WIDTH,
    localparam FIFO_DRAM_DEPTH      = 16,
    localparam FIFO_SMEM1_WIDTH     = WSEL_BW + SMEM_WW*NUM_PE,
    localparam FIFO_SMEM1_DEPTH     = 16,
    localparam FIFO_SMEM2_WIDTH     = WSEL_BW + SMEM_WW*NUM_PE,
    localparam FIFO_SMEM2_DEPTH     = 16,

    // ---------------- CCM NZN FIFO parameters ----------------
    localparam CCM_NZN_FIFO_WIDTH   = $clog2(MAX_N),
    localparam CCM_NZN_FIFO_DEPTH   = 16                // 2^int

)(

// -----------------------------------------------------------------------------

    // ---------------- Clock and Reset ----------------
    input  logic                        clk,
    input  logic                        rstn,
    
    // ---------------- CONFIG signals ----------------
    input  logic                        spm_cfg_valid,
    input  cfg_t                        spm_cfg_data,
    output logic                        spm_cfg_ready,

    input  logic [C_S_AXI_DATA_WIDTH-1:0]           spm_addr_i,
    input  logic [C_S_AXI_DATA_WIDTH-1:0]           smem_addr0_i,
    input  logic [C_S_AXI_DATA_WIDTH-1:0]           smem_addr1_i,
    input  logic [C_S_AXI_DATA_WIDTH-1:0]           smem_addr2_i,
    input  logic [C_S_AXI_DATA_WIDTH-1:0]           dram_addr0_i,

    // Ports of BRAM Slave Interface SPM_MEM
    input  logic                                    spm_mem_clkb,
    input  logic                                    spm_mem_rstb,
    input  logic [C_SPM_MEM_ADDR_WIDTH-1 : 0]       spm_mem_addrb,
    input  logic [C_SPM_MEM_DATA_WIDTH-1 : 0]       spm_mem_dinb,
    output logic [C_SPM_MEM_DATA_WIDTH-1 : 0]       spm_mem_doutb,
    input  logic                                    spm_mem_enb,
    input  logic [C_SPM_MEM_NB_COL-1 : 0]           spm_mem_web,

    // ---------------- DRAM request signals ----------------
    // Ports of AXIS Master Bus Interface M_AXIS_MM2S_CMD
    output logic                        m_axis_mm2s_cmd_tvalid,
    output logic [AXI_DM_CMD_WIDTH-1:0] m_axis_mm2s_cmd_tdata,
    input  logic                        m_axis_mm2s_cmd_tready,

    // ---------------- DRAM FIFO input signals ----------------
    // output logic                        dram_full,
    // input  logic [FIFO_DRAM_WIDTH-1:0]  dram_fifo_din,
    // input  logic                        dram_fifo_wen,

    // Ports of AXIS Slave Bus Interface S_AXIS_MM2S
    input  logic                        s_axis_mm2s_tvalid,
    input  logic [DRAM_WIDTH-1:0]       s_axis_mm2s_tdata,
    output logic                        s_axis_mm2s_tready,
    
    // ---------------- CCM output signals ----------------
    output logic                        ccm_valid_o,
    input  logic                        ccm_ready_i,
    // output logic [ACT_BW-1:0]           ccm_dout_act[0:NUM_PE]      // acc
    output logic [ACT_BW*(NUM_PE+1)-1:0] ccm_dout_act               // acc
    
);

// -----------------------------------------------------------------------------

    // ---------------- IPM_SPM Config ----------------
    // logic                               spm_cfg_valid;
    // cfg_t                               spm_cfg_data;
    // logic                               spm_cfg_ready;
    logic [SPM_ADDR_BW-1:0]             spm_addr;

    // ---------------- IPM_SPM Read Port ----------------
    logic                               spm_rd_en;
    logic [SPM_ADDR_BW-1:0]             spm_rd_addr;
    logic [SPM_WW-1:0]                  spm_rd_data;
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
    // logic                               ccm_ready_i;

    logic [$clog2(MAX_N)-1:0]           ccm_din_nzn;
    logic                               ccm_pop_nzn;

    logic [ACT_BW-1:0]                  ccm_din_act[0:NUM_PE-1];
    logic [WEIGHT_BW-1:0]               ccm_din_weight[0:NUM_PE-1];
    logic [$clog2(MAX_N)-1:0]           ccm_din_nzi;
    
    // logic                               ccm_valid_o;
    logic                               ccm_ready_o;
    logic [ACT_BW-1:0]                  ccm_dout_act_arr[0:NUM_PE]; // acc
    
    // ---------------- HIST signals ----------------
    logic                               hist_ready_o;
    logic [$clog2(MAX_N)-1:0]           hist_nzi[0:3];
    logic                               hist_nzi_v[0:3];

    // ---------------- CCM NZN FIFO signals ----------------
    logic                               ccm_nzn_fifo_push;
    logic                               ccm_nzn_fifo_empty;
    logic                               ccm_nzn_fifo_full;
    logic [CCM_NZN_FIFO_WIDTH-1:0]      ccm_nzn_fifo_din;



// -----------------------------------------------------------------------------
// Address from CTL_REG
    assign spm_addr   = spm_addr_i  [SPM_ADDR_BW -1:0];
    assign smem_addr0 = smem_addr0_i[SMEM_ADDR_BW-1:0];
    assign smem_addr1 = smem_addr1_i[SMEM_ADDR_BW-1:0];
    assign smem_addr2 = smem_addr2_i[SMEM_ADDR_BW-1:0];
    assign dram_addr0 = dram_addr0_i[DRAM_ADDR_BW-1:0];


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
    
    
    // // (* ram_style = "block" *)
    // BRAM_SDP_1C #(
    //     .RAM_WIDTH      (SPM_WW             ),
    //     .RAM_DEPTH      (SPM_DEPTH          ),
    //     .RAM_PERFORMANCE("LOW_LATENCY"      ),
    //     .INIT_FILE      (""                 )
    // ) SPM_MEM (
    //     .addra          (                   ),
    //     .addrb          (spm_rd_addr        ),
    //     .dina           (                   ),
    //     .clka           (clk                ),
    //     .wea            (                   ),
    //     .enb            (spm_rd_en          ),
    //     .rstb           (!spm_rd_rstn       ),
    //     .doutb          (spm_rd_data        )
    // );
    
    // (* ram_style = "block" *)
    BRAM_TDP_WF_BW_2C #(
        .RAM_WIDTH      (C_SPM_MEM_DATA_WIDTH),
        .RAM_DEPTH      (SPM_DEPTH          ),
        .RAM_PERFORMANCE("LOW_LATENCY"      ),
        .INIT_FILE      (""                 )
    ) SPM_MEM (
        .addra          (spm_rd_addr        ),
        .dina           ('0                 ),
        .clka           (clk                ),
        .wea            ('0                 ),
        .ena            (spm_rd_en          ),
        .rsta           (!spm_rd_rstn       ),
        .douta          (spm_rd_data        ),

        .addrb          (spm_mem_addrb >> $clog2(C_SPM_MEM_NB_COL)),  // axi_bram_ctrl address is byte address
        .dinb           (spm_mem_dinb       ),
        .clkb           (spm_mem_clkb       ),
        .web            (spm_mem_web        ),  // axi_bram_ctrl we is byte write enable
        .enb            (spm_mem_enb        ),
        .rstb           (spm_mem_rstb       ),
        .doutb          (spm_mem_doutb      )
    );
    

    // assign spm_cfg_data = cfg_data;
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

    assign m_axis_mm2s_cmd_tvalid = drg_cmd_tvalid;
    assign m_axis_mm2s_cmd_tdata = drg_cmd_tdata;
    assign drg_cmd_tready = m_axis_mm2s_cmd_tready;
    // assign drg_cmd_tready = 1'b1;
    

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
    

    assign dram_fifo_wen = s_axis_mm2s_tvalid;
    assign dram_fifo_din = s_axis_mm2s_tdata;
    assign s_axis_mm2s_tready = !dram_full;


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
        .dout_act           (ccm_dout_act_arr)
    );
    
    
    generate
        for (genvar pe_idx = 0; pe_idx < NUM_PE+1; pe_idx++) begin
            assign ccm_dout_act_arr[pe_idx] = ccm_dout_act[ACT_BW*(NUM_PE-pe_idx) +: ACT_BW];
        end
    endgenerate

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
    


endmodule


