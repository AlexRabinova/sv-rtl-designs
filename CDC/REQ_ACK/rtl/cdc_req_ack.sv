module cdc_req_ack #(
    parameter int DATA_WIDTH = 8
)(
    // Source Clock Domain
    input  logic                   clk_src,
    input  logic                   rst_src_n,
    input  logic                   valid_src_i,   // Request pulse to initiate transfer
    input  logic [DATA_WIDTH-1:0]  data_src_i,    // Data or count value to transfer
    output logic                   ready_src_o,   // High when ready for a new request

    // Destination Clock Domain
    input  logic                   clk_dst,
    input  logic                   rst_dst_n,
    output logic                   valid_dst_o,   // Single-cycle pulse when new data arrives
    output logic [DATA_WIDTH-1:0]  data_dst_o     // Synchronized data in destination domain
);

    // =================================================================
    // 1. Source Domain: Control Logic & Request Toggle
    // =================================================================
    logic req_toggle_src;
    logic ack_sync_ff1, ack_sync_ff2, ack_sync_ff2_d;
    logic ack_received;
    logic busy;
    logic [DATA_WIDTH-1:0] data_latched;

    // Detect ACK transition from destination domain (2-stage sync)
    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            ack_sync_ff1   <= 1'b0;
            ack_sync_ff2   <= 1'b0;
            ack_sync_ff2_d <= 1'b0;
        end else begin
            ack_sync_ff1   <= ack_toggle_dst;
            ack_sync_ff2   <= ack_sync_ff1;
            ack_sync_ff2_d <= ack_sync_ff2;
        end
    end

    assign ack_received = ack_sync_ff2 ^ ack_sync_ff2_d;
    assign ready_src_o  = !busy;

    // Latch data and manage busy/request state
    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            req_toggle_src <= 1'b0;
            busy           <= 1'b0;
            data_latched   <= '0;
        end else begin
            if (valid_src_i && !busy) begin
                data_latched   <= data_src_i;   // Hold data stable during handshake
                req_toggle_src <= ~req_toggle_src; // Toggle request signal
                busy           <= 1'b1;
            end else if (ack_received) begin
                busy           <= 1'b0;          // Handshake complete, accept next request
            end
        end
    end

    // =================================================================
    // 2. CDC Crossing: Synchronize Request to Destination Domain
    // =================================================================
    logic req_sync_ff1, req_sync_ff2, req_sync_ff2_d;
    logic req_pulse_dst;

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            req_sync_ff1   <= 1'b0;
            req_sync_ff2   <= 1'b0;
            req_sync_ff2_d <= 1'b0;
        end else begin
            req_sync_ff1   <= req_toggle_src;
            req_sync_ff2   <= req_sync_ff1;
            req_sync_ff2_d <= req_sync_ff2;
        end
    end

    assign req_pulse_dst = req_sync_ff2 ^ req_sync_ff2_d;

    // =================================================================
    // 3. Destination Domain: Acknowledge Toggle & Data Capture
    // =================================================================
    logic ack_toggle_dst;

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            ack_toggle_dst <= 1'b0;
            valid_dst_o    <= 1'b0;
            data_dst_o     <= '0;
        end else begin
            if (req_pulse_dst) begin
                ack_toggle_dst <= ~ack_toggle_dst; // Toggle ACK back to source
                valid_dst_o    <= 1'b1;           // Strobe valid output
                data_dst_o     <= data_latched;    // Safe because data is held stable across bus
            end else begin
                valid_dst_o    <= 1'b0;
            end
        end
    end

endmodule