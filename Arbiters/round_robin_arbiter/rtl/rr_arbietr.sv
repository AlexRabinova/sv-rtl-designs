// Code your design here
module rr_arbiter #(
    parameter int WIDTH = 4
)(
    input  logic               clk,
    input  logic               rst_n,
    input  logic [WIDTH-1:0]   req,     // Request vector
    input  logic [WIDTH-1:0]   mask,    // Qualification/disable mask (all 1's if unmasked)
    output logic [WIDTH-1:0]   grant    // One-hot grant output
);

    // Internal signals
    logic [WIDTH-1:0] ptr_oh;
    logic [WIDTH-1:0] mask_hi;
    logic [WIDTH-1:0] req_active;
    logic [WIDTH-1:0] req_hi, req_lo;
    logic [WIDTH-1:0] grant_hi, grant_lo;
    logic             any_hi;

    // 1. Qualify requests with the external mask
    assign req_active = req & mask;

    // 2. Generate high-zone priority mask using the two's complement inversion trick
    assign mask_hi = ~(ptr_oh - 1'b1);

    // 3. Partition requests into High and Low zones
    assign req_hi = req_active & mask_hi;
    assign req_lo = req_active & ~mask_hi;

    // 4. Parallel LSB extraction (x & -x) for fixed-priority evaluation
    assign grant_hi = req_hi & (-req_hi);
    assign grant_lo = req_lo & (-req_lo);

    // 5. Final grant selection multiplexer
    assign any_hi = |req_hi;
    assign grant  = any_hi ? grant_hi : grant_lo;

    // 6. Pointer update logic (rotates on valid grant, holds on idle)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ptr_oh <= 'b1; // Reset pointing to index 0 (one-hot)
        end else if (|grant) begin
            // Rotate left with wrap-around (MSB wraps back to LSB)
            ptr_oh <= {grant[WIDTH-2:0], grant[WIDTH-1]};
        end
        // Implicitly holds its current value if |grant == 0 (idle)
    end

endmodule