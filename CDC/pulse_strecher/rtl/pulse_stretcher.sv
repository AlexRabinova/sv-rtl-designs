module pulse_stretcher #(
    parameter int STRETCH_CYCLES = 3
) (
    // Source Domain
    input  logic clk_src,
    input  logic rst_src_n,
    input  logic pulse_in,

    // Destination Domain
    input  logic clk_dst,
    input  logic rst_dst_n,
    output logic pulse_out
);

    // -------------------------------------------------------------
    // 1. Source Domain: Toggle on input pulse
    // -------------------------------------------------------------
    logic toggle_src;

    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            toggle_src <= 1'b0;
        end else if (pulse_in) begin
            toggle_src <= ~toggle_src;
        end
    end

    // -------------------------------------------------------------
    // 2. Destination Domain: Multi-stage Synchronizer (2FF minimum)
    // -------------------------------------------------------------
    logic [1:0] sync_chain;

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            sync_chain <= 2'b00;
        end else begin
            sync_chain <= {sync_chain[0], toggle_src};
        end
    end

    // -------------------------------------------------------------
    // 3. Destination Domain: Edge Detection & Counter for Stretching
    // -------------------------------------------------------------
    logic toggle_sync_q;
    logic edge_detected;
    
    // Calculate counter bit width based on stretch cycles parameter
    localparam int CNT_WIDTH = $clog2(STRETCH_CYCLES + 1);
    logic [CNT_WIDTH-1:0] stretch_cnt;
    logic stretching;

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            toggle_sync_q <= 1'b0;
        end else begin
            toggle_sync_q <= sync_chain[1];
        end
    end

    // Detect any edge (rising or falling) of the toggled signal
    assign edge_detected = (sync_chain[1] ^ toggle_sync_q);

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            stretch_cnt <= '0;
            stretching  <= 1'b0;
        end else begin
            if (edge_detected && !stretching) begin
                stretch_cnt <= STRETCH_CYCLES - 1;
                stretching  <= 1'b1;
            end else if (stretching) begin
                if (stretch_cnt == '0) begin
                    stretching <= 1'b0;
                end else begin
                    stretch_cnt <= stretch_cnt - 1'b1;
                end
            end
        end
    end

    // Output is high whenever we are stretching or an edge just arrived
    assign pulse_out = stretching || edge_detected;

endmodule