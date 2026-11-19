
module fwft_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 3
)(
    input  logic                   clk,
    input  logic                   rst_n,
    

    input  logic                   rd_en,
    output logic [DATA_WIDTH-1:0]  dout,
    output logic                   empty,
    

    input  logic                   wr_en,
    input  logic [DATA_WIDTH-1:0]  din,
    output logic                   full
);


    typedef enum logic [1:0] {
        ST_EMPTY  = 2'b00,  // 0 items in system
        ST_SINGLE = 2'b01,  // 1 item in output register
        ST_STREAM = 2'b10   // >= 2 items (output reg + backing FIFO)
    } state_t;

    state_t current_state, next_state;


    logic                   fifo_wr_en;
    logic [DATA_WIDTH-1:0]  fifo_din;
    logic                   fifo_rd_en;
    logic [DATA_WIDTH-1:0]  fifo_dout;
    logic                   fifo_empty;
    logic                   fifo_full;

    // Output holding register
    logic [DATA_WIDTH-1:0]  dout_reg;

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_std_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(fifo_wr_en),
        .din(fifo_din),
        .rd_en(fifo_rd_en),
        .dout(fifo_dout),
        .empty(fifo_empty),
        .full(fifo_full)
    );


    assign dout  = dout_reg;
    assign empty = (current_state == ST_EMPTY);
    assign full  = fifo_full;


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= ST_EMPTY;
            dout_reg      <= '0;
        end else begin
            current_state <= next_state;
        end
    end


    always @(*) begin
        next_state = current_state;
        fifo_wr_en = 1'b0;
        fifo_rd_en = 1'b0;
        fifo_din   = din;

        case (current_state)
            ST_EMPTY: begin
                if (wr_en) begin
                    next_state = ST_SINGLE; // Landed directly in output reg
                end
            end

            ST_SINGLE: begin
                case ({rd_en, wr_en})
                    2'b10: begin // Read only
                        next_state = ST_EMPTY;
                    end
                    2'b01: begin // Write only (overflows into backing fifo)
                        fifo_wr_en = 1'b1;
                        next_state = ST_STREAM;
                    end
                    2'b11: begin // Simultaneous read & write (bypasses backing fifo)
                        next_state = ST_SINGLE;
                    end
                    default: ;
                endcase
            end

            ST_STREAM: begin
                case ({rd_en, wr_en})
                    2'b10: begin // Read only
                        fifo_rd_en = 1'b1;
                        if (fifo_empty) begin
                            next_state = ST_SINGLE; // Backing FIFO drained
                        end
                    end
                    2'b01: begin // Write only
                        fifo_wr_en = 1'b1;
                    end
                    2'b11: begin // Read & Write simultaneously
                        fifo_rd_en = 1'b1;
                        fifo_wr_en = 1'b1;
                    end
                    default: ;
                endcase
            end

            default: next_state = ST_EMPTY;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        case (current_state)
            ST_EMPTY: begin
                if (wr_en) begin
                    // BYPASS: Write directly to output reg for 0-cycle availability
                    dout_reg <= din;
                end
            end

            ST_SINGLE: begin
                case ({rd_en, wr_en})
                    2'b10: begin // Read only -> goes empty, clear reg
                        dout_reg <= '0;
                    end
                    2'b01: begin // Write only -> item stays in reg, new goes to fifo
                        // dout_reg remains as is
                    end
                    2'b11: begin // Simultaneous read & write -> new write bypasses to reg
                        dout_reg <= din;
                    end
                    default: ;
                endcase
            end

            ST_STREAM: begin
                if (rd_en) begin
                    // Pull next item from backing FIFO into output register
                    dout_reg <= fifo_dout;
                end
            end
        endcase
    end

endmodule


