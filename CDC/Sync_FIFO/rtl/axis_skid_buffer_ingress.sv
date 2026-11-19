module axis_skid_buffer_ingress #(
    parameter int DATA_WIDTH = 8
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // Upstream AXI-Stream Slave Interface
    input  logic                  s_axis_tvalid,
    output logic                  s_axis_tready,
    input  logic [DATA_WIDTH-1:0] s_axis_tdata,

    // Downstream FIFO Core Interface
    output logic                  to_fifo_tvalid,
    input  logic                  to_fifo_tready,
    output logic [DATA_WIDTH-1:0] to_fifo_tdata
);

    logic [DATA_WIDTH-1:0] skid_reg;
    logic                  skid_valid;

    wire s_axis_fire = s_axis_tvalid && s_axis_tready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axis_tready <= 1'b1;
            skid_valid    <= 1'b0;
            skid_reg      <= '0;
        end else begin
            if (s_axis_fire && !to_fifo_tready) begin
                // Core is full: buffer incoming beat and de-assert ready
                skid_reg      <= s_axis_tdata;
                skid_valid    <= 1'b1;
                s_axis_tready <= 1'b0;
            end else if (to_fifo_tready && skid_valid) begin
                // Core cleared room: drain skid buffer and re-assert ready
                skid_valid    <= 1'b0;
                s_axis_tready <= 1'b1;
            end
        end
    end

    assign to_fifo_tvalid = skid_valid || s_axis_tvalid;
    assign to_fifo_tdata  = skid_valid  ? skid_reg : s_axis_tdata;

endmodule