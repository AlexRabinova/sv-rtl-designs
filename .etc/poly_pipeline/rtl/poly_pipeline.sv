module poly_pipeline (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid_in,
    input  logic [7:0]  x_in,
    output logic [7:0]  y_out,
    output logic        valid_out
);

    // Pipeline Stage 1 registers
    logic [7:0] x_stage1;
    logic [7:0] stage1_res;
    logic       val_stage1;

    // Pipeline Stage 2 registers
    logic [7:0] x_stage2;
    logic [7:0] stage2_res;
    logic       val_stage2;

    // --- STAGE 1: (x + 1) * x ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_stage1   <= '0;
            stage1_res <= '0;
            val_stage1 <= 1'b0;
        end else if (valid_in) begin
            x_stage1   <= x_in;
            stage1_res <= (x_in + 8'd1) * x_in; // First part: x^2 + x
            val_stage1 <= 1'b1;
        end else begin
            val_stage1 <= 1'b0;
        end
    end

    // --- STAGE 2: (stage1_res + 1) * x_stage1 ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage2_res <= '0;
            val_stage2 <= 1'b0;
        end else if (val_stage1) begin
            stage2_res <= (stage1_res + 8'd1) * x_stage1; // Final part: (x^2 + x + 1) * x
            val_stage2 <= 1'b1;
        end else begin
            val_stage2 <= 1'b0;
        end
    end

    assign y_out     = stage2_res;
    assign valid_out = val_stage2;

endmodule