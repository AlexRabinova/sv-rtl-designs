module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 4 // Must be a power of 2 (2^ADDR_WIDTH)
    //parameter ALMOST_FULL_THRESH  = 12,
    //parameter ALMOST_EMPTY_THRESH = 4
)(
    input  logic                  clk,
    input  logic                  rst_n,
    
    // Write Interface
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] din,
    output logic                  full,
   // output logic almost_full,
    
    // Read Interface
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] dout,
    output logic                  valid_out,
    output logic                  empty
   // output logic almost_empty
);
    localparam ADDR_WIDTH = $clog2(DEPTH);

    // Storage element
    logic [DATA_WIDTH-1:0] mem [DEPTH-1:0]; // SRAM(6T) or REGISTER FILE(FF's)

    // Pointers are (ADDR_WIDTH + 1) bits wide
    logic [ADDR_WIDTH:0] wr_ptr;
    logic [ADDR_WIDTH:0] rd_ptr;

    //logic [ADDR_WIDTH:0] occupancy;

    // Direct flag assignments
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]) && 
                   (wr_ptr[ADDR_WIDTH]     != rd_ptr[ADDR_WIDTH]);

    //assign occupancy    = wr_ptr - rd_ptr;
    //assign almost_full  = (occupancy >= ALMOST_FULL_THRESH);
    //assign almost_empty = (occupancy <= ALMOST_EMPTY_THRESH);

    // Combinational read out (Register-based FIFO behavior - Zero latency)
    //assign dout  = mem[rd_ptr[ADDR_WIDTH-1:0]];

    // BRAM-friendly Read Logic (1-cycle read latency)
    // BRAM-friendly Read Logic (No reset on memory output)
    always_ff @(posedge clk) begin
        if (rd_en && !empty) begin
            dout <= mem[rd_ptr[ADDR_WIDTH-1:0]];
        end
    end

    // Control logic explicitly handling reset
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr    <= '0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= rd_en && !empty;
            if (rd_en && !empty) begin
                rd_ptr <= rd_ptr + 1'b1;
            end
        end
    end

    // Write Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
        end else if (wr_en &&  !full) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= din;
            wr_ptr                      <= wr_ptr + 1'b1;
        end
    end


endmodule