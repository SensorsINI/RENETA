
module DTV1_MACC #(
    parameter NUM_PE    = 16,    //16
    // BFP16
    parameter sig_width = 7,
    parameter exp_width = 8,
    parameter ieee_compliance = 1,
    parameter WEIGHT_BW = 16,
    parameter ACT_BW    = 16,
    parameter ACC_BW    = 16
) (
    input  logic                    clk,
    input  logic [0:NUM_PE-1]       en_mul,
    input  logic [0:NUM_PE-1]       en_add,
    input  logic                    en_acc,
    input  logic                    rstn,
    
    input  logic                    mul_mux_sel,
    input  logic                    add_mux0_sel,
    input  logic [1:0]              add_mux1_sel,
    input  logic [1:0]              acc_mux_sel,            // acc
    
    input  logic [ACT_BW-1:0]       din_act[0:NUM_PE-1],
    input  logic [WEIGHT_BW-1:0]    din_weight[0:NUM_PE-1],
    input  logic [ACC_BW-1:0]       din_buf[0:NUM_PE],      // acc

    output logic [ACC_BW-1:0]       dout_acc[0:NUM_PE],     // acc
    output logic [ACC_BW-1:0]       dout_mul[0:NUM_PE-1]
);
    
    logic [ACT_BW-1:0]      mul_mux_out[0:NUM_PE-1];
    logic [ACC_BW-1:0]      add_mux0_out[0:NUM_PE-1];
    logic [ACC_BW-1:0]      add_mux1_out[0:NUM_PE-1];
    logic [ACC_BW-1:0]      acc_mux_out;
    
    logic [ACT_BW-1:0]      mul_op0[0:NUM_PE-1];
    logic [WEIGHT_BW-1:0]   mul_op1[0:NUM_PE-1];
    logic [ACC_BW-1:0]      mul_out[0:NUM_PE-1];
    logic [ACC_BW-1:0]      mul_out_r1[0:NUM_PE-1];
    // logic [ACC_BW-1:0]      mul_out_r2[0:NUM_PE-1];
	logic [7:0]             mul_status[0:NUM_PE-1];
	logic [7:0]             mul_status_r1[0:NUM_PE-1];
	// logic [7:0]             mul_status_r2[0:NUM_PE-1];
    
    logic [ACC_BW-1:0]      add_op0[0:NUM_PE-1];
    logic [ACC_BW-1:0]      add_op1[0:NUM_PE-1];
    logic [ACC_BW-1:0]      add_out[0:NUM_PE-1];
    logic [ACC_BW-1:0]      add_out_r1[0:NUM_PE-1];
    // logic [ACC_BW-1:0]      add_out_r2[0:NUM_PE-1];
	logic [7:0]             add_status[0:NUM_PE-1];
	logic [7:0]             add_status_r1[0:NUM_PE-1];
	// logic [7:0]             add_status_r2[0:NUM_PE-1];
    
    logic [ACC_BW-1:0]      acc_op0;
    logic [ACC_BW-1:0]      acc_op1;
    logic [ACC_BW-1:0]      acc_out;
    logic [ACC_BW-1:0]      acc_out_r1;
    // logic [ACC_BW-1:0]      acc_out_r2;
	logic [7:0]             acc_status;
	logic [7:0]             acc_status_r1;
	// logic [7:0]             acc_status_r2;
    
    
    
    // MAC MUL_MUX
    always_comb begin
        case (mul_mux_sel)
            1'b0 : mul_mux_out = din_weight;
            1'b1 : mul_mux_out = din_buf[0:NUM_PE-1];
        endcase
    end
    
    // MAC ADD_MUX0
    always_comb begin
        case (add_mux0_sel)
            1'b0 : add_mux0_out = mul_out_r1;
            1'b1 : begin
                add_mux0_out[0] = '0;
                for (int pe_idx = 1; pe_idx < NUM_PE; pe_idx++) begin
                    add_mux0_out[pe_idx] = add_out_r1[pe_idx-1];
                end
            end
        endcase
    end
    
    // MAC ADD_MUX1
    always_comb begin
        case (add_mux1_sel)
            2'b00 : add_mux1_out = '{NUM_PE{'0}};
            2'b01 : add_mux1_out = din_buf[0:NUM_PE-1];
            2'b10 : add_mux1_out = add_out_r1;
            2'b11 : add_mux1_out = '{NUM_PE{'0}};
        endcase
    end
    
    // MAC Connections
    assign mul_op0 = din_act;
    assign mul_op1 = mul_mux_out;
    assign add_op0 = add_mux0_out;
    assign add_op1 = add_mux1_out;
    
    // // MAC Computations
    // always_comb begin
        // for (int pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
            // mul_out[pe_idx] = mul_op0[pe_idx] * mul_op1[pe_idx];
            // add_out[pe_idx] = add_op0[pe_idx] + add_op1[pe_idx];
        // end
    // end
    
    generate
        for (genvar pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
            DW_fp_mult #(
                sig_width,
                exp_width,
                ieee_compliance
            ) fp_mult (
                .a(mul_op0[pe_idx]),
                .b(mul_op1[pe_idx]),
                .rnd(3'b000),
                .z(mul_out[pe_idx]),
                .status(mul_status[pe_idx])
            );

            always_ff @(posedge clk or negedge rstn) begin
                if (!rstn) begin
                    mul_out_r1[pe_idx] <= '0;
                    // mul_out_r2[pe_idx] <= '0;
                    mul_status_r1[pe_idx] <= '0;
                    // mul_status_r2[pe_idx] <= '0;
                end else if (en_mul[pe_idx]) begin
                    mul_out_r1[pe_idx] <= mul_out[pe_idx];
                    // mul_out_r2[pe_idx] <= mul_out_r1[pe_idx];
                    mul_status_r1[pe_idx] <= mul_status[pe_idx];
                    // mul_status_r2[pe_idx] <= mul_status_r1[pe_idx];
                end
            end
        end
    endgenerate
            
    generate
        for (genvar pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
            DW_fp_add #(
                sig_width,
                exp_width,
                ieee_compliance
            ) fp_add (
                .a(add_op0[pe_idx]),
                .b(add_op1[pe_idx]),
                .rnd(3'b000),
                .z(add_out[pe_idx]),
                .status(add_status[pe_idx])
            );
            
            always_ff @(posedge clk or negedge rstn) begin
                if (!rstn) begin
                    add_out_r1[pe_idx] <= '0;
                    // add_out_r2[pe_idx] <= '0;
                    add_status_r1[pe_idx] <= '0;
                    // add_status_r2[pe_idx] <= '0;
                end else if (en_add[pe_idx]) begin
                    add_out_r1[pe_idx] <= add_out[pe_idx];
                    // add_out_r2[pe_idx] <= add_out_r1[pe_idx];
                    add_status_r1[pe_idx] <= add_status[pe_idx];
                    // add_status_r2[pe_idx] <= add_status_r1[pe_idx];
                end
            end
        end
    endgenerate
    


    // ACC_MUX
    always_comb begin
        case (acc_mux_sel)
            2'b00 : acc_mux_out = '0;
            2'b01 : acc_mux_out = din_buf[NUM_PE];
            2'b10 : acc_mux_out = acc_out_r1;
            2'b11 : acc_mux_out = '0;
        endcase
    end
    
    // ACC Connections
    assign acc_op0 = add_out_r1[NUM_PE-1];
    assign acc_op1 = acc_mux_out;

    // // ACC Computation
    // always_comb begin
        // acc_out = acc_op0 + acc_op1;
    // end
    
    DW_fp_add #(
        sig_width,
        exp_width,
        ieee_compliance
    ) fp_add_acc (
        .a(acc_op0),
        .b(acc_op1),
        .rnd(3'b000),
        .z(acc_out),
        .status(acc_status)
    );
    
    // ACC Register
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            acc_out_r1 <= '0;
            // acc_out_r2 <= '0;
            acc_status_r1 <= '0;
            // acc_status_r2 <= '0;
        end else if (en_acc) begin
            acc_out_r1 <= acc_out;
            // acc_out_r2 <= acc_out_r1;
            acc_status_r1 <= acc_status;
            // acc_status_r2 <= acc_status_r1;
        end
    end

    // Output Connections
    always_comb begin
        for (int pe_idx = 0; pe_idx < NUM_PE; pe_idx++) begin
            dout_acc[pe_idx] = add_out_r1[pe_idx];
            dout_mul[pe_idx] = mul_out_r1[pe_idx];
        end
        dout_acc[NUM_PE] = acc_out_r1;
    end

endmodule


