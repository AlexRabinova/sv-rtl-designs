module pulse_synchronizer #(
    parameter int SYNC_STAGES = 2
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
    // 2. Clock Domain Crossing: Multi-stage Synchronizer Chain
    // -------------------------------------------------------------
    logic [SYNC_STAGES-1:0] sync_chain;

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            sync_chain <= '0;
        end else begin
            sync_chain <= {sync_chain[SYNC_STAGES-2:0], toggle_src};
        end
    end

    // -------------------------------------------------------------
    // 3. Destination Domain: Edge Detection (Level to Pulse)
    // -------------------------------------------------------------
    logic toggle_sync_q;

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            toggle_sync_q <= 1'b0;
        end else begin
            toggle_sync_q <= sync_chain[SYNC_STAGES-1];
        end
    end

    // Detect any transition (rising or falling edge) on the synchronized toggle signal
    assign pulse_out = sync_chain[SYNC_STAGES-1] ^ toggle_sync_q;

endmodule