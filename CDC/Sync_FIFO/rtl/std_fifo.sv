module std_fifo #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 8,
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input  wire                  clk,
    input  wire                  rst,

    // Write Interface
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] din,
    output wire                  full,

    // Read Interface (Standard 1-cycle latency)
    input  wire                  rd_en,
    output reg  [DATA_WIDTH-1:0] dout,
    output wire                  empty
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH:0]   w_ptr;
    reg [ADDR_WIDTH:0]   r_ptr;

    assign full  = (w_ptr[ADDR_WIDTH-1:0] == r_ptr[ADDR_WIDTH-1:0]) && 
                   (w_ptr[ADDR_WIDTH]   != r_ptr[ADDR_WIDTH]);
    assign empty = (w_ptr == r_ptr);

    // Write Logic
    always @(posedge clk) begin
        if (rst) begin
            w_ptr <= '0;
        end else if (wr_en && !full) begin
            mem[w_ptr[ADDR_WIDTH-1:0]] <= din;
            w_ptr <= w_ptr + 1'b1;
        end
    end

    // Read Logic (Standard: output updates 1 cycle AFTER rd_en)
    always @(posedge clk) begin
        if (rst) begin
            r_ptr <= '0;
            dout  <= '0;
        end else if (rd_en && !empty) begin
            dout  <= mem[r_ptr[ADDR_WIDTH-1:0]];
            r_ptr <= r_ptr + 1'b1;
        end
    end

endmodule