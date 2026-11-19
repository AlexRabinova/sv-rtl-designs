module axis_skid_buffer_egress #(
    parameter int DATA_WIDTH = 8
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // Upstream FIFO Core Interface
    input  logic                  from_fifo_tvalid,
    output logic                  from_fifo_tready,
    input  logic [DATA_WIDTH-1:0] from_fifo_tdata,

    // Downstream AXI-Stream Master Interface
    output logic                  m_axis_tvalid,
    input  logic                  m_axis_tready,
    output logic [DATA_WIDTH-1:0] m_axis_tdata
);

    logic [DATA_WIDTH-1:0] primary_reg;
    logic [DATA_WIDTH-1:0] skid_reg;
    logic                  primary_valid;
    logic                  skid_valid;

    assign from_fifo_tready = !skid_valid;
    
    // Combinational pass-through when primary pipeline is empty
    assign m_axis_tvalid = primary_valid || from_fifo_tvalid;
    assign m_axis_tdata  = skid_valid    ? skid_reg : 
                           primary_valid ? primary_reg : from_fifo_tdata;

    wire in_fire  = from_fifo_tvalid && from_fifo_tready;
    wire out_fire = m_axis_tvalid && m_axis_tready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            primary_reg   <= '0;
            skid_reg      <= '0;
            primary_valid <= 1'b0;
            skid_valid    <= 1'b0;
        end else begin
            if (in_fire && !out_fire && primary_valid) begin
                skid_reg   <= from_fifo_tdata;
                skid_valid <= 1'b1;
            end 
            else if (out_fire && skid_valid) begin
                primary_reg <= skid_reg;
                if (in_fire) begin
                    skid_reg   <= from_fifo_tdata;
                    skid_valid <= 1'b1;
                end else begin
                    skid_valid <= 1'b0;
                end
            end 
            else if (in_fire && (!primary_valid || out_fire)) begin
                primary_reg   <= from_fifo_tdata;
                primary_valid <= 1'b1;
            end 
            else if (out_fire && !skid_valid) begin
                primary_valid <= 1'b0;
            end
        end
    end

endmodule