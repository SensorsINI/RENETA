
module axis_broadcast #(
///////////////////////////////////////////////////////////////////////////////
// Parameter Definitions
///////////////////////////////////////////////////////////////////////////////
    parameter integer C_AXIS_TDATA_WIDTH        = 16,
    parameter integer C_NUM_MI_SLOTS            = 4
) (
///////////////////////////////////////////////////////////////////////////////
// Port Declarations
///////////////////////////////////////////////////////////////////////////////
    // System Signals
    input  logic                                aclk,
    input  logic                                aresetn,

    // Slave side
    input  logic                                s_axis_tvalid,
    output logic                                s_axis_tready,
    // input  logic [C_AXIS_TDATA_WIDTH-1:0]       s_axis_tdata,

    // Master side
    output logic                                m_axis_tvalid [C_NUM_MI_SLOTS],
    input  logic                                m_axis_tready [C_NUM_MI_SLOTS]
    // output logic [C_AXIS_TDATA_WIDTH-1:0]       m_axis_tdata  [C_NUM_MI_SLOTS]
);

////////////////////////////////////////////////////////////////////////////////
// Wires/Reg declarations
////////////////////////////////////////////////////////////////////////////////
    logic                                       s_axis_tvalid_i;
    logic [C_NUM_MI_SLOTS-1:0]                  m_axis_tvalid_pk;   // Packed
    logic [C_NUM_MI_SLOTS-1:0]                  m_axis_tready_pk;   // Packed

////////////////////////////////////////////////////////////////////////////////
// BEGIN RTL
////////////////////////////////////////////////////////////////////////////////
    logic [C_NUM_MI_SLOTS-1:0]                  m_ready_d;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            m_ready_d <= {C_NUM_MI_SLOTS{1'b0}};
        end else begin
            if (s_axis_tready) begin
                m_ready_d <= {C_NUM_MI_SLOTS{1'b0}};
            end else begin
                m_ready_d <= m_ready_d | (m_axis_tvalid_pk & m_axis_tready_pk);
            end
        end
    end

    assign s_axis_tready = (&(m_ready_d | m_axis_tready_pk) & aresetn);
    assign s_axis_tvalid_i = (s_axis_tvalid & aresetn);
    assign m_axis_tvalid_pk = {C_NUM_MI_SLOTS{s_axis_tvalid_i}} & ~m_ready_d;

    always_comb begin
        for (int idx = 0; idx < C_NUM_MI_SLOTS; idx++) begin
            m_axis_tready_pk[idx] = m_axis_tready[idx];
            m_axis_tvalid[idx] = m_axis_tvalid_pk[idx];
            // m_axis_tdata[idx] = s_axis_tdata;
        end
    end

endmodule // axis_broadcast
