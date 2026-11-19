// Tx module maintains credit tracking and outputs data when credits > 0
module credit_tx #(
    parameter int DATA_WIDTH  = 32,
    parameter int MAX_CREDITS = 8,
    parameter int CREDIT_BITS = $clog2(MAX_CREDITS + 1)
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // Interface with upstream producer
    input  logic [DATA_WIDTH-1:0] tx_data_in,
    input  logic                  tx_valid_in,
    output logic                  tx_ready_out, // Upstream ready when credits available

    // Link interface to Rx
    output logic [DATA_WIDTH-1:0] link_data,
    output logic                  link_valid,
    input  logic                  link_credit_ret // Credit returned from Rx
);

    logic [CREDIT_BITS-1:0] credit_cnt;

    // Ready to accept data from upstream if we have at least one credit
    assign tx_ready_out = (credit_cnt > 0);

    // Send data on link when upstream valid and we have credit
    assign link_valid   = tx_valid_in && tx_ready_out;
    assign link_data    = tx_data_in;

    // Credit Counter Management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            credit_cnt <= MAX_CREDITS[CREDIT_BITS-1:0]; // Initialize with total buffer capacity
        end else begin
            case ({link_valid, link_credit_ret})
                2'b10: credit_cnt <= credit_cnt - 1'b1; // Sent data, no credit returned
                2'b01: credit_cnt <= credit_cnt + 1'b1; // Did not send data, credit returned
                2'b11: credit_cnt <= credit_cnt;        // Sent data AND credit returned (net change = 0)
                2'b00: credit_cnt <= credit_cnt;        // Idle
            endcase
        end
    end

endmodule

// Rx module receives incoming link data into a FIFO and returns credits upon read pop
module credit_rx #(
    parameter int DATA_WIDTH = 32,
    parameter int FIFO_DEPTH = 8
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // Link interface from Tx
    input  logic [DATA_WIDTH-1:0] link_data,
    input  logic                  link_valid,
    output logic                  link_credit_ret,

    // Downstream consumer interface
    output logic [DATA_WIDTH-1:0] rx_data_out,
    output logic                  rx_valid_out,
    input  logic                  rx_pop_in
);

    // Synchronous FIFO Storage
    logic [DATA_WIDTH-1:0] fifo [FIFO_DEPTH];
    logic [$clog2(FIFO_DEPTH)-1:0] wr_ptr, rd_ptr;
    logic [$clog2(FIFO_DEPTH):0]   fifo_count;

    // FIFO status flags
    assign rx_valid_out = (fifo_count > 0);
    assign rx_data_out  = fifo[rd_ptr];

    // Credit is returned whenever a word is popped by the downstream consumer
    assign link_credit_ret = rx_pop_in && rx_valid_out;

    // FIFO Pointers & Counter Logic
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
            wr_ptr     <= '0;
            rd_ptr     <= '0;
            fifo_count <= '0;
        end else begin
            // Write (Push) operation from link
            if (link_valid) begin
                fifo[wr_ptr] <= link_data;
                wr_ptr       <= wr_ptr + 1'b1;
            end

            // Read (Pop) operation from consumer
            if (link_credit_ret) begin
                rd_ptr <= rd_ptr + 1'b1;
            end

            // FIFO count updating
            case ({link_valid, link_credit_ret})
                2'b10: fifo_count <= fifo_count + 1'b1;
                2'b01: fifo_count <= fifo_count - 1'b1;
                2'b11: fifo_count <= fifo_count;
                2'b00: fifo_count <= fifo_count;
            endcase
        end
    end


endmodule