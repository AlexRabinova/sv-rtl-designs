module variable_shift_register_3bit (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [2:0]  d_i,       // 3-bit input data (MSB down to LSB)
    input  logic [1:0]  shift_amt, // Control lines determining the number of bits to be shifted
    output logic [2:0]  q_o        // 3-bit output from the destination register
);

    // 1. Source Register (Left REG block in Figure 38)
    logic [2:0] source_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            source_reg <= 3'b000;
        end else begin
            source_reg <= d_i;
        end
    end

    // 2. Multiplexer Network (MUX blocks in Figure 38)[cite: 5]
    // Implements a logical shift right with zeros added from the left (MSB side).
    logic [2:0] mux_out;

    always_comb begin
        case (shift_amt)
            2'd0:    mux_out = source_reg;                  // Shift by 0
            2'd1:    mux_out = {1'b0, source_reg[2:1]};     // Shift by 1 (adds '0' from the left)[cite: 5]
            2'd2:    mux_out = {2'b00, source_reg[2]};      // Shift by 2 (adds '0's from the left)[cite: 5]
            default: mux_out = source_reg;
        endcase
    end

    // 3. Destination Register (Right REG block in Figure 38)[cite: 5]
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_o <= 3'b000;
        end else begin
            q_o <= mux_out;
        end
    end

endmodule