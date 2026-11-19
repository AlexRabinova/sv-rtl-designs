module fwft_fifo_top #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 8
)(
    input  wire                  clk,
    input  wire                  rst,

    // Write Port (Standard FIFO Interface)
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] din,
    output wire                  full,

    // FWFT Ready/Valid Read Port
    output wire                  valid,
    input  wire                  ready,
    output wire [DATA_WIDTH-1:0] dout
);

    // -------------------------------------------------------------------------
    // Internal Signals & Standard FIFO Instantiation
    // -------------------------------------------------------------------------
    wire                  fifo_rd_en;
    wire                  fifo_empty;
    wire [DATA_WIDTH-1:0] fifo_dout;
    reg                   fifo_rd_pending;

    std_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) u_std_fifo (
        .clk   (clk),
        .rst   (rst),
        .wr_en (wr_en),
        .din   (din),
        .full  (full),
        .rd_en (fifo_rd_en),
        .dout  (fifo_dout),
        .empty (fifo_empty)
    );

    // -------------------------------------------------------------------------
    // Data Registers
    // -------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] dout_reg;
    reg [DATA_WIDTH-1:0] secondary_reg;

    // Output drive directly from primary register
    assign dout = dout_reg;

    // -------------------------------------------------------------------------
    // FSM State Encoding
    // -------------------------------------------------------------------------
    localparam [1:0] STATE_EMPTY  = 2'b00;
    localparam [1:0] STATE_SINGLE = 2'b01;
    localparam [1:0] STATE_FULL   = 2'b10;

    reg [1:0] state, next_state;

    // Output valid signal is true in SINGLE and FULL states
    assign valid = (state != STATE_EMPTY);

    // Read from standard FIFO whenever the skid buffer has space for another word
    assign fifo_rd_en = !fifo_empty && (next_state != STATE_FULL) && !fifo_rd_pending;

    // -------------------------------------------------------------------------
    // Track RAM Read In-Flight Status (1 Cycle RAM Latency)
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            fifo_rd_pending <= 1'b0;
        end else begin
            if (fifo_rd_en)
                fifo_rd_pending <= 1'b1;
            else if (fifo_rd_pending)
                fifo_rd_pending <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // FSM Next-State Combinational Logic
    // -------------------------------------------------------------------------
    always @(*) begin
        next_state = state;

        case (state)
            STATE_EMPTY: begin
                // Transition to SINGLE when RAM data arrives
                if (fifo_rd_pending) begin
                    next_state = STATE_SINGLE;
                end
            end

            STATE_SINGLE: begin
                if (ready && !fifo_rd_pending) begin
                    // Downstream consumed data and no incoming RAM data
                    next_state = STATE_EMPTY;
                end else if (!ready && fifo_rd_pending) begin
                    // Downstream stalled and incoming RAM data arrives -> skid into secondary
                    next_state = STATE_FULL;
                end
                // If (ready && fifo_rd_pending), downstream consumes and RAM refills -> Stay in SINGLE
            end

            STATE_FULL: begin
                if (ready) begin
                    // Downstream consumed output word -> shift secondary into primary
                    next_state = STATE_SINGLE;
                end
            end

            default: next_state = STATE_EMPTY;
        endcase
    end

    // -------------------------------------------------------------------------
    // FSM State Sequential Registers & Datapath Control
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state         <= STATE_EMPTY;
            dout_reg      <= '0;
            secondary_reg <= '0;
        end else begin
            state <= next_state;

            case (state)
                STATE_EMPTY: begin
                    if (fifo_rd_pending) begin
                        dout_reg <= fifo_dout;
                    end
                end

                STATE_SINGLE: begin
                    if (ready && fifo_rd_pending) begin
                        // Pass-through: Consumer took old word, store incoming RAM word
                        dout_reg <= fifo_dout;
                    end else if (!ready && fifo_rd_pending) begin
                        // Skid condition: Consumer stalled, store incoming RAM word in secondary
                        secondary_reg <= fifo_dout;
                    end
                end

                STATE_FULL: begin
                    if (ready) begin
                        // Drain condition: Move secondary data into output register
                        dout_reg <= secondary_reg;
                    end
                end
            endcase
        end
    end

endmodule