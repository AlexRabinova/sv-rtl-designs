module fifo_controller #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16,
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                  clk,
    input  logic                  rst_n,
    output logic [ADDR_WIDTH-1 : 0] w_addr,r_addr,
    input  logic                  wr,rd,
    output logic                   full,empty
);

    logic [ADDR_WIDTH-1:0] wr_ptr,next_wr_ptr;
    logic [ADDR_WIDTH-1:0] rd_ptr,next_rd_ptr;

    logic                  next_empty;
    logic                  next_full;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
        begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            full <= 0;
            empty <= 1;
        end
        else begin
            wr_ptr <= next_wr_ptr;
            rd_ptr <= next_rd_ptr;
            full <= next_full;
            empty <= next_empty;
        end
    end

    always_comb begin
        next_wr_ptr = wr_ptr;
        next_rd_ptr = rd_ptr;
        next_full = full;
        next_empty = empty;

        case ({wr,rd})
            2'b01: //read
            begin
                if (!empty) begin
                    next_rd_ptr = rd_ptr + 1;
                    next_full = 1'b0;
                    if (next_rd_ptr == wr_ptr) begin
                        next_empty = 1'b1;
                    end 
                end
            end

            2'10: //write
            begin
                if (!full) begin
                    next_wr_ptr = wr_ptr + 1;
                    next_empty = 1'b0;
                    if (next_wr_ptr == rd_ptr) begin
                        next_full = 1'b1;
                    end
                end
            end

            2'b11: //write and read
            begin
                if (empty) begin
                    next_wr_ptr = wr_ptr;
                    next_rd_ptr = rd_ptr;
                end else begin
                    next_wr_ptr = wr_ptr + 1;
                    next_rd_ptr = rd_ptr + 1;
                end
            end

            default: //nothing
        endcase
    end

    assign w_addr = wr_ptr;
    assign r_addr = rd_ptr;

endmodule