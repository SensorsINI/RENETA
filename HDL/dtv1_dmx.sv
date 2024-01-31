
import definesPkg::*;

// IPM Data Multiplexer

//// Pipeline Stages:
//// 0: INPUT
//// 1: RPT
//// 2: MUX_DS
//// 3: MUX_UB0
//// 4: MUX_UB1
//// 5: HIST_NZI, SYNC

// Pipeline Stages:
// 0: INPUT
// 1: RPT
// 2: MUX_DS, MUX_U_OP1, REG_OP1
// 3: REG_OP0, MUX_UB_OP1
// 4: OUTPUT

// cfg_ready initialized to 1?
//           set to 1 only when cfg_valid==1?

// Modified for dtv1.0_perf_estm:
//   Add output signal en_hist_nzi


module IPM_DMX #(
    // parameter NUM_PE        = 16,               //16
    // parameter MAX_N         = 256,              //1024
    // parameter MAX_M         = 256,              //32
    // parameter MAX_NoP       = MAX_N/NUM_PE,     //64

    // parameter DRAM_WW       = 256,              //1024

    parameter SMEM_WW       = 16,

    // parameter sig_width     = 7,
    // parameter exp_width     = 8,
    // parameter ieee_compliance = 1,

    // localparam WEIGHT_BW    = 1 + exp_width + sig_width,
    // localparam ACT_BW       = 1 + exp_width + sig_width,

    localparam WSEL_BW      = $clog2(NUM_PE) + 1    // {WordOp, WordIdx}

    // localparam MAX_CNT      = (MAX_N>MAX_M)? (MAX_N):(MAX_M)
) (
    input  logic                        clk,
    input  logic                        rstn,
    
    input  logic                        cfg_valid,
    // input  PROC_t                       cfg_proc,
    // input  logic [$clog2(MAX_CNT)-1:0]  cfg_cnt0,
    // input  logic [$clog2(MAX_CNT)-1:0]  cfg_cnt1,
    // input  logic [$clog2(MAX_CNT)-1:0]  cfg_cnt2,
    input  cfg_t                        cfg_data,
    output logic                        cfg_ready,

    input  logic [$clog2(MAX_N)-1:0]    din_nzn,
    output logic                        pop_nzn,
    
    input  logic [$clog2(MAX_N)-1:0]    din_nzi,
    output logic                        pop_nzi,

    // ---------------- DRAM Input Channel ----------------
    // input  logic [DRAM_WW-1:0]          dram_data,
    input  logic [SMEM_WW-1:0]          dram_data[0:NUM_PE-1],
    input  logic                        dram_empty,
    output logic                        dram_pop,

    // ---------------- SMEM Input Channels ----------------
    input  logic [SMEM_WW-1:0]          smem1_data[0:NUM_PE-1],
    input  logic [WSEL_BW-1:0]          smem1_dwsel,
    input  logic                        smem1_empty,
    output logic                        smem1_pop,

    input  logic [SMEM_WW-1:0]          smem2_data[0:NUM_PE-1],
    input  logic [WSEL_BW-1:0]          smem2_dwsel,
    input  logic                        smem2_empty,
    output logic                        smem2_pop,
    
    // ---------------- Output Channels ----------------
    output logic [ACT_BW-1:0]           dout_act[0:NUM_PE-1],
    output logic [WEIGHT_BW-1:0]        dout_weight[0:NUM_PE-1],
    output logic [$clog2(MAX_N)-1:0]    dout_nzi,
    output logic                        en_hist_nzi,
    output logic                        valid_o,
    input  logic                        ready_i
);


