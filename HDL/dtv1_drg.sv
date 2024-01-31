
import definesPkg::*;

// DRAM Read Request Generator

// cfg_ready initialized to 1?
//           set to 1 only when cfg_valid==1?

// Modified for dtv1.0_perf_estm:
//   Set ready_i_nzi=0 when pop_nzi if empty
//     Set rd_avalid to 0 when waiting for ready_i_nzi after a completed read address transaction

// (?) PROC_MTxV_SP: set cfg_cnt2_r = cfg_cnt1_r = 0


module IPM_DRG #(
    // parameter NUM_PE        = 16,               //16
    // parameter MAX_N         = 256,              //1024
    // parameter MAX_M         = 256,              //32
    // parameter MAX_NoP       = MAX_N/NUM_PE,     //64

    // parameter DRAM_WW       = 1024,             // 64 * 16-b

    // Parameters of AXIS Master Bus Interface M_AXIS_MM2S_CMD
    // Parameters of AXIS Master Bus Interface M_AXIS_S2MM_CMD
    parameter AXI_DM_CMD_WIDTH  = 72,

    parameter DRAM_ADDR_BW      = 32,
    parameter BTT_BW            = 23,
    // localparam MAX_CNT      = (MAX_N>MAX_M)? (MAX_N):(MAX_M),
    // localparam NT_BW        = $clog2(MAX_M+1)

    parameter AXI_DM_CMD_BASE  = 32'h4080_0000      // End-of-Frame, INCR address
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

    input  logic [$clog2(MAX_N)-1:0]    cfg_nzn,
    input  logic [DRAM_ADDR_BW-1:0]     dram_addr,

    // input  logic [$clog2(MAX_N)-1:0]    din_nzn,
    // output logic                        pop_nzn,

    input  logic [$clog2(MAX_N)-1:0]    din_nzi,
    output logic                        pop_nzi,
    input  logic                        empty_nzi,

    // ---------------- DRAM Read Channels ----------------
    // Ports of AXIS Master Bus Interface M_AXIS_MM2S_CMD
    output logic                        cmd_tvalid,
    output logic [AXI_DM_CMD_WIDTH-1:0] cmd_tdata,
    input  logic                        cmd_tready
    
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
    // logic [$clog2(MAX_M)-1:0]           cfg_t_r;
    logic [$clog2(MAX_M)-1:0]           cfg_n1_r;
    // logic [$clog2(MAX_CNT)-1:0]         cfg_cnt0_r;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt1_r;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt2_r;
    // logic [$clog2(MAX_CNT)-1:0]         cfg_cnt0_r1;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt1_r1;
    logic [$clog2(MAX_CNT)-1:0]         cfg_cnt2_r1;

    logic [$clog2(MAX_N)-1:0]           cfg_nzn_r1;

    logic [DRAM_ADDR_BW-1:0]            dram_addr_r;

    // logic [$clog2(MAX_N)-1:0]           din_nzn_r;
    // logic [0:1]                         pop_nzn_r;

    logic                               ready_i_eff;
    // logic                               ready_i_nzn;
    logic                               ready_i_nzi;

    // Output Signal
    logic [0:1]                         valid_o_r;
    
    // FSM - states
    // (* mark_debug = "true" *)
    enum logic [1:0] {S_IDLE, S_INIT, S_GEN} state;
    logic                               f_proc_end;
    
    // DRAM Data I/O Counters
    // logic [$clog2(MAX_CNT)-1:0]         cnt0;   // Inner most loop
    logic [$clog2(MAX_CNT)-1:0]         cnt1;
    logic [$clog2(MAX_CNT)-1:0]         cnt2;   // Outer most loop
    logic                               f_cnt_o;
    logic [0:1]                         f_cnt_o_r;

    // AXI-DM Commands
    logic [DRAM_ADDR_BW-1:0]            addr;
    logic [BTT_BW-1:0]                  btt;
    logic                               cmd_tvalid_r0;
    logic                               cmd_tvalid_r1;
    logic                               cmd_tready_d;
    logic [AXI_DM_CMD_WIDTH-1:0]        cmd_tdata_r;
    
    
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
            // cfg_cnt0_r1     <= '0;
            cfg_cnt1_r1     <= '0;
            cfg_cnt2_r1     <= '0;
            cfg_nt_r        <= '0;
            cfg_n1_r        <= '0;
            cfg_nzn_r1      <= '0;
            dram_addr_r     <= '0;
        end else if ((state == S_IDLE) && cfg_valid) begin
            // cfg_cnt0_r1     <= cfg_data.cnt0;
            cfg_cnt1_r1     <= cfg_data.cnt1;
            cfg_cnt2_r1     <= cfg_data.cnt2;
            cfg_nt_r        <= cfg_data.nt;
            cfg_n1_r        <= cfg_data.n1;
            cfg_nzn_r1      <= cfg_nzn;
            dram_addr_r     <= dram_addr;
        end
    end

    always_ff @(posedge clk) begin
        if (!rstn) begin
            // cfg_cnt0_r <= '0;
            cfg_cnt1_r <= '0;
            cfg_cnt2_r <= '0;
        end else begin
            case (cfg_proc_r) inside
                PROC_MxV_SP : begin
                    if (state == S_INIT) begin
                        // cfg_cnt0_r <= cfg_cnt0_r1;
                        cfg_cnt1_r <= cfg_nzn_r1;
                        cfg_cnt2_r <= cfg_cnt2_r1;
                    end
                end
                PROC_MTxV_SP : begin
                    if (state == S_INIT) begin
                        // cfg_cnt0_r <= cfg_cnt0_r1;
                        cfg_cnt1_r <= cfg_cnt1_r1;
                        cfg_cnt2_r <= cfg_nzn_r1;
                    end
                end
                PROC_VXV_SP : begin
                    if (state == S_INIT) begin
                        // cfg_cnt0_r <= din_nzn;
                        cfg_cnt1_r <= cfg_cnt1_r1;
                        cfg_cnt2_r <= cfg_cnt2_r1;
                    end
                end
                default : begin
                    if (state == S_INIT) begin
                        // cfg_cnt0_r <= cfg_cnt0_r1;
                        cfg_cnt1_r <= cfg_cnt1_r1;
                        cfg_cnt2_r <= cfg_cnt2_r1;
                    end
                end
            endcase
        end
    end

    // (!) Not registered
    // (!) No empty check
    // always_comb begin
    //     pop_nzn = 1'b0;
    //     case (cfg_proc_r) inside
    //         PROC_MxV_SP : begin
    //             if (state == S_INIT) begin
    //                 pop_nzn = 1'b1;
    //             end
    //         end
    //         PROC_MTxV_SP : begin
    //             if (state == S_INIT) begin
    //                 pop_nzn = 1'b1;
    //             end
    //         end
    //         PROC_VXV_SP : begin
    //             if (state == S_INIT) begin
    //                 pop_nzn = 1'b0;
    //             end
    //         end
    //         default : begin
    //             if (state == S_INIT) begin
    //                 pop_nzn = 1'b0;
    //             end
    //         end
    //     endcase
    // end

    // (!) Not registered
    // (!) No empty check
    always_comb begin
        case (cfg_proc_r) inside
            PROC_MxV_SP, PROC_MTxV_SP : begin
                pop_nzi = f_O[0] && !empty_nzi; //
            end
            default : begin
                pop_nzi = 1'b0;
            end
        endcase
    end



    // Control Signals
    
    assign ready_i_eff = cmd_tready && ready_i_nzi;  // TODO
    // assign ready_i_eff = cmd_tready && ready_i_nzn;

    // always_comb begin
    //     case (cfg_proc_r) inside
    //         PROC_MxV_SP, PROC_MTxV_SP : begin
    //             ready_i_nzn = 1'b1;
    //         end
    //         PROC_VXV_SP : begin
    //             ready_i_nzn = 1'b1;
    //             if (valid_o_r[0] && (cnt0 == cfg_cnt0_r) && !f_cnt_o && empty_nzn)
    //                 ready_i_nzn = 1'b0;
    //         end
    //         default : begin 
    //             ready_i_nzn = 1'b1;
    //         end
    //     endcase
    // end

    always_comb begin
        case (cfg_proc_r) inside
            PROC_MxV_SP, PROC_MTxV_SP : begin
                ready_i_nzi = 1'b1;
                if (valid_o_r[0] && !f_cnt_o && empty_nzi)
                    ready_i_nzi = 1'b0;
            end
            default : begin 
                ready_i_nzi = 1'b1;
            end
        endcase
    end

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
        if (!rstn || !rstn_init) begin
            f_O[1] <= '0;
        end else if ((valid_o_r[0] || valid_o_r[1]) && ready_i_eff) begin
            f_O[1] <= f_O[0];
        end
    end
    
    
    
    // DRAM Data Counters
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
        if (!rstn || !rstn_init) begin
            f_cnt_o_r[1] <= '0;
        end else if ((valid_o_r[0] || valid_o_r[1]) && ready_i_eff) begin
            f_cnt_o_r[1] <= f_cnt_o_r[0];
        end
    end
    


    // DRAM Read Channel - read request signals
    always_comb begin
        case (cfg_proc_r)
            PROC_MxV_SP : begin
                cmd_tvalid_r0 = f_O[0];
                addr = dram_addr_r + (cfg_n1_r * cnt2 + din_nzi) * NUM_PE * DATA_BYTE;
                btt = 1 * NUM_PE * DATA_BYTE;
                cmd_tdata_r = (addr << 32) | AXI_DM_CMD_BASE | btt;
            end
            PROC_MTxV_SP : begin
                cmd_tvalid_r0 = f_O[0];
                addr = dram_addr_r + (cfg_n1_r * cnt1 + din_nzi) * NUM_PE * DATA_BYTE;
                btt = 1 * NUM_PE * DATA_BYTE;
                cmd_tdata_r = (addr << 32) | AXI_DM_CMD_BASE | btt;
            end
            PROC_VXV_SP : begin
                cmd_tvalid_r0 = f_O[0] && (cnt2 == 0) && (cnt1 == 0); // (?) set cfg_cnt2_r = cfg_cnt1_r = 0 instead?
                addr = dram_addr_r;
                btt = (cfg_cnt2_r + 1) * cfg_nt_r * NUM_PE * DATA_BYTE;
                cmd_tdata_r = (addr << 32) | AXI_DM_CMD_BASE | btt;
            end

            default : begin
                cmd_tvalid_r0 = 1'b0;
                addr = '0;
                btt = '0;
                cmd_tdata_r = '0;
            end
        endcase
    end
    
    always_ff @(posedge clk) begin
        if (!rstn || !rstn_init) begin
            cmd_tvalid_r1 <= '0;
            cmd_tdata <= '0;
        end else if (ready_i_eff) begin
            cmd_tvalid_r1 <= cmd_tvalid_r0;
            if (cmd_tvalid_r0) begin
                cmd_tdata <= cmd_tdata_r;
            end
        end
    end

    // Set cmd_tvalid to 0 when waiting for ready_i_nzi after a completed mm2s cmd transaction
    always_ff @(posedge clk) begin
        if (!rstn) begin
            cmd_tready_d <= 1'b0;
        end else begin
            if (ready_i_eff) begin
                cmd_tready_d <= 1'b0;
            end else begin
                cmd_tready_d <= cmd_tready_d || (cmd_tvalid && cmd_tready);
            end
        end
    end

    assign cmd_tvalid = cmd_tvalid_r1 && !cmd_tready_d;




endmodule
