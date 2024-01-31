
import definesPkg::*;

`define ROUND_FLOOR

// Compute Core Module

// Stage    Components
//   (0)    INPUTS, LMEM_rd_MUL
//     1    DIN_R1, LMEM_rd_ADD
//     2    DIN_R2,
//     3    MUL,
//     4    ADD,    LMEM_wr_MUL
//     5    FUNC,   LMEM_wr_ADD
//     6    MUX_DOUT

// cfg_ready initialized to 1?
//           set to 1 only when cfg_valid==1?

// (!) Bit-width matching: LMEM_MAC_DEPTH, MAX_N, MAX_M

// (!) LMEM signals not registered

// (!) [MxV, MTxV, VXV, VXV_SP] need to delay CCM input to prevent RAW hazard



module CCM #(
    // parameter NUM_PE        = 16,           //16
    // parameter MAX_N         = 256,          //1024
    // parameter MAX_M         = 256,          //32
    // parameter MAX_NoP       = MAX_N/NUM_PE, //64
    
    // parameter sig_width     = 7,
    // parameter exp_width     = 8,
    // parameter ieee_compliance = 1,

    // parameter NUM_FUNC      = 4,            //2
    parameter LMEM_MAC_DEPTH = (MAX_M>MAX_N)? (MAX_M):(MAX_N),
    parameter LMEM_ACC_DEPTH = MAX_M        //32

    // localparam WEIGHT_BW    = 1 + exp_width + sig_width,
    // localparam ACT_BW       = 1 + exp_width + sig_width,
    // localparam ACC_BW       = 1 + exp_width + sig_width,
    // localparam MAX_CNT      = (MAX_N>MAX_M)? (MAX_N):(MAX_M)
) (
    input  logic                        clk,
    input  logic                        rstn,
    
    // Config signals
    input  logic                        cfg_valid,
    // input  PROC_t                       cfg_proc,
    // input  FUNC_t                       cfg_func,
    // input  logic [$clog2(MAX_CNT)-1:0]  cfg_cnt0,
    // input  logic [$clog2(MAX_CNT)-1:0]  cfg_cnt1,
    // input  logic [$clog2(MAX_CNT)-1:0]  cfg_cnt2,
    input  cfg_t                        cfg_data,
    output logic                        cfg_ready,
    
    input  logic [$clog2(MAX_N)-1:0]    din_nzn,
    output logic                        pop_nzn,

    input  logic [ACT_BW-1:0]           din_act[0:NUM_PE-1],
    input  logic [WEIGHT_BW-1:0]        din_weight[0:NUM_PE-1],
    input  logic [$clog2(MAX_N)-1:0]    din_nzi,
    input  logic                        valid_i,
    output logic                        ready_o,
    
    output logic                        valid_o,
    input  logic                        ready_i,
    output logic [ACT_BW-1:0]           dout_act[0:NUM_PE]      // acc
);


// -----------------------------------------------------------------------------
// Global variables

    // Overall - control signals
    logic                               rstn_init;
    
    // Overall - flags
    logic [0:6]                         f_I;
    logic [0:6]                         f_O;
    logic [0:6]                         f_O_ACC;
    
    // Config Signal
    PROC_t                              cfg_proc_r;
    FUNC_t                              cfg_func_r;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt0_r;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt1_r;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt2_r;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt0_r1;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt1_r1;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt2_r1;

    // Input Signal
    logic                               ready_i_eff;
    logic [0:6]                         valid_i_r;
    logic [0:NUM_PE+2]                  valid_i_chain;
    logic [0:6]                         valid_i_acc_r;

    // Output Signal
    logic [0:6]                         valid_o_r;
    logic [0:6]                         valid_o_acc_r;
    
    // FSM - states
    // (* mark_debug = "true" *)
    enum logic [1:0] {S_IDLE, S_INIT, S_COMPUTE} state;
    logic                               f_proc_end;
    
    // PE - control signal
    logic                               rstn_PE;
    logic [0:5]                         en_mac_i0;
    logic [0:5]                         en_mac_i1;
    logic [0:5]                         en_mac_o0;
    logic [0:5]                         en_mac_o1;
    logic [0:5]                         en_acc_i0;
    logic [0:5]                         en_acc_i1;
    logic [0:5]                         en_acc_o0;
    logic [0:5]                         en_acc_o1;
    logic [0:NUM_PE+1]                  en_chain_i0;

    logic [0:NUM_PE-1]                  en_mul;
    logic [0:NUM_PE-1]                  en_add;
    logic                               en_acc;
    
    // PE - input data registers
    logic [ACT_BW-1:0]                  din_act_r1[0:NUM_PE-1];
    logic [ACT_BW-1:0]                  din_act_r2[0:NUM_PE-1];
    logic [WEIGHT_BW-1:0]               din_weight_r1[0:NUM_PE-1];
    logic [WEIGHT_BW-1:0]               din_weight_r2[0:NUM_PE-1];
    logic [$clog2(MAX_N)-1:0]           din_nzi_r[0:4];

    // PE - accumulating results
    logic [ACC_BW-1:0]                  pe_din_buf[0:NUM_PE];   // acc
    logic [ACC_BW-1:0]                  pe_dout_acc[0:NUM_PE];  // acc
    logic [ACC_BW-1:0]                  pe_dout_mul[0:NUM_PE-1];
    
    // PE - mux selections
    logic                               mul_mux_sel;
    logic                               mul_mux_sel_r[0:2];
    logic                               add_mux0_sel;
    logic                               add_mux0_sel_r[0:3];
    logic [1:0]                         add_mux1_sel;
    logic [1:0]                         add_mux1_sel_r[0:3];
    logic [1:0]                         acc_mux_sel;
    logic [1:0]                         acc_mux_sel_r[0:3];
    
    // LMEM_MAC - data
    logic [ACC_BW-1:0]                  lmem_mac_din[0:NUM_PE-1];
    // logic [ACC_BW-1:0]                  lmem_mac_dout[0:NUM_PE-1];
    logic [ACC_BW-1:0]                  lmem_mac_dout_reg[0:NUM_PE-1];

    // LMEM_MAC - data/address counters
    logic [$clog2(MAX_CNT)-1:0]         cnt0_mac;
    logic [$clog2(MAX_CNT)-1:0]         cnt1_mac;
    logic [$clog2(MAX_CNT)-1:0]         cnt2_mac;
    logic [$clog2(LMEM_MAC_DEPTH)-1:0]  cnt_mac_mr[0:NUM_PE-1];
    logic [$clog2(LMEM_MAC_DEPTH)-1:0]  cnt_mac_mw;
    logic [$clog2(LMEM_MAC_DEPTH)-1:0]  cnt_mac_mrw_ub;
    logic [$clog2(LMEM_MAC_DEPTH)-1:0]  addr_mac_rd[0:NUM_PE-1];
    logic [$clog2(LMEM_MAC_DEPTH)-1:0]  addr_mac_wr;
    logic                               f_cnt_mac;
    logic [0:6]                         f_cnt_mac_r;
    
    // LMEM_MAC - control signals
    logic                               en_cnt_mac_mr[0:NUM_PE-1];
    logic                               en_cnt_mac_mw;
    logic                               en_mac_rd[0:NUM_PE-1];
    logic [0:4]                         en_mac_rd_r;
    logic                               en_mac_wr;
    logic [0:4]                         en_mac_wr_r;
    logic                               rstn_mac;
    logic                               regce_mac[0:NUM_PE-1];
    logic [0:NUM_PE]                    en_chain_rd_r;
    
    // DEBUG: Reset LMEM_MAC for PROC_VXV_SP
    //          when (cnt2_mac < cfg_cnt2_r) && (cnt1_mac == cfg_cnt1_r) && (cnt0_mac == cfg_cnt0_r)
    logic [0:2]                         rst_lmem_mac_r;
    logic                               rst_lmem_mac;
    
    // LMEM_ACC - data/address counters
    logic [$clog2(MAX_CNT)-1:0]         cnt0_acc;
    logic [$clog2(MAX_CNT)-1:0]         cnt1_acc;
    logic [$clog2(MAX_CNT)-1:0]         cnt2_acc;
    logic [$clog2(LMEM_ACC_DEPTH)-1:0]  cnt_acc_mr;
    logic [$clog2(LMEM_ACC_DEPTH)-1:0]  cnt_acc_mw;
    logic                               f_cnt_acc;
    logic [0:6]                         f_cnt_acc_r;
    
    // LMEM_ACC - control signals
    logic                               en_acc_rd;
    logic [0:2]                         en_acc_rd_r;
    logic                               en_acc_wr;
    logic [0:4]                         en_acc_wr_r;
    logic                               rstn_acc;
    logic                               regce_acc;
    
    // Activation Function Output, Mux
    logic [ACT_BW-1:0]                  mac_func_out[0:NUM_PE-1];
    logic [ACT_BW-1:0]                  mac_func_out_r[0:NUM_PE-1];
    FUNC_t                              mac_func_sel;               // ? entries
    FUNC_t                              mac_func_sel_r[0:4];
    logic [ACT_BW-1:0]                  acc_func_out;
    logic [ACT_BW-1:0]                  acc_func_out_r;
    FUNC_t                              acc_func_sel;               // 2 entries
    FUNC_t                              acc_func_sel_r[0:4];

    // Output Register, Mux
    logic [ACT_BW-1:0]                  dout_act_r[0:NUM_PE];

    
// -----------------------------------------------------------------------------
// Module body

    
    // FSM
    always_ff @(posedge clk) begin
        if (!rstn) begin
            state <= S_IDLE;
            cfg_ready <= 1'b1;
            cfg_proc_r <= PROC_IDLE;
        end else begin
            case (state)
    
                S_IDLE : begin              // Idle
                    if (cfg_valid) begin
                        state <= S_INIT;
                        cfg_ready <= 1'b0;  // Deassert when a procedure is started
                        cfg_proc_r <= cfg_data.proc;
                    end
                end
                
                S_INIT : begin              // Initialize
                    state <= S_COMPUTE;
                    cfg_ready <= cfg_ready;
                    cfg_proc_r <= cfg_proc_r;
                end
                
                S_COMPUTE : begin           // Compute
                    if (f_proc_end) begin
                        state <= S_IDLE;
                        cfg_ready <= 1'b1;  // Assert when a procedure is finished
                        cfg_proc_r <= PROC_IDLE;
                    end
                end

                default : begin
                    state <= S_IDLE;
                    cfg_ready <= 1'b0;
                    cfg_proc_r <= PROC_IDLE;
                end

            endcase
        end
    end

    always_comb begin
        f_proc_end = 1'b0;
        case (cfg_proc_r) inside
            PROC_MxV, PROC_VXV, PROC_MxV_SP, PROC_VXV_SP :
                if (f_cnt_mac_r[6] && valid_i_r[6] && ready_i_eff)
                    f_proc_end = 1'b1;
            PROC_MTxV, PROC_MTxV_SP :
                if (f_cnt_acc_r[6] && valid_i_acc_r[6] && ready_i_eff)
                    f_proc_end = 1'b1;
            default :
                f_proc_end = 1'b0;
        endcase
    end
    
    

    // Config Signals
    always_ff @(posedge clk) begin
        if (!rstn) begin
            cfg_func_r <= FUNC_NONE;
            cfg_cnt0_r1 <= '0;
            cfg_cnt1_r1 <= '0;
            cfg_cnt2_r1 <= '0;
        end else if ((state == S_IDLE) && cfg_valid) begin
            cfg_func_r <= cfg_data.func;
            cfg_cnt0_r1 <= cfg_data.cnt0;
            cfg_cnt1_r1 <= cfg_data.cnt1;
            cfg_cnt2_r1 <= cfg_data.cnt2;
        end
    end

    // Counter - Upper bounds
    always_ff @(posedge clk) begin
        if (!rstn) begin
            cfg_cnt0_r <= '0;
        end else begin
            case (cfg_proc_r)
                PROC_MxV, PROC_MTxV, PROC_VXV, PROC_MxV_SP, PROC_MTxV_SP : begin
                    if (state == S_INIT) begin
                        cfg_cnt0_r <= cfg_cnt0_r1;
                    end
                end
                PROC_VXV_SP : begin
                    // cnt1 == 0         : N(l-1)   (All PEs accumulate from 0)
                    // cnt1 == 1..(Nt-2) : din_nzn  (NZI PEs only)
                    // cnt1 == (Nt-1)    : N(l-1)   (All PEs output results)
                    // cfg_cnt0_r <= cfg_cnt0_r1;  // din_nzn;
                    if (state == S_INIT) begin
                        cfg_cnt0_r <= din_nzn;
                    end else if (en_mac_i0[0] && (cnt0_mac == cfg_cnt0_r) && !f_cnt_mac) begin
                        cfg_cnt0_r <= din_nzn;
                    end
                end
                default : begin
                    cfg_cnt0_r <= '0;
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (!rstn) begin
            cfg_cnt1_r <= '0;
            cfg_cnt2_r <= '0;
        end else if (state == S_INIT) begin
            case (cfg_proc_r) inside
                PROC_MxV, PROC_MTxV, PROC_VXV, PROC_VXV_SP : begin
                    cfg_cnt1_r <= cfg_cnt1_r1;
                    cfg_cnt2_r <= cfg_cnt2_r1;
                end
                PROC_MxV_SP : begin
                    cfg_cnt1_r <= din_nzn;
                    cfg_cnt2_r <= cfg_cnt2_r1;
                end
                PROC_MTxV_SP : begin
                    cfg_cnt1_r <= cfg_cnt1_r1;
                    cfg_cnt2_r <= din_nzn;
                end
                default : begin
                    cfg_cnt1_r <= '0;
                    cfg_cnt2_r <= '0;
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
                end else if (en_mac_i0[0] && (cnt0_mac == cfg_cnt0_r) && !f_cnt_mac) begin   // S_GEN
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
    
    // TODO
    // always_comb begin
    //     case (state) inside
    //         S_FP, S_BPdZ, S_BPdW, S_PU : begin
    //             ready_i_eff = ready_i || !f_O[5];
    //         end
    //         S_BPdA : begin
    //             ready_i_eff = ready_i || !f_O_ACC[5];
    //         end
    //         default : begin
    //             ready_i_eff = ready_i || !f_O[5];
    //             // ready_i_eff = 1'b0;
    //         end
    //     endcase
    // end
    assign ready_i_eff = ready_i;
    
    assign valid_i_r[0] = valid_i;
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 6; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                valid_i_r[ps_idx] <= 1'b0;
            end else if (ready_i_eff) begin
                valid_i_r[ps_idx] <= valid_i_r[ps_idx-1];
            end
        end
    end

    // assign valid_i_chain[0] = valid_i_r[4];
    assign valid_i_chain[0] = valid_i_r[4] && (cfg_proc_r inside {PROC_MTxV, PROC_MTxV_SP});
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= NUM_PE+2; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                valid_i_chain[ps_idx] <= 1'b0;
            end else if (ready_i_eff) begin
                valid_i_chain[ps_idx] <= valid_i_chain[ps_idx-1];
            end
        end
    end

    assign valid_i_acc_r[0] = valid_i_chain[NUM_PE-1];
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 6; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                valid_i_acc_r[ps_idx] <= 1'b0;
            end else if (ready_i_eff) begin
                valid_i_acc_r[ps_idx] <= valid_i_acc_r[ps_idx-1];
            end
        end
    end
    
    always_comb begin
        case (cfg_proc_r) inside
            PROC_MxV, PROC_MTxV, PROC_VXV, PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP : begin
                ready_o = f_I[0] && ready_i_eff;
                // if (state == S_COMPUTE) ready_o = ready_i_eff;
            end
            default : begin
                ready_o = 1'b0;
            end
        endcase
    end
    
    assign valid_o_r[0] = f_O[0] & valid_i_r[0];
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 6; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                valid_o_r[ps_idx] <= 1'b0;
            end else if (ready_i_eff) begin
                valid_o_r[ps_idx] <= valid_o_r[ps_idx-1];
            end
        end
    end

    assign valid_o_acc_r[0] = f_O_ACC[0] & valid_i_acc_r[0];
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 6; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                valid_o_acc_r[ps_idx] <= 1'b0;
            end else if (ready_i_eff) begin
                valid_o_acc_r[ps_idx] <= valid_o_acc_r[ps_idx-1];
            end
        end
    end

    always_comb begin  // TODO
        case (cfg_proc_r) inside
            PROC_MxV, PROC_VXV, PROC_MxV_SP, PROC_VXV_SP : begin
                valid_o = valid_o_r[6];
            end
            PROC_MTxV, PROC_MTxV_SP : begin
                valid_o = valid_o_acc_r[6];
            end
            default : begin
                valid_o = 1'b0;
            end
        endcase
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
    
    always_ff @(posedge clk) begin
        if (!rstn) begin    // No || !rstn_init
            f_I[0] <= 1'b0;
        end else begin
            case (state) inside
                S_INIT : begin
                    if (cfg_proc_r inside {PROC_MxV, PROC_MTxV, PROC_VXV, PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP}) begin
                        f_I[0] <= 1'b1;
                    end else begin
                        f_I[0] <= 1'b0;
                    end
                end
                S_COMPUTE : begin
                    if (cfg_proc_r inside {PROC_MxV, PROC_MTxV, PROC_VXV, PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP}) begin
                        // Deassert when last input data accepted
                        if (en_mac_i0[0] && f_cnt_mac) begin
                            f_I[0] <= 1'b0;
                        end
                    end
                end
                default : begin
                    f_I[0] <= 1'b0;
                end
            endcase
        end
    end
    
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 6; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                f_I[ps_idx] <= 1'b0;
            end else if (en_mac_i1[ps_idx-1]) begin
                f_I[ps_idx] <= f_I[ps_idx-1];
            end
        end
    end
    
    always_comb begin
        case (cfg_proc_r) inside
            PROC_MxV, PROC_VXV, PROC_MxV_SP, PROC_VXV_SP : begin
                f_O[0] = (cnt1_mac == cfg_cnt1_r); // && f_I[0];
            end
            // PROC_MTxV, PROC_MTxV_SP : begin                              // For ready_i_eff?
            //     f_O[0] = (cnt1_acc == cfg_cnt1_r); // && f_I_ACC[0];
            // end
            default : begin
                f_O[0] = 1'b0;
            end
        endcase
    end
    
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 6; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                f_O[ps_idx] <= 1'b0;
            end else if (en_mac_o1[ps_idx-1]) begin
                f_O[ps_idx] <= f_O[ps_idx-1];
            end
        end
    end
    
    always_comb begin
        case (cfg_proc_r) inside
            PROC_MTxV, PROC_MTxV_SP : begin
                f_O_ACC[0] = (cnt1_acc == cfg_cnt1_r); // && f_I_ACC[0];
            end
            default : begin
                f_O_ACC[0] = 1'b0;
            end
        endcase
    end
    
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 6; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                f_O_ACC[ps_idx] <= 1'b0;
            end else if (en_acc_o1[ps_idx-1]) begin
                f_O_ACC[ps_idx] <= f_O_ACC[ps_idx-1];
            end
        end
    end

    
    
    // PE Control Signals
    assign rstn_PE = rstn_init;
    
    always_comb begin
        for (int ps_idx = 0; ps_idx <= 5; ps_idx++) begin
            // MAC Enables
            en_mac_i0[ps_idx] = valid_i_r[ps_idx] && ready_i_eff;
            en_mac_i1[ps_idx] = (valid_i_r[ps_idx] || valid_i_r[ps_idx+1]) && ready_i_eff;
            en_mac_o0[ps_idx] = valid_o_r[ps_idx] && ready_i_eff;
            en_mac_o1[ps_idx] = (valid_o_r[ps_idx] || valid_o_r[ps_idx+1]) && ready_i_eff;

            // // ACC Enables
            en_acc_i0[ps_idx] = valid_i_acc_r[ps_idx] && ready_i_eff;
            en_acc_i1[ps_idx] = (valid_i_acc_r[ps_idx] || valid_i_acc_r[ps_idx+1]) && ready_i_eff;
            en_acc_o0[ps_idx] = valid_o_acc_r[ps_idx] && ready_i_eff;
            en_acc_o1[ps_idx] = (valid_o_acc_r[ps_idx] || valid_o_acc_r[ps_idx+1]) && ready_i_eff;
        end
    end

    always_comb begin
        for (int ps_idx = 0; ps_idx <= NUM_PE+1; ps_idx++) begin
            en_chain_i0[ps_idx] = valid_i_chain[ps_idx] && ready_i_eff;
        end
    end



    // LMEM_MAC Counters - LMEM Address, Accumulation Round, Repetition Round
    always_ff @(posedge clk) begin
        if ((!rstn) || (!rstn_init)) begin
            cnt0_mac <= 0;
            cnt1_mac <= 0;
            cnt2_mac <= 0;
        end else if (en_mac_i0[0]) begin
            if (cnt0_mac == cfg_cnt0_r) begin
                cnt0_mac <= 0;
                if (cnt1_mac == cfg_cnt1_r) begin
                    cnt1_mac <= 0;
                    if (cnt2_mac == cfg_cnt2_r) begin
                        cnt2_mac <= 0;
                    end else begin
                        cnt2_mac <= cnt2_mac + 1;
                    end
                end else begin
                    cnt1_mac <= cnt1_mac + 1;
                end
            end else begin
                cnt0_mac <= cnt0_mac + 1;
            end
        end
    end
    
    assign f_cnt_mac = (cnt2_mac == cfg_cnt2_r) && (cnt1_mac == cfg_cnt1_r) && (cnt0_mac == cfg_cnt0_r);
    
    assign f_cnt_mac_r[0] = f_cnt_mac & valid_i_r[0];
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 6; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                f_cnt_mac_r[ps_idx] <= 1'b0;
            end else if (en_mac_i1[ps_idx-1]) begin
                f_cnt_mac_r[ps_idx] <= f_cnt_mac_r[ps_idx-1];
            end
        end
    end
    
    always_ff @(posedge clk) begin
        if (!rstn) begin
            cnt_mac_mrw_ub <= '0;
        end else if (state == S_INIT) begin
            case (cfg_proc_r)
                PROC_MxV, PROC_VXV, PROC_MxV_SP, PROC_VXV_SP : begin
                    cnt_mac_mrw_ub <= cfg_cnt0_r1;
                end
                PROC_MTxV, PROC_MTxV_SP : begin
                    cnt_mac_mrw_ub <= NUM_PE-1;
                end
                // PROC_VXV_SP : Use din_nzi instead of cnt_mac_mr/w as LMEM address
                default : begin
                    cnt_mac_mrw_ub <= '0;
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        for (int pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
            if ((!rstn) || (!rstn_init)) begin
                cnt_mac_mr[pe_idx] <= 0;
            end else if (en_cnt_mac_mr[pe_idx]) begin
                if (cnt_mac_mr[pe_idx] == cnt_mac_mrw_ub) begin
                    cnt_mac_mr[pe_idx] <= 0;
                end else begin
                    cnt_mac_mr[pe_idx] <= cnt_mac_mr[pe_idx] + 1;
                end
            end
        end
    end

    always_ff @(posedge clk) begin
        if ((!rstn) || (!rstn_init)) begin
            cnt_mac_mw <= 0;
        end else if (en_cnt_mac_mw) begin
            if (cnt_mac_mw == cnt_mac_mrw_ub) begin
                cnt_mac_mw <= 0;
            end else begin
                cnt_mac_mw <= cnt_mac_mw + 1;
            end
        end
    end
    
    always_comb begin
        for (int pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
            case (cfg_proc_r) inside
                PROC_MxV, PROC_VXV : begin
                    en_cnt_mac_mr[pe_idx] = en_mac_i0[1];
                end
                PROC_MTxV, PROC_MTxV_SP : begin
                    en_cnt_mac_mr[pe_idx] = en_chain_i0[0 + pe_idx];
                end
                // PROC_MxV_SP : Successive add in MAC ADD_REG
                // PROC_VXV_SP : Use din_nzi instead of cnt_mac_mr as LMEM address
                default : begin
                    en_cnt_mac_mr[pe_idx] = 1'b0;
                end
            endcase
        end
    end
    
    always_comb begin
        case (cfg_proc_r) inside
            PROC_MxV, PROC_VXV : begin
                en_cnt_mac_mw = en_mac_i0[4];
            end
            PROC_MTxV, PROC_MTxV_SP : begin
                en_cnt_mac_mw = en_mac_i0[3];
            end
            // PROC_MxV_SP : Successive add in MAC ADD_REG
            // PROC_VXV_SP : Use din_nzi instead of cnt_mac_mw as LMEM address
            default : begin
                en_cnt_mac_mw = 1'b0;
            end
        endcase
    end



    // LMEM_MAC - address
    always_comb begin
        for (int pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
            case (cfg_proc_r) inside
                PROC_MxV, PROC_MTxV, PROC_VXV, PROC_MTxV_SP : begin
                    addr_mac_rd[pe_idx] = cnt_mac_mr[pe_idx];
                end
                PROC_VXV_SP : begin
                    addr_mac_rd[pe_idx] = din_nzi_r[1];     // Bit-width match when LMEM_MAC_DEPTH==MAX_N
                end
                // PROC_MxV_SP : Successive add in MAC ADD_REG
                default : begin
                    addr_mac_rd[pe_idx] = cnt_mac_mr[pe_idx];
                end
            endcase
        end
    end
    
    always_comb begin
        case (cfg_proc_r) inside
            PROC_MxV, PROC_MTxV, PROC_VXV, PROC_MTxV_SP : begin
                addr_mac_wr = cnt_mac_mw;
            end
            PROC_VXV_SP : begin
                addr_mac_wr = din_nzi_r[4];                 // Bit-width match when LMEM_MAC_DEPTH==MAX_N
            end
            // PROC_MxV_SP : Successive add in MAC ADD_REG
            default : begin
                addr_mac_wr = cnt_mac_mw;
            end
        endcase
    end
    
    

    // LMEM_MAC - control signals
    assign rstn_mac = rstn_init;
    
    always_comb begin
        case (cfg_proc_r) inside
            PROC_MxV, PROC_VXV, PROC_VXV_SP : begin
                en_mac_rd_r[0] = (cnt1_mac > 0);
                en_mac_wr_r[0] = (cnt1_mac < cfg_cnt1_r);
                en_mac_wr = en_mac_wr_r[4] && en_mac_i0[4];
                rst_lmem_mac_r[0] = (cnt2_mac < cfg_cnt2_r) && (cnt1_mac == cfg_cnt1_r) && (cnt0_mac == cfg_cnt0_r) && (cfg_proc_r == PROC_VXV_SP);
            end
            PROC_MTxV, PROC_MTxV_SP : begin
                en_mac_rd_r[0] = 1'b1;
                en_mac_wr_r[0] = 1'b1;
                en_mac_wr = en_mac_wr_r[3] && en_mac_i0[3];
                rst_lmem_mac_r[0] = 1'b0;
            end
            // PROC_MxV_SP : Successive add in MAC ADD_REG
            default : begin
                en_mac_rd_r[0] = 1'b0;
                en_mac_wr_r[0] = 1'b0;
                en_mac_wr = en_mac_wr_r[4] && en_mac_i0[4];
                rst_lmem_mac_r[0] = 1'b0;
            end
        endcase
    end
    always_comb begin
        for (int pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
            case (cfg_proc_r) inside
                PROC_MxV, PROC_VXV, PROC_VXV_SP : begin
                    en_mac_rd[pe_idx] = en_mac_rd_r[1] && en_mac_i0[1];
                    regce_mac[pe_idx] = en_mac_rd_r[2] && en_mac_i0[2];
                end
                PROC_MTxV, PROC_MTxV_SP : begin
                    en_mac_rd[pe_idx] = en_chain_rd_r[0 + pe_idx] && en_chain_i0[0 + pe_idx];
                    regce_mac[pe_idx] = en_chain_rd_r[1 + pe_idx] && en_chain_i0[1 + pe_idx];
                end
                // PROC_MxV_SP : Successive add in MAC ADD_REG
                default : begin
                    en_mac_rd[pe_idx] = en_mac_rd_r[1] && en_mac_i0[1];
                    regce_mac[pe_idx] = en_mac_rd_r[2] && en_mac_i0[2];
                end
            endcase
        end
        rst_lmem_mac = rst_lmem_mac_r[2] && en_mac_i0[2];
    end
    
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 2; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                rst_lmem_mac_r[ps_idx] <= '0;
            end else if (en_mac_i0[ps_idx-1]) begin
                rst_lmem_mac_r[ps_idx] <= rst_lmem_mac_r[ps_idx-1];
            end
        end
    end
    
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 4; ps_idx++) begin  // ps_idx <= 2
            if (!rstn || !rstn_init) begin
                en_mac_rd_r[ps_idx] <= '0;
            end else if (en_mac_i0[ps_idx-1]) begin
                en_mac_rd_r[ps_idx] <= en_mac_rd_r[ps_idx-1];
            end
        end
    end
    
    assign en_chain_rd_r[0] = en_mac_rd_r[4];
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= NUM_PE; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                en_chain_rd_r[ps_idx] <= '0;
            end else if (en_chain_i0[ps_idx-1]) begin
                en_chain_rd_r[ps_idx] <= en_chain_rd_r[ps_idx-1];
            end
        end
    end
    
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 4; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                en_mac_wr_r[ps_idx] <= '0;
            end else if (en_mac_i0[ps_idx-1]) begin
                en_mac_wr_r[ps_idx] <= en_mac_wr_r[ps_idx-1];
            end
        end
    end
    
    // LMEM_MAC - data
    always_comb begin
        for (int pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
            case (cfg_proc_r) inside
                PROC_MxV, PROC_VXV, PROC_VXV_SP : begin
                    lmem_mac_din[pe_idx][ACC_BW-1:0] = pe_dout_acc[pe_idx][ACC_BW-1:0];
                end
                PROC_MTxV, PROC_MTxV_SP : begin
                    lmem_mac_din[pe_idx][ACC_BW-1:0] = pe_dout_mul[pe_idx][ACC_BW-1:0];
                end
                // PROC_MxV_SP : Successive add in MAC ADD_REG
                default : begin
                    lmem_mac_din[pe_idx][ACC_BW-1:0] = pe_dout_acc[pe_idx][ACC_BW-1:0];
                end
            endcase
        end
    end

    always_comb begin
        for (int pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
            pe_din_buf[pe_idx][ACC_BW-1:0] = lmem_mac_dout_reg[pe_idx][ACC_BW-1:0];
        end
    end

    // LMEM_MAC
    generate
        for (genvar pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
            // (* ram_style = "block" *)
            BRAM_SDP_1C #(
                .RAM_WIDTH(ACC_BW),
                .RAM_DEPTH(LMEM_MAC_DEPTH),
                .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
                .INIT_FILE("")
            ) LMEM_MAC (
                .addra  (addr_mac_wr),
                .addrb  (addr_mac_rd[pe_idx]),
                .dina   (lmem_mac_din[pe_idx]),
                .clka   (clk),
                .wea    (en_mac_wr),
                .enb    (en_mac_rd[pe_idx]),
                .rstb   (!rstn || !rstn_mac),
                .regceb (regce_mac[pe_idx]),
                .doutb  (lmem_mac_dout_reg[pe_idx])
            );
        end
    endgenerate
    
    // logic [8:0]     LMEM_MAC_AA[0:NUM_PE-1];
    // always_comb begin
    //     for (int pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
    //         LMEM_MAC_AA[pe_idx] = {1'b0, lmem_mac_dout[pe_idx]};
    //     end
    // end

    // logic [8:0]     LMEM_MAC_AB;
    // assign LMEM_MAC_AB = {1'b0, addr_mac_wr};

    // generate
    //     for (genvar pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
    //         rf_2p_hde_hvt_rvt_264x16m4 LMEM_MAC(
    //             // -------- PORT A (Read) --------
    //             .CLKA(clk),
    //             .CENA(!en_mac_rd[pe_idx]),  // Read Enable (active low)
    //             .AA(LMEM_MAC_AA[pe_idx]),   // Read Address
    //             // .AA(addr_mac_rd[pe_idx]),   // Read Address
    //             .QA(lmem_mac_dout[pe_idx]), // Data Output
    //             .EMAA('0),                  // Extra Margin Adjustment, used for production only
    //             // -------- PORT B (Write) --------
    //             .CLKB(clk),
    //             .CENB(!en_mac_wr),          // Write Enable (active low)
    //             .AB(LMEM_MAC_AB),           // Write Address
    //             // .AB(addr_mac_wr),           // Write Address
    //             .DB(lmem_mac_din[pe_idx]),  // Data Input
    //             .EMAB('0),                  // Extra Margin Adjustment, used for production only
    //             // -------- Shared --------
    //             .RET1N(1'b1),               // Retention Input (active low)
    //             .COLLDISN(1'b1)             // Disable internal collision detection circuitry (active low)
    //         );
    //     end
    // endgenerate
    
    // logic [ACC_BW-1:0] lmem_mac_dout [0:NUM_PE-1];
    // always_ff @(posedge clk) begin
    //     if (!rstn || !rstn_mac) begin
    //         lmem_mac_dout_reg <= '{NUM_PE{'0}};
    //     end else if (regce_mac) begin
    //         lmem_mac_dout_reg <= lmem_mac_dout;
    //     end
    // end



    // MAC MUL_MUX
    // 1'b0: din_weight_r2 => mul_in_1
    // 1'b1: lmem_dout_reg => mul_in_1
    always_comb begin
        case (cfg_proc_r)
            PROC_MxV, PROC_MTxV, PROC_VXV, PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP : begin
                mul_mux_sel_r[0] = 1'b0;
            end
            default : begin
                mul_mux_sel_r[0] = 1'b0;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 2; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                mul_mux_sel_r[ps_idx] <= '0;
            end else if (en_mac_i0[ps_idx-1]) begin
                mul_mux_sel_r[ps_idx] <= mul_mux_sel_r[ps_idx-1];
            end
        end
    end

    assign mul_mux_sel = mul_mux_sel_r[2];
    
    // MAC ADD_MUX0
    // 1'b0: Parallel Mode, mul_out_r[pe_idx]   => add_in_0[pe_idx]
    // 1'b1: Cascade Mode,  add_out_r[pe_idx-1] => add_in_0[pe_idx]
    always_comb begin
        case (cfg_proc_r)
            PROC_MxV, PROC_VXV, PROC_MxV_SP, PROC_VXV_SP : begin
                add_mux0_sel_r[0] = 1'b0;
            end
            PROC_MTxV, PROC_MTxV_SP : begin
                add_mux0_sel_r[0] = 1'b1;
            end
            default : begin
                add_mux0_sel_r[0] = 1'b0;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 3; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                add_mux0_sel_r[ps_idx] <= '0;
            end else if (en_mac_i0[ps_idx-1]) begin
                add_mux0_sel_r[ps_idx] <= add_mux0_sel_r[ps_idx-1];
            end
        end
    end

    assign add_mux0_sel = add_mux0_sel_r[3];
    
    // MAC ADD_MUX1
    // 2'b00: '0            => add_in_2
    // 2'b01: lmem_dout_reg => add_in_2
    // 2'b10: add_out_r     => add_in_2
    // 2'b11: '0            => add_in_2
    always_comb begin
        case (cfg_proc_r)
            // PROC_MxV_SP: Successive add in MAC ADD_REG, cfg_cnt0 should be 0
            PROC_MxV, PROC_VXV, PROC_MxV_SP : begin
                if (cnt1_mac == 0) begin
                    add_mux1_sel_r[0] = 2'b00;
                end else if (cfg_cnt0_r > 0) begin
                    add_mux1_sel_r[0] = 2'b01;
                end else begin
                    add_mux1_sel_r[0] = 2'b10;
                end
            end
            PROC_VXV_SP : begin    // No successive accumulation in add_out_r
                if (cnt1_mac == 0) begin
                    add_mux1_sel_r[0] = 2'b00;
                end else begin
                    add_mux1_sel_r[0] = 2'b01;
                end
            end
            PROC_MTxV, PROC_MTxV_SP : begin
                add_mux1_sel_r[0] = 2'b01;
            end
            default : begin
                add_mux1_sel_r[0] = 2'b00;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 3; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                add_mux1_sel_r[ps_idx] <= '0;
            end else if (en_mac_i0[ps_idx-1]) begin
                add_mux1_sel_r[ps_idx] <= add_mux1_sel_r[ps_idx-1];
            end
        end
    end

    assign add_mux1_sel = add_mux1_sel_r[3];
    
    
    
    // MACC
    always_ff @(posedge clk) begin
        if (!rstn || !rstn_PE) begin
            din_act_r1 <= '{NUM_PE{'0}};
        end else if (en_mac_i0[0]) begin
            din_act_r1 <= din_act;
        end
    end
    always_ff @(posedge clk) begin
        if (!rstn || !rstn_PE) begin
            din_act_r2 <= '{NUM_PE{'0}};
        end else if (en_mac_i0[1]) begin
            din_act_r2 <= din_act_r1;
        end
    end
    
    assign din_nzi_r[0] = din_nzi;
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 4; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                din_nzi_r[ps_idx] <= '0;
            end else if (en_mac_i0[ps_idx-1]) begin
                din_nzi_r[ps_idx] <= din_nzi_r[ps_idx-1];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rstn || !rstn_PE) begin
            din_weight_r1 <= '{NUM_PE{'0}};
        end else if (en_mac_i0[0]) begin
            din_weight_r1 <= din_weight;
        end
    end
    always_ff @(posedge clk) begin
        if (!rstn || !rstn_PE) begin
            din_weight_r2 <= '{NUM_PE{'0}};
        end else if (en_mac_i0[1]) begin
            din_weight_r2 <= din_weight_r1;
        end
    end

    always_comb begin
        for (int pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
            case (cfg_proc_r) inside
                PROC_MxV, PROC_VXV, PROC_MxV_SP, PROC_VXV_SP : begin
                    en_mul[pe_idx] = en_mac_i0[2];
                    en_add[pe_idx] = en_mac_i0[3];
                end
                PROC_MTxV, PROC_MTxV_SP : begin
                    en_mul[pe_idx] = en_mac_i0[2];
                    en_add[pe_idx] = en_chain_i0[2 + pe_idx];
                end
                default : begin
                    en_mul[pe_idx] = en_mac_i0[2];
                    en_add[pe_idx] = en_mac_i0[3];
                end
            endcase
        end
    end
    assign en_acc = en_acc_i0[3];

    DTV1_MACC #(
        .NUM_PE             (NUM_PE),
        .sig_width          (sig_width),
        .exp_width          (exp_width),
        .ieee_compliance    (ieee_compliance),
        .WEIGHT_BW          (WEIGHT_BW),
        .ACT_BW             (ACT_BW),
        .ACC_BW             (ACC_BW)
    ) MACC_inst (
        .clk                (clk),
        .en_mul             (en_mul),
        .en_add             (en_add),
        .en_acc             (en_acc),
        .rstn               (rstn && rstn_PE),
        .mul_mux_sel        (mul_mux_sel),
        .add_mux0_sel       (add_mux0_sel),
        .add_mux1_sel       (add_mux1_sel),
        .acc_mux_sel        (acc_mux_sel),
        .din_act            (din_act_r2),
        .din_weight         (din_weight_r2),
        .din_buf            (pe_din_buf),
        .dout_acc           (pe_dout_acc),
        .dout_mul           (pe_dout_mul)
    );
    

    
    // None, ReLU
    assign mac_func_sel_r[0] = cfg_func_r;

    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 4; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                mac_func_sel_r[ps_idx] <= FUNC_NONE;
            end else if (en_mac_o0[ps_idx-1]) begin
                mac_func_sel_r[ps_idx] <= mac_func_sel_r[ps_idx-1];
            end
        end
    end
    
    assign mac_func_sel = mac_func_sel_r[4];
    
    always_comb begin
        for (int pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
            case (mac_func_sel)
                FUNC_NONE : begin
                    mac_func_out[pe_idx] = pe_dout_acc[pe_idx];
                end
                FUNC_ReLU : begin
                    // if (pe_dout_acc[pe_idx] > 0) begin
                    if (pe_dout_acc[pe_idx][ACC_BW-1] == 1'b0) begin
                        mac_func_out[pe_idx] = pe_dout_acc[pe_idx];
                    end else begin
                        mac_func_out[pe_idx] = 0;
                    end
                end
                default : begin
                    mac_func_out[pe_idx] = pe_dout_acc[pe_idx];
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            mac_func_out_r <= '{NUM_PE{'0}};
        end else if (en_mac_o0[4]) begin
            mac_func_out_r <= mac_func_out;
        end
    end
    
    // DOUT_ACT_REG
    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            dout_act_r[0:NUM_PE-1] <= '{NUM_PE{'0}};
        end else if (en_mac_o0[5]) begin
            dout_act_r[0:NUM_PE-1] <= mac_func_out_r[0:NUM_PE-1];
        end
    end
    

    
    // LMEM_ACC Counters - LMEM Address, Accumulation Round, Repetition Round
    always_ff @(posedge clk) begin
        if ((!rstn) || (!rstn_init)) begin
            cnt0_acc <= 0;
            cnt1_acc <= 0;
            cnt2_acc <= 0;
        end else if (en_acc_i0[0]) begin
            if (cnt0_acc == cfg_cnt0_r) begin
                cnt0_acc <= 0;
                if (cnt1_acc == cfg_cnt1_r) begin
                    cnt1_acc <= 0;
                    if (cnt2_acc == cfg_cnt2_r) begin
                        cnt2_acc <= 0;
                    end else begin
                        cnt2_acc <= cnt2_acc + 1;
                    end
                end else begin
                    cnt1_acc <= cnt1_acc + 1;
                end
            end else begin
                cnt0_acc <= cnt0_acc + 1;
            end
        end
    end
    
    assign f_cnt_acc = (cnt2_acc == cfg_cnt2_r) && (cnt1_acc == cfg_cnt1_r) && (cnt0_acc == cfg_cnt0_r);
    
    assign f_cnt_acc_r[0] = f_cnt_acc & valid_i_acc_r[0];
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 6; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                f_cnt_acc_r[ps_idx] <= 1'b0;
            end else if (en_acc_i1[ps_idx-1]) begin
                f_cnt_acc_r[ps_idx] <= f_cnt_acc_r[ps_idx-1];
            end
        end
    end
    
    always_ff @(posedge clk) begin
        if ((!rstn) || (!rstn_init)) begin
            cnt_acc_mr <= 0;
        end else if (en_acc_i0[1]) begin
            if (cnt_acc_mr == cfg_cnt0_r) begin
                cnt_acc_mr <= 0;
            end else begin
                cnt_acc_mr <= cnt_acc_mr + 1;
            end
        end
    end
    
    always_ff @(posedge clk) begin
        if ((!rstn) || (!rstn_init)) begin
            cnt_acc_mw <= 0;
        end else if (en_acc_i0[4]) begin
            if (cnt_acc_mw == cfg_cnt0_r) begin
                cnt_acc_mw <= 0;
            end else begin
                cnt_acc_mw <= cnt_acc_mw + 1;
            end
        end
    end



    // LMEM_ACC - control signals
    assign rstn_acc = rstn_init;
    
    always_comb begin
        case (cfg_proc_r) inside
            PROC_MTxV : begin
                en_acc_rd_r[0] = (cnt1_acc > 0);
                en_acc_wr_r[0] = (cnt1_acc < cfg_cnt1_r);
                en_acc_rd = en_acc_rd_r[1] && en_acc_i0[1];
                regce_acc = en_acc_rd_r[2] && en_acc_i0[2];
                en_acc_wr = en_acc_wr_r[4] && en_acc_i0[4];
            end
            // PROC_MTxV_SP : Successive add in ACC ADD_REG
            default : begin
                en_acc_rd_r[0] = 1'b0;
                en_acc_wr_r[0] = 1'b0;
                en_acc_rd = en_acc_rd_r[1] && en_acc_i0[1];
                regce_acc = en_acc_rd_r[2] && en_acc_i0[2];
                en_acc_wr = en_acc_wr_r[4] && en_acc_i0[4];
            end
        endcase
    end
    
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 2; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                en_acc_rd_r[ps_idx] <= '0;
            end else if (en_acc_i0[ps_idx-1]) begin
                en_acc_rd_r[ps_idx] <= en_acc_rd_r[ps_idx-1];
            end
        end
    end
    
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 4; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                en_acc_wr_r[ps_idx] <= '0;
            end else if (en_acc_i0[ps_idx-1]) begin
                en_acc_wr_r[ps_idx] <= en_acc_wr_r[ps_idx-1];
            end
        end
    end
    
    // LMEM_ACC
    generate
        // (* ram_style = "block" *)
        BRAM_SDP_1C #(
            .RAM_WIDTH(ACC_BW),
            .RAM_DEPTH(LMEM_ACC_DEPTH),
            .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
            .INIT_FILE("")
        ) LMEM_ACC (
            .addra  (cnt_acc_mw),
            .addrb  (cnt_acc_mr),
            .dina   (pe_dout_acc[NUM_PE]),
            .clka   (clk),
            .wea    (en_acc_wr),
            .enb    (en_acc_rd),
            .rstb   (!rstn || !rstn_acc),
            .regceb (regce_acc),
            .doutb  (pe_din_buf[NUM_PE])
        );
    endgenerate
    
    // logic [8:0]     LMEM_ACC_AA;
    // assign LMEM_ACC_AA = {1'b0, cnt_acc_mr};

    // logic [8:0]     LMEM_ACC_AB;
    // assign LMEM_ACC_AB = {1'b0, cnt_acc_mw};

    // logic [ACC_BW-1:0] lmem_acc_out;

    // rf_2p_hde_hvt_rvt_264x16m4 LMEM_ACC(
    //     // -------- PORT A (Read) --------
    //     .CLKA(clk),
    //     .CENA(!en_acc_rd),          // Read Enable (active low)
    //     .AA(LMEM_ACC_AA),           // Read Address
    //     // .AA(cnt_acc_mr),            // Read Address
    //     .QA(lmem_acc_out),          // Data Output
    //     .EMAA('0),                  // Extra Margin Adjustment, used for production only
    //     // -------- PORT B (Write) --------
    //     .CLKB(clk),
    //     .CENB(!en_acc_wr),          // Write Enable (active low)
    //     .AB(LMEM_ACC_AB),           // Write Address
    //     // .AB(cnt_acc_mw),            // Write Address
    //     .DB(pe_dout_acc[NUM_PE]),  // Data Input
    //     .EMAB('0),                  // Extra Margin Adjustment, used for production only
    //     // -------- Shared --------
    //     .RET1N(1'b1),               // Retention Input (active low)
    //     .COLLDISN(1'b1)             // Disable internal collision detection circuitry (active low)
    // );
    
    // logic [ACC_BW-1:0] lmem_acc_out_reg;
    // always_ff @(posedge clk) begin
    //     if (!rstn || !rstn_acc) begin
    //         lmem_acc_out_reg <= '0;
    //     end else if (regce_acc) begin
    //         lmem_acc_out_reg <= lmem_acc_out;
    //     end
    // end
    // assign pe_din_buf[NUM_PE] = lmem_acc_out_reg;



    // ACC_MUX
    // 2'b00: '0            => acc_in_2
    // 2'b01: lmem_dout_reg => acc_in_2
    // 2'b10: acc_out_r     => acc_in_2
    // 2'b11: '0            => acc_in_2
    always_comb begin
        case (cfg_proc_r)
            // PROC_MTxV_SP: Successive add in ACC ADD_REG, cfg_cnt0 should be 0
            PROC_MTxV, PROC_MTxV_SP : begin
                if (cnt1_acc == 0) begin
                    acc_mux_sel_r[0] = 2'b00;
                end else if (cfg_cnt0_r > 0) begin
                    acc_mux_sel_r[0] = 2'b01;
                end else begin
                    acc_mux_sel_r[0] = 2'b10;
                end
            end
            default : begin
                acc_mux_sel_r[0] = 2'b00;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 3; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                acc_mux_sel_r[ps_idx] <= '0;
            end else if (en_acc_i0[ps_idx-1]) begin
                acc_mux_sel_r[ps_idx] <= acc_mux_sel_r[ps_idx-1];
            end
        end
    end

    assign acc_mux_sel = acc_mux_sel_r[3];
    


    // None, ReLU
    assign acc_func_sel_r[0] = cfg_func_r;

    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 4; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                acc_func_sel_r[ps_idx] <= FUNC_NONE;
            end else if (en_acc_o0[ps_idx-1]) begin
                acc_func_sel_r[ps_idx] <= acc_func_sel_r[ps_idx-1];
            end
        end
    end
    
    assign acc_func_sel = acc_func_sel_r[4];
    
    always_comb begin
        case (acc_func_sel)
            FUNC_NONE : begin
                acc_func_out = pe_dout_acc[NUM_PE];
            end
            default : begin
                acc_func_out = pe_dout_acc[NUM_PE];
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            acc_func_out_r <= '0;
        end else if (en_acc_o0[4]) begin
            acc_func_out_r <= acc_func_out;
        end
    end

    // DOUT_ACT_REG
    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            dout_act_r[NUM_PE] <= '0;
        end else if (en_acc_o0[5]) begin
            dout_act_r[NUM_PE] <= acc_func_out_r;
        end
    end
    

    // Output Data
    always_comb begin
        for (int pe_idx = 0; pe_idx <= NUM_PE; pe_idx++) begin
            dout_act[pe_idx] = dout_act_r[pe_idx];
        end
    end

    
endmodule
