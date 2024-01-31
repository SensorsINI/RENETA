
`ifndef DEF_PKG
`define DEF_PKG

package definesPkg;

    // ---------------- Overall parameters ----------------
    parameter NUM_PE        = 16;           //16
    parameter MAX_N         = 256; //8;     //1024
    parameter MAX_M         = 256; //4;     //32
    parameter MAX_NoP       = MAX_N/NUM_PE; //64

    localparam NZL_HA_BW    = $clog2(MAX_NoP*MAX_M);    // NZL head address bit-width
    localparam MAX_CNT      = (MAX_N>MAX_M)? (MAX_N):(MAX_M);
    localparam NT_BW        = $clog2(MAX_M+1);
    
    // BFP16: (7,8)
    parameter sig_width     = 7;
    parameter exp_width     = 8;
    parameter ieee_compliance = 0;

    localparam WEIGHT_BW    = 1 + exp_width + sig_width;
    localparam ACT_BW       = 1 + exp_width + sig_width;
    localparam ACC_BW       = 1 + exp_width + sig_width;
    localparam DATA_BYTE    = 2;    // $ceil(1 + exp_width + sig_width)
    
    localparam PROC_BW      = 4;
    localparam NUM_FUNC     = 4;
    
    localparam CFG_BW       = PROC_BW + NT_BW + $clog2(MAX_M) + $clog2(NUM_FUNC) + $clog2(MAX_CNT)*3 + $clog2(MAX_N); // + NZL_HA_BW + $clog2(NUM_PE);
    
    typedef enum logic [PROC_BW-1:0]  { PROC_IDLE,
                                        PROC_MxV,
                                        PROC_MTxV,
                                        PROC_VXV,
                                        PROC_MxV_SP,
                                        PROC_MTxV_SP,
                                        PROC_VXV_SP} PROC_t;
    
    typedef enum logic [$clog2(NUM_FUNC)-1:0] { FUNC_NONE,
                                                FUNC_ReLU,
                                                FUNC_sigmoid,
                                                FUNC_tanh} FUNC_t;

    typedef struct packed {
        PROC_t                              proc;
        logic [NT_BW-1:0]                   nt;
        logic [$clog2(MAX_M)-1:0]           t;
        FUNC_t                              func;
        logic [$clog2(MAX_CNT)-1:0]         cnt0;
        logic [$clog2(MAX_CNT)-1:0]         cnt1;
        logic [$clog2(MAX_CNT)-1:0]         cnt2;
        logic [$clog2(MAX_N)-1:0]           n1;
        // logic [NZL_HA_BW-1:0]               nzl_head_addr;
        // logic [$clog2(NUM_PE)-1:0]          nzl_head_peid;
    } cfg_t;

endpackage

`endif
