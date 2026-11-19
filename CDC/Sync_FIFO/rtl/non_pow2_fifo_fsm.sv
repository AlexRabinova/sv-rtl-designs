module non_pow2_fifo #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 10,
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Write Interface
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] din,
    output wire                  full,

    // Read Interface
    input  wire                  rd_en,
    output reg  [DATA_WIDTH-1:0] dout,
    output wire                  empty,
    output logic                 error_flag
);

    // Memory Storage
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers & Counter
    reg [ADDR_WIDTH-1:0] w_ptr, r_ptr;
    reg [ADDR_WIDTH:0]   count;

    // Operation Qualifiers
    // Allow write when full ONLY IF reading simultaneously (frees 1 slot)
    wire valid_write = wr_en && (!full  || rd_en);
    wire valid_read  = rd_en && (!empty);

    // Status Flags
    assign full       = (count == DEPTH);
    assign empty      = (count == 0);
    assign error_flag = (wr_en && full && !rd_en) || (rd_en && empty);

    //--------------------------------------------------------------------------
    // 1. Memory Write Block
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (valid_write) begin
            mem[w_ptr] <= din;
        end
    end

    //--------------------------------------------------------------------------
    // 2. Memory Read Block
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (valid_read) begin
            dout <= mem[r_ptr];
        end
    end

    //--------------------------------------------------------------------------
    // 3. Pointer Update Block (w_ptr & r_ptr with Non-Power-of-2 Rollover)
    //--------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_ptr <= '0;
            r_ptr <= '0;
        end else begin
            // Write Pointer Rollover Logic
            if (valid_write) begin
                w_ptr <= (w_ptr == DEPTH - 1) ? '0 : w_ptr + 1'b1;
            end

            // Read Pointer Rollover Logic
            if (valid_read) begin
                r_ptr <= (r_ptr == DEPTH - 1) ? '0 : r_ptr + 1'b1;
            end
        end
    end

    //--------------------------------------------------------------------------
    // 4. Occupancy Tracking Block (Count Register)
    //--------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= '0;
        end else begin
            case ({valid_write, valid_read})
                2'b10:   count <= count + 1'b1; // Push only
                2'b01:   count <= count - 1'b1; // Pop only
                default: count <= count;        // Concurrent read/write or Idle
            endcase
        end
    end

endmodule