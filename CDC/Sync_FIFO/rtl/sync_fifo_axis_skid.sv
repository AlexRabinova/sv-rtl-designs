module sync_fifo_axis_skid #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // Upstream AXI-Stream Slave Interface (CONNECTED TO TB)
    input  logic                  s_axis_tvalid,
    output logic                  s_axis_tready,
    input  logic [DATA_WIDTH-1:0] s_axis_tdata,

    // Downstream AXI-Stream Master Interface (CONNECTED TO TB)
    output logic                  m_axis_tvalid,
    input  logic                  m_axis_tready,
    output logic [DATA_WIDTH-1:0] m_axis_tdata
);

    // Internal Ingress Skid -> FIFO Core Signals
    logic                  fifo_wr_valid;
    logic                  fifo_wr_ready;
    logic [DATA_WIDTH-1:0] fifo_wr_data;

    // Internal FIFO Core -> Egress Skid Signals
    logic                  fifo_rd_valid;
    logic                  fifo_rd_ready;
    logic [DATA_WIDTH-1:0] fifo_rd_data;

    logic                  fifo_empty;
    logic                  fifo_full;

    // 1. Ingress Skid Buffer
    axis_skid_buffer_ingress #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_ingress_skid (
        .clk           (clk),
        .rst_n         (rst_n),
        .s_axis_tvalid (s_axis_tvalid),  // External Slave input
        .s_axis_tready (s_axis_tready),  // External Slave output
        .s_axis_tdata  (s_axis_tdata),   // External Slave input
        .to_fifo_tvalid(fifo_wr_valid),  // Internal to FIFO
        .to_fifo_tready(fifo_wr_ready),
        .to_fifo_tdata (fifo_wr_data)
    );

    assign fifo_wr_ready = !fifo_full;

    // 2. Core Sync FIFO
    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH     (DEPTH)
    ) u_core_fifo (
        .clk      (clk),
        .rst_n    (rst_n),
        .wr_en    (fifo_wr_valid && fifo_wr_ready),
        .full     (fifo_full),
        .din      (fifo_wr_data),
        .rd_en    (!fifo_empty && fifo_rd_ready),
        .empty    (fifo_empty),
        .valid_out(fifo_rd_valid),
        .dout     (fifo_rd_data)
    );

    // 3. Egress Skid Buffer
    axis_skid_buffer_egress #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_egress_skid (
        .clk             (clk),
        .rst_n           (rst_n),
        .from_fifo_tvalid(fifo_rd_valid), // Internal from FIFO
        .from_fifo_tready(fifo_rd_ready),
        .from_fifo_tdata (fifo_rd_data),
        .m_axis_tvalid   (m_axis_tvalid), // External Master output
        .m_axis_tready   (m_axis_tready), // External Master input
        .m_axis_tdata    (m_axis_tdata)   // External Master output
    );

endmodule