// -----------------------------------------------------------------------------
// Global variables

    // Overall - control signals
    logic                               rstn_init;
    
    // Overall - flags
    logic [0:5]                         f_I;
    // logic [0:5]                         f_I_dram;
    // logic [0:5]                         f_I_smem1;
    // logic [0:5]                         f_I_smem2;
    logic [0:5]                         f_O;
    
    // Config
    PROC_t                              cfg_proc_r;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt0_r;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt1_r;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt2_r;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt0_r1;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt1_r1;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt2_r1;

    // logic [$clog2(MAX_N)-1:0]           din_nzn_r;
    // logic [0:1]                         pop_nzn_r;

    logic                               valid_i_eff;
    logic                               ready_i_eff;

    logic                               empty_any_eff;
    // logic                               valid_i_fifos;
    // logic                               valid_i_dram;
    // logic                               valid_i_smem1;
    // logic                               valid_i_smem2;

    logic [0:5]                         valid_i_r;
    logic [0:5]                         valid_o_r;
    
    // FSM - states
    // (* mark_debug = "true" *)
    enum logic [1:0] {S_IDLE, S_INIT, S_STREAM} state;
    logic                               f_proc_end;
    
    // Pipeline Control Signals
    logic [0:4]                         en_i0;
    logic [0:4]                         en_i1;
    logic [0:4]                         en_o0;
    logic [0:4]                         en_o1;

    // Data I/O Counters
    logic [$clog2(MAX_CNT)-1:0]         cnt0;   // Inner most loop
    logic [$clog2(MAX_CNT)-1:0]         cnt1;
    logic [$clog2(MAX_CNT)-1:0]         cnt2;   // Outer most loop
    logic                               f_cnt_i;
    logic [0:5]                         f_cnt_i_r;
    // logic                               f_cnt_o;
    // logic [0:5]                         f_cnt_o_r;
    logic [0:2]                         f_cnt12_r;

    // // Input Data Repeater
    // logic [SMEM_WW-1:0]                 dram_data_r[0:NUM_PE-1];
    // logic [SMEM_WW-1:0]                 smem1_data_r[0:NUM_PE-1];
    // logic [WSEL_BW-1:0]                 smem1_dwsel_r;
    // logic [SMEM_WW-1:0]                 smem2_data_r[0:NUM_PE-1];
    // logic [WSEL_BW-1:0]                 smem2_dwsel_r;

    // Input FIFO Read Enable
    logic                               pop_nzi_r[0:1];
    logic                               ren_dram_r[0:1];
    logic                               ren_smem1_r[0:1];
    logic                               ren_smem2_r[0:1];

    // DRAM/SMEM Mux
    logic [SMEM_WW-1:0]                 mux_ds[0:NUM_PE-1];
    logic [SMEM_WW-1:0]                 mux_ds_r[0:NUM_PE-1];
    logic                               mux_ds_sel;
    logic                               mux_ds_sel_r[1:2];

    // Operand 0 Data Register
    logic [SMEM_WW-1:0]                 op0_data_r[0:NUM_PE-1];

    // Operand 1 Data Register
    logic [SMEM_WW-1:0]                 op1_data_r[0:NUM_PE-1];

    // Broadcast Mux
    // logic [SMEM_WW-1:0]                 mux_b_op0;
    logic [SMEM_WW-1:0]                 mux_b_op1;
    // logic [SMEM_WW-1:0]                 mux_b_op0_r;
    logic [SMEM_WW-1:0]                 mux_b_op1_r;
    // logic [$clog2(NUM_PE)-1:0]          mux_b_op0_sel;
    logic [$clog2(NUM_PE)-1:0]          mux_b_op1_sel;
    // logic [$clog2(NUM_PE)-1:0]          mux_b_op0_sel_r[0:1];
    logic [$clog2(NUM_PE)-1:0]          mux_b_op1_sel_r[2:2];

    // Unicast/Broadcast Mux
    // logic [SMEM_WW-1:0]                 mux_ub_op0[0:NUM_PE-1];
    logic [SMEM_WW-1:0]                 mux_ub_op1[0:NUM_PE-1];
    // logic [SMEM_WW-1:0]                 mux_ub_op0_r[0:NUM_PE-1];
    logic [SMEM_WW-1:0]                 mux_ub_op1_r[0:NUM_PE-1];
    // logic                               mux_ub_op0_sel;
    logic                               mux_ub_op1_sel;
    // logic                               mux_ub_op0_sel_r[0:2];
    logic                               mux_ub_op1_sel_r[2:3];

    // Output Data Register
    logic [SMEM_WW-1:0]                 dout_op0_r[0:NUM_PE-1];     // dout_weight_r
    logic [SMEM_WW-1:0]                 dout_op1_r[0:NUM_PE-1];     // dout_act_r

    // NZI Register
    logic [$clog2(MAX_N)-1:0]           din_nzi_r[2:5];
    logic                               en_hist_nzi_r[4:5];

    // NZI History
    logic                               ready_hist;

    
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
                    state <= S_STREAM;
                end
                
                S_STREAM : begin
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
    
    assign f_proc_end = f_cnt_i_r[5] && valid_i_r[5] && ready_i_eff;
    // assign f_proc_end = f_cnt_o_r[5] && valid_o_r[5] && ready_i_eff;
    
    
    
    // Config Signals

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
                S_STREAM : begin
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
                S_STREAM : begin
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
            cfg_cnt0_r1     <= '0;
            cfg_cnt1_r1     <= '0;
            cfg_cnt2_r1     <= '0;
        end else if ((state == S_IDLE) && cfg_valid) begin
            cfg_cnt0_r1     <= cfg_data.cnt0;
            cfg_cnt1_r1     <= cfg_data.cnt1;
            cfg_cnt2_r1     <= cfg_data.cnt2;
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
                    end else if (valid_i_r[0] && (cnt0 == cfg_cnt0_r) && !f_cnt_i && ready_i_eff) begin
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
                end else if (valid_i_r[0] && (cnt0 == cfg_cnt0_r) && !f_cnt_i && ready_i_eff) begin   // S_STREAM
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
    
    always_comb begin
        case (cfg_proc_r) inside
            PROC_MxV, PROC_MTxV, PROC_VXV, PROC_VXV_SP : begin
                // valid_i_eff = ren_dram_r[2] && (!dram_empty || f_cnt12_r[2]) && ren_smem1_r[2] && !smem1_empty;
                valid_i_eff = (!dram_empty || f_cnt12_r[2]) && !smem1_empty;
                empty_any_eff = (dram_empty && !f_cnt12_r[2]) || smem1_empty;
            end
            PROC_MxV_SP, PROC_MTxV_SP : begin
                // valid_i_eff = ren_dram_r[2] && !dram_empty && ren_smem1_r[2] && !smem1_empty;
                valid_i_eff = !dram_empty && !smem1_empty;
                empty_any_eff = dram_empty || smem1_empty;
            end
            default : begin
                valid_i_eff = 1'b0;
                empty_any_eff = 1'b1;                                       // ???
            end
        endcase
    end

    assign valid_i_r[0] = f_I[0] && valid_i_eff;
    assign valid_i_r[1] = f_I[1] && valid_i_eff;
    // assign valid_i_r[2] = f_I[2] && valid_i_eff;                     // ???
    always_ff @(posedge clk) begin
        for (int ps_idx = 2; ps_idx <= 5; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                valid_i_r[ps_idx] <= 1'b0;
            end else if (ready_i_eff) begin
                valid_i_r[ps_idx] <= valid_i_r[ps_idx-1];
            end
        end
    end


    assign ready_i_eff = ready_i;  // TODO


    assign valid_o_r[0] = f_O[0] && valid_i_eff;
    assign valid_o_r[1] = f_O[1] && valid_i_eff;
    // assign valid_o_r[2] = f_O[2] && valid_i_eff;    // valid_i_r[2]  // ???
    always_ff @(posedge clk) begin
        for (int ps_idx = 2; ps_idx <= 5; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                valid_o_r[ps_idx] <= 1'b0;
            end else if (ready_i_eff) begin
                valid_o_r[ps_idx] <= valid_o_r[ps_idx-1];
            end
        end
    end
    
    always_comb begin
        case (cfg_proc_r) inside
            PROC_MxV, PROC_MTxV, PROC_VXV, PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP : begin
                valid_o = valid_o_r[5];
            end
            default : begin
                valid_o = 1'b0;
            end
        endcase
    end


    // // FIFO data output valid
    // always_ff @(posedge clk) begin
    //     if (!rstn || !rstn_init) begin
    //         valid_i_dram  <= 1'b0;
    //         valid_i_smem1 <= 1'b0;
    //         valid_i_smem2 <= 1'b0;
    //     end else begin
    //         valid_i_dram  <= dram_pop  && !dram_empty;
    //         valid_i_smem1 <= smem1_pop && !smem1_empty;
    //         valid_i_smem2 <= smem2_pop && !smem2_empty;
    //     end
    // end

    // always_comb begin
    //     case (cfg_proc_r) inside
    //         PROC_MxV, PROC_MTxV, PROC_VXV, PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP : begin
    //             valid_i_fifos = valid_i_dram && valid_i_smem1;
    //         end
    //         default : begin
    //             valid_i_fifos = 1'b0;
    //         end
    //     endcase
    // end

    
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

    // Flag - Input
    always_ff @(posedge clk) begin
        if (!rstn) begin
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
                S_STREAM : begin
                    if (cfg_proc_r inside {PROC_MxV, PROC_MTxV, PROC_VXV, PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP}) begin
                        // Deassert when last input data accepted
                        if (f_cnt_i_r[0] && valid_i_r[0] && ready_i_eff) begin
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
        for (int ps_idx = 1; ps_idx <= 5; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                f_I[ps_idx] <= 1'b0;
            end else if (en_i1[ps_idx-1]) begin
                f_I[ps_idx] <= f_I[ps_idx-1];
            end
        end
    end
    
    // // Flag - Input DRAM
    // always_ff @(posedge clk) begin
    //     if (!rstn) begin
    //         f_I_dram[0] <= 1'b0;
    //     end else begin
    //         case (state) inside
    //             S_INIT : begin
    //                 if (cfg_proc_r inside {PROC_MxV, PROC_MTxV, PROC_VXV, PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP}) begin
    //                     f_I_dram[0] <= 1'b1;
    //                 end else begin
    //                     f_I_dram[0] <= 1'b0;
    //                 end
    //             end
    //             S_STREAM : begin
    //                 if (cfg_proc_r inside {PROC_MxV, PROC_MTxV, PROC_VXV, PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP}) begin
    //                     // Deassert when last input data accepted
    //                     if (f_cnt_i_r[0] && valid_i_r[0] && ready_i_eff) begin
    //                         f_I_dram[0] <= 1'b0;
    //                     end
    //                 end
    //             end
    //             default : begin
    //                 f_I_dram[0] <= 1'b0;
    //             end
    //         endcase
    //     end
    // end
    
    // always_ff @(posedge clk) begin
    //     for (int ps_idx = 1; ps_idx <= 5; ps_idx++) begin
    //         if (!rstn || !rstn_init) begin
    //             f_I_dram[ps_idx] <= 1'b0;
    //         end else if (en_i1[ps_idx-1]) begin
    //             f_I_dram[ps_idx] <= f_I_dram[ps_idx-1];
    //         end
    //     end
    // end
    
    // // Flag - Input SMEM Read Channel 1
    // always_ff @(posedge clk) begin
    //     if (!rstn) begin
    //         f_I_smem1[0] <= 1'b0;
    //     end else begin
    //         case (state) inside
    //             S_INIT : begin
    //                 if (cfg_proc_r inside {PROC_MxV, PROC_MTxV, PROC_VXV, PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP}) begin
    //                     f_I_smem1[0] <= 1'b1;
    //                 end else begin
    //                     f_I_smem1[0] <= 1'b0;
    //                 end
    //             end
    //             S_STREAM : begin
    //                 if (cfg_proc_r inside {PROC_MxV, PROC_MTxV, PROC_VXV, PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP}) begin
    //                     // Deassert when last input data accepted
    //                     if (f_cnt_i_r[0] && valid_i_r[0] && ready_i_eff) begin
    //                         f_I_smem1[0] <= 1'b0;
    //                     end
    //                 end
    //             end
    //             default : begin
    //                 f_I_smem1[0] <= 1'b0;
    //             end
    //         endcase
    //     end
    // end
    
    // always_ff @(posedge clk) begin
    //     for (int ps_idx = 1; ps_idx <= 5; ps_idx++) begin
    //         if (!rstn || !rstn_init) begin
    //             f_I_smem1[ps_idx] <= 1'b0;
    //         end else if (en_i1[ps_idx-1]) begin
    //             f_I_smem1[ps_idx] <= f_I_smem1[ps_idx-1];
    //         end
    //     end
    // end
    
    // // Flag - Input SMEM Read Channel 2
    // always_ff @(posedge clk) begin
    //     if (!rstn) begin
    //         f_I_smem2[0] <= 1'b0;
    //     end else begin
    //         case (state) inside
    //             S_INIT : begin
    //                 if (cfg_proc_r inside {}) begin
    //                     f_I_smem2[0] <= 1'b1;
    //                 end else begin
    //                     f_I_smem2[0] <= 1'b0;
    //                 end
    //             end
    //             S_STREAM : begin
    //                 if (cfg_proc_r inside {}) begin
    //                     // Deassert when last input data accepted
    //                     if (f_cnt_i_r[0] && valid_i_r[0] && ready_i_eff) begin
    //                         f_I_smem2[0] <= 1'b0;
    //                     end
    //                 end
    //             end
    //             default : begin
    //                 f_I_smem2[0] <= 1'b0;
    //             end
    //         endcase
    //     end
    // end
    
    // always_ff @(posedge clk) begin
    //     for (int ps_idx = 1; ps_idx <= 5; ps_idx++) begin
    //         if (!rstn || !rstn_init) begin
    //             f_I_smem2[ps_idx] <= 1'b0;
    //         end else if (en_i1[ps_idx-1]) begin
    //             f_I_smem2[ps_idx] <= f_I_smem2[ps_idx-1];
    //         end
    //     end
    // end
    
    // Flag - Overall output
    always_ff @(posedge clk) begin
        if (!rstn) begin
            f_O[0] <= 1'b0;
        end else begin
            case (state) inside
                S_INIT : begin
                    f_O[0] <= 1'b1;
                end
                S_STREAM : begin
                    if (f_cnt_i_r[0] && valid_i_r[0] && ready_i_eff) begin
                    // if (f_cnt_o_r[0] && valid_o_r[0] && ready_i_eff) begin
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
        for (int ps_idx = 1; ps_idx <= 5; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                f_O[ps_idx] <= 1'b0;
            end else if (en_o1[ps_idx-1]) begin
                f_O[ps_idx] <= f_O[ps_idx-1];
            end
        end
    end
    
    
    
    // Pipeline Control Signals
    always_comb begin
        for (int ps_idx = 0; ps_idx <= 4; ps_idx++) begin
            en_i0[ps_idx] = valid_i_r[ps_idx] && ready_i_eff;
            en_i1[ps_idx] = (valid_i_r[ps_idx] || valid_i_r[ps_idx+1]) && ready_i_eff;
            en_o0[ps_idx] = valid_o_r[ps_idx] && ready_i_eff;
            en_o1[ps_idx] = (valid_o_r[ps_idx] || valid_o_r[ps_idx+1]) && ready_i_eff;
        end
    end



    // SMEM Data Counters
    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            cnt0 <= 0;
            cnt1 <= 0;
            cnt2 <= 0;
        end else if (valid_i_r[0] && ready_i_eff) begin
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
    
    assign f_cnt_i = (cnt2 == cfg_cnt2_r) && (cnt1 == cfg_cnt1_r) && (cnt0 == cfg_cnt0_r);
    
    assign f_cnt_i_r[0] = f_cnt_i && valid_i_r[0];  // ???
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 5; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                f_cnt_i_r[ps_idx] <= '0;
            end else if (en_i1[ps_idx-1]) begin
                f_cnt_i_r[ps_idx] <= f_cnt_i_r[ps_idx-1];
            end
        end
    end
    
    // assign f_cnt_o = (cnt2 == cfg_cnt2_r) && (cnt1 == cfg_cnt1_r) && (cnt0 == cfg_cnt0_r);
    
    // assign f_cnt_o_r[0] = f_cnt_o && valid_o_r[0];
    // always_ff @(posedge clk) begin
    //     for (int ps_idx = 1; ps_idx <= 5; ps_idx++) begin
    //         if (!rstn || !rstn_init) begin
    //             f_cnt_o_r[ps_idx] <= '0;
    //         end else if (en_o1[ps_idx-1]) begin
    //             f_cnt_o_r[ps_idx] <= f_cnt_o_r[ps_idx-1];
    //         end
    //     end
    // end

    assign f_cnt12_r[0] = (cnt2 == cfg_cnt2_r) && (cnt1 == cfg_cnt1_r) && valid_i_r[0];
    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 2; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                f_cnt12_r[ps_idx] <= '0;
            end else if (en_i1[ps_idx-1]) begin
                f_cnt12_r[ps_idx] <= f_cnt12_r[ps_idx-1];
            end
        end
    end
    


    // Input FIFO Read Enable

    always_comb begin
        case (cfg_proc_r) inside
            PROC_VXV_SP : begin
                pop_nzi_r[0] = f_I[0];
            end
            default : begin
                pop_nzi_r[0] = 1'b0;
            end
        endcase
    end

    always_comb begin
        case (cfg_proc_r) inside
            PROC_MxV, PROC_MTxV, PROC_VXV, PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP : begin
                // Repeat streaming dram_data for (cfg_cnt0_r) times
                ren_dram_r[0] = (cnt0 == 0) && f_I[0];
            end
            default : begin
                ren_dram_r[0] = 1'b0;
            end
        endcase
    end

    always_comb begin
        case (cfg_proc_r) inside
            PROC_MxV, PROC_MTxV, PROC_VXV, PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP : begin
                ren_smem1_r[0] = f_I[0];
            end
            default : begin
                ren_smem1_r[0] = 1'b0;
            end
        endcase
    end

    always_comb begin
        case (cfg_proc_r) inside
            PROC_MxV, PROC_MTxV, PROC_VXV, PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP : begin
                ren_smem2_r[0] = 1'b0;
            end
            default : begin
                ren_smem2_r[0] = 1'b0;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        for (int ps_idx = 1; ps_idx <= 1; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                pop_nzi_r[ps_idx] <= 1'b0;
                ren_dram_r[ps_idx] <= 1'b0;
                ren_smem1_r[ps_idx] <= 1'b0;
                ren_smem2_r[ps_idx] <= 1'b0;
            end else if (en_i1[ps_idx-1]) begin
                pop_nzi_r[ps_idx] <= pop_nzi_r[ps_idx-1];
                ren_dram_r[ps_idx] <= ren_dram_r[ps_idx-1];
                ren_smem1_r[ps_idx] <= ren_smem1_r[ps_idx-1];
                ren_smem2_r[ps_idx] <= ren_smem2_r[ps_idx-1];
            end
        end
    end

    assign pop_nzi = pop_nzi_r[1] && !empty_any_eff && ready_i_eff;
    assign dram_pop = ren_dram_r[1] && !dram_empty && !empty_any_eff && ready_i_eff;
    assign smem1_pop = ren_smem1_r[1] && !smem1_empty && !empty_any_eff && ready_i_eff;
    assign smem2_pop = ren_smem2_r[1] && !smem2_empty && !empty_any_eff && ready_i_eff;
    


    // Input Data Repeater

    // always_ff @(posedge clk) begin
    //     if (!rstn || !rstn_init) begin
    //         dram_data_r <= '{NUM_PE{'0}};
    //     end else if (en_i0[0]) begin                        // && f_I_dram
    //         dram_data_r[0:NUM_PE-1] <= dram_data[0:NUM_PE-1];
    //     end
    // end
    
    // always_ff @(posedge clk) begin
    //     if (!rstn || !rstn_init) begin
    //         rd_data_r[2] <= '{NUM_PE{'0}};
    //         // rd_dwsel_r[2] <= '0;
    //     end else if (en_i0[0]) begin                        // && f_I_smem2
    //         rd_data_r[2][0:NUM_PE-1] <= rd_data[2][0:NUM_PE-1];
    //         // rd_dwsel_r[2] <= rd_dwsel[2];
    //     end
    // end
    
    // always_ff @(posedge clk) begin
    //     if (!rstn || !rstn_init) begin
    //         rd_data_r[1] <= '{NUM_PE{'0}};
    //         // rd_dwsel_r[1] <= '0;
    //     end else if (en_i0[0]) begin                        // && f_I_smem1
    //         rd_data_r[1][0:NUM_PE-1] <= rd_data[1][0:NUM_PE-1];
    //         // rd_dwsel_r[1] <= rd_dwsel[1];
    //     end
    // end



    // DRAM/SMEM Mux
    
    // mux_ds_sel
    // 1'b0: DRAM
    // 1'b1: SMEM Read Channel 2
    always_comb begin
        case (cfg_proc_r) inside
            PROC_MxV, PROC_MTxV, PROC_VXV, PROC_MxV_SP, PROC_MTxV_SP, PROC_VXV_SP : begin
                mux_ds_sel_r[1] = 1'b0;
            end
            default : begin
                mux_ds_sel_r[1] = 1'b0;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        for (int ps_idx = 2; ps_idx <= 2; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                mux_ds_sel_r[ps_idx] <= 1'b0;
            end else if (en_i0[ps_idx-1]) begin
                mux_ds_sel_r[ps_idx] <= mux_ds_sel_r[ps_idx-1];
            end
        end
    end

    assign mux_ds_sel = mux_ds_sel_r[2];

    always_comb begin
        case (mux_ds_sel)
            1'b0 : mux_ds[0:NUM_PE-1] = dram_data[0:NUM_PE-1];
            1'b1 : mux_ds[0:NUM_PE-1] = smem2_data[0:NUM_PE-1];
            default : mux_ds[0:NUM_PE-1] = dram_data[0:NUM_PE-1];
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            mux_ds_r <= '{NUM_PE{'0}};
        end else if (en_i0[2]) begin
            mux_ds_r[0:NUM_PE-1] <= mux_ds[0:NUM_PE-1];
        end
    end



    // Operand 0 Data Register
    
    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            op0_data_r <= '{NUM_PE{'0}};
        end else if (en_i0[3]) begin
            op0_data_r[0:NUM_PE-1] <= mux_ds_r[0:NUM_PE-1];
        end
    end
    


    // Operand 1 Data Register
    
    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            op1_data_r <= '{NUM_PE{'0}};
        end else if (en_i0[2]) begin
            op1_data_r[0:NUM_PE-1] <= smem1_data[0:NUM_PE-1];
        end
    end
    


    // Broadcast Mux

    // mux_b_op1_sel (pe_idx)
    always_comb begin
        case (cfg_proc_r) inside
            PROC_MxV, PROC_VXV, PROC_MxV_SP, PROC_VXV_SP : begin
                mux_b_op1_sel_r[2] = smem1_dwsel[WSEL_BW-1-1:0];
            end
            PROC_MTxV, PROC_MTxV_SP : begin
                mux_b_op1_sel_r[2] = '0;        // Not broadcast
            end
            default : begin
                mux_b_op1_sel_r[2] = '0;
            end
        endcase
    end

    // always_ff @(posedge clk) begin
    //     for (int ps_idx = 2; ps_idx <= 2; ps_idx++) begin
    //         if (!rstn || !rstn_init) begin
    //             mux_b_op1_sel_r[ps_idx] <= 1'b0;
    //         end else if (en_i0[ps_idx-1]) begin
    //             mux_b_op1_sel_r[ps_idx] <= mux_b_op1_sel_r[ps_idx-1];
    //         end
    //     end
    // end

    assign mux_b_op1_sel = mux_b_op1_sel_r[2];

    always_comb begin
        mux_b_op1 = smem1_data[mux_b_op1_sel];
    end

    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            mux_b_op1_r <= '0;
        end else if (en_i0[2]) begin
            mux_b_op1_r <= mux_b_op1;
        end
    end



    // Unicast/Broadcast Mux

    // mux_ub_op1_sel
    // 1'b0: Unicast
    // 1'b1: Broadcast
    always_comb begin
        case (cfg_proc_r) inside
            PROC_MxV, PROC_VXV, PROC_MxV_SP, PROC_VXV_SP : begin
                mux_ub_op1_sel_r[2] = 1'b1;     // Broadcast
            end
            PROC_MTxV, PROC_MTxV_SP : begin
                mux_ub_op1_sel_r[2] = 1'b0;     // Unicast
            end
            default : begin
                mux_ub_op1_sel_r[2] = 1'b0;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        for (int ps_idx = 3; ps_idx <= 3; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                mux_ub_op1_sel_r[ps_idx] <= 1'b0;
            end else if (en_i0[ps_idx-1]) begin
                mux_ub_op1_sel_r[ps_idx] <= mux_ub_op1_sel_r[ps_idx-1];
            end
        end
    end

    assign mux_ub_op1_sel = mux_ub_op1_sel_r[3];

    always_comb begin
        case (mux_ub_op1_sel)
            1'b0 : mux_ub_op1[0:NUM_PE-1] = op1_data_r[0:NUM_PE-1]; // Unicast
            1'b1 : mux_ub_op1[0:NUM_PE-1] = '{NUM_PE{mux_b_op1_r}}; // Broadcast
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            mux_ub_op1_r <= '{NUM_PE{'0}};
        end else if (en_i0[3]) begin
            mux_ub_op1_r[0:NUM_PE-1] <= mux_ub_op1[0:NUM_PE-1];
        end
    end
    


    // Output Data Register
    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            dout_op0_r <= '{NUM_PE{'0}};
            dout_op1_r <= '{NUM_PE{'0}};
        end else if (en_i0[4]) begin
            dout_op0_r[0:NUM_PE-1] <= op0_data_r[0:NUM_PE-1];
            dout_op1_r[0:NUM_PE-1] <= mux_ub_op1_r[0:NUM_PE-1];
        end
    end



    // NZI Register
    assign din_nzi_r[2] = din_nzi;
    always_ff @(posedge clk) begin
        for (int ps_idx = 3; ps_idx <= 5; ps_idx++) begin
            if (!rstn || !rstn_init) begin
                din_nzi_r[ps_idx] <= 1'b0;
            end else if (en_i0[ps_idx-1]) begin
                din_nzi_r[ps_idx] <= din_nzi_r[ps_idx-1];
            end
        end
    end

    // HIST_NZI enable
    // Indicates whether hist_nzi should record recent indicies
    //   and stall when necessary to prevent RAW hazard
    always_comb begin
        case (cfg_proc_r) inside
            PROC_MxV, PROC_MTxV, PROC_VXV, PROC_VXV_SP : begin
                en_hist_nzi_r[4] = 1'b1;
            end
            default : begin
                en_hist_nzi_r[4] = 1'b0;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            en_hist_nzi_r[5] <= 1'b0;
        end else if (en_i0[4]) begin
            en_hist_nzi_r[5] <= en_hist_nzi_r[4];
        end
    end

    // Output Data
    assign dout_weight[0:NUM_PE-1] = dout_op0_r[0:NUM_PE-1];
    assign dout_act[0:NUM_PE-1] = dout_op1_r[0:NUM_PE-1];
    assign dout_nzi = din_nzi_r[5];
    assign en_hist_nzi = en_hist_nzi_r[5];

endmodule